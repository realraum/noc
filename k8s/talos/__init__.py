from base64 import b64encode
from ipaddress import ip_address, ip_network
from pathlib import Path
from typing import Any, Optional
import yaml, zstd  # Replace zstd w/ the stdlib's compression.zstd once on Py3.14

import pulumi as pu
import pulumiverse_talos as talos

from networking import vlans, k8s_vip, node_ip, pod_net, svc_net


nodes = [ 1, 2 ]
version = "1.12.3"

def network_config(node: Optional[int]) -> Any:
    cfg = lambda name, kind, **args: {
        "apiVersion": "v1alpha1",
        "kind": f"{kind}Config",
        "name": name,
        **args,
    }

    return ([
        cfg("trunk", "LinkAlias", selector={ "match": '"0000:01:00.0" == link.bus_path' }),
        cfg("trunk", "Link", up=True, addresses=[]),
    ] + [
        cfg(
            name, "VLAN",
            vlanID=vlan.id, vlanMode="802.1q",
            parent="trunk", up=True,
            addresses=[ { "address": f"{str(node_ip(node))}/24" } ] if name == "mgmt" and node is not None else [],
            routes=[ { "gateway": str(vlan.gw) } ] if name == "mgmt" and node is not None else [],
        )
        for name, vlan in vlans.items()
    ]) + ([
        cfg("mgmt", "DHCPv4", clientIdentifier="mac"),
    ] if node is None else [])

image_schematic = talos.imagefactory.Schematic(
    "installerSchematic",
    schematic = yaml.dump({
        "customization": {
            "extraKernelArgs": [
                f"talos.config.early={b64encode(zstd.compress(yaml.dump_all(network_config(None)).encode("ASCII"), 22)).decode("ASCII")}"
            ],
            "systemExtensions": {
                "officialExtensions": [
                    "siderolabs/intel-ucode",
                    "siderolabs/nvme-cli",
                ],
            },
        },
    }),
)
pu.export(
    "installerAmd64",
    talos.imagefactory.get_urls_output(
        architecture = "amd64",
        platform = "metal",
        schematic_id = image_schematic.id,
        talos_version = version,
    ).urls.iso_secureboot,
)

secrets = talos.machine.Secrets(
    "talos-secrets",
    talos_version = version,
)

pu.export(
    "talosconfig",
    secrets.client_configuration.apply(lambda ccfg: yaml.dump({
        # talos.client.get_configuration_output doesn't seem to work
        "context": "rkube",
        "contexts": { "rkube": {
            "endpoints": [ str(node_ip(node)) for node in nodes ],  # TODO limit to control-plane nodes
            "nodes": [ str(node_ip(node)) for node in nodes ],
            "ca":  ccfg.ca_certificate,
            "crt": ccfg.client_certificate,
            "key": ccfg.client_key,
        } },
    })),
)

config = pu.Config()
bootstrap_idx = config.get_int("bootstrapNode")
if bootstrap_idx:
    assert bootstrap_idx in nodes

    cluster_cfg = talos.machine.get_configuration_output(
        cluster_name = "rkube",
        talos_version = version,
        machine_type = "controlplane",
        cluster_endpoint = f"https://{str(node_ip(bootstrap_idx))}:6443",
        machine_secrets = secrets.machine_secrets.apply(lambda ms: {  # HACK for pulumiverse/pulumi-talos#103
            "certs": {
                "k8sAggregator": ms.certs.k8s_aggregator,
                "os": ms.certs.os,
                "etcd": ms.certs.etcd,
                "k8s": ms.certs.k8s,
                "k8sServiceaccount": ms.certs.k8s_serviceaccount,
            },
            "secrets": {
                "bootstrapToken": ms.secrets.bootstrap_token,
                "secretboxEncryptionSecret": ms.secrets.secretbox_encryption_secret,
            },
            "trustdinfo": ms.trustdinfo,
            "cluster": {
                "id": ms.cluster.id,
                "secret": ms.cluster.secret,
            },
        }),
        config_patches = [
            yaml.dump({
                # Use TPM-backed disk encryption from the start
                "machine": {
                    "systemDiskEncryption": {
                        vol: {
                            "provider": "luks2",
                            "keys": [ {
                                "tpm": {},
                                "slot": 0,
                            } ],
                        }
                        for vol in ("ephemeral", "state")
                    },
                },
            }),
            # Disable the default CNI, override the IPv4 defaults
            yaml.dump({
                "cluster": {
                    "network": {
                        "podSubnets": [ str(pod_net) ],
                        "serviceSubnets": [ str(svc_net) ],
                        "cni": { "name": "none" },
                    },
                    "proxy": { "disabled": True },
                },
            }),
            yaml.dump({
                "apiVersion": "v1alpha1",
                "kind": "ResolverConfig",
                "nameservers": [
                    { "address": str(vlans["mgmt"].gw) }, # gw.realraum.at
                    { "address": "10.12.0.10" },          # FFgraz anycast DNS resolver
                    { "address": "9.9.9.10" },            # quad9.net, “Unsecured”
                    { "address": "149.112.112.10" },      #  fallback address for the same
                ],
                "searchDomains": {
                    "disableDefault": True,  # do not infer a search domain from hostname (not a FQDN)
                    "domains": [ "mgmt.realraum.at" ],  # node names must be resolvable in this zone
                },
            })
        ]
    )

    nodes_install = {
        idx: talos.machine.ConfigurationApply(
            f"rkube{idx}-install",
            client_configuration = secrets.client_configuration,
            machine_configuration_input = cluster_cfg.machine_configuration,
            node = str(node_ip(idx)),
            config_patches = [
                # Set the hostname
                yaml.dump({
                    "apiVersion": "v1alpha1",
                    "kind": "HostnameConfig",
                    "hostname": f"rkube-{idx}",
                    "auto": "off",
                }),
                # Run the install
                yaml.dump({ "machine": { "install": {
                    "disk": "/dev/nvme0n1",
                    "image": talos.imagefactory.get_urls(
                        architecture = "amd64",
                        platform = "metal",
                        schematic_id = image_schematic.id,
                        talos_version = version,
                    ).urls.installer_secureboot,
                    "wipe": False,
                } } }),
                *[ yaml.dump(patch) for patch in network_config(idx) ],
                yaml.dump({  # /!\ Only for control-plane nodes
                    "apiVersion": "v1alpha1",
                    "kind": "Layer2VIPConfig",
                    "name": str(k8s_vip),
                    "link": "mgmt",
                }),
                # Configuration needed by other modules after this point
                # TODO: do some dependency inversion magic to define those in the relevant module
                # TODO DNS config
            ],
        )
        for idx in nodes
    }

    bootstrap = talos.machine.Bootstrap(
        "rkube-bootstrap",
        node = str(node_ip(bootstrap_idx)),
        client_configuration = secrets.client_configuration,
        opts = pu.ResourceOptions(depends_on = tuple(nodes_install.values())),
    )

    kubeconfig = talos.cluster.get_kubeconfig_output(
        client_configuration = talos.cluster.GetKubeconfigClientConfigurationArgs(
            # WTF, why does passing secrets.client_configuration not work?
            ca_certificate = secrets.client_configuration.ca_certificate,
            client_certificate = secrets.client_configuration.client_certificate,
            client_key = secrets.client_configuration.client_key,
        ),
        node = str(k8s_vip),
        opts = pu.InvokeOutputOptions(depends_on = bootstrap), # accesses the k8s cluster by vIP
    )
    pu.export("kubeconfig", kubeconfig.kubeconfig_raw)
