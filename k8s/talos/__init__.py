from base64 import b64encode
from ipaddress import ip_address, ip_network
from pathlib import Path
import yaml, zstd  # Replace zstd w/ the stdlib's compression.zstd once on Py3.14

import pulumi as pu
import pulumiverse_talos as talos


vlans = {
    "mgmt": 32,
}
mgmt_net = ip_network("192.168.32.0/24")
gw_ip = mgmt_net[-2]
cluster_vip = ip_address("192.168.32.80")  # A failover IP used to find control-plane node(s)
nodes = [ 1, 2 ]
version = "1.12.3"

network_config = (Path(__file__).parent / "network_config.yaml").read_text()

image_schematic = talos.imagefactory.Schematic(
    "installerSchematic",
    schematic = yaml.dump({
        "customization": {
            "extraKernelArgs": [
                f"talos.config.early={b64encode(zstd.compress(network_config.encode("ASCII"), 22)).decode("ASCII")}"
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

cluster_cfg = talos.machine.get_configuration_output(
    cluster_name = "rkube",
    talos_version = version,
    machine_type = "controlplane",
    cluster_endpoint = f"https://{cluster_vip}:6443",
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
    ]
)
pu.export(
    "talosconfig",
    secrets.client_configuration.apply(lambda ccfg: yaml.dump({
        # talos.client.get_configuration_output doesn't seem to work
        "context": "rkube",
        "contexts": { "rkube": {
            "endpoints": [ str(cluster_vip) ],
            "nodes": [ str(cluster_vip + node) for node in nodes ],
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

    nodes_install = {
        idx: talos.machine.ConfigurationApply(
            f"rkube{idx}-install",
            client_configuration = secrets.client_configuration,
            machine_configuration_input = cluster_cfg.machine_configuration,
            node = str(cluster_vip + idx),
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
                network_config,  # TODO: generate config w/ static IP
                yaml.dump({  # /!\ Only for control-plane nodes
                    "apiVersion": "v1alpha1",
                    "kind": "Layer2VIPConfig",
                    "name": str(cluster_vip),
                    "link": "mgmt",
                }),
                # Configuration needed by other modules after this point
                # TODO: do some dependency inversion magic to define those in the relevant module
                # Disable the default CNI
                yaml.dump({
                    "cluster": {
                        "network": { "cni": { "name": "none" } },
                        "proxy": { "disabled": True },
                    },
                }),
                # TODO DNS config
            ],
        )
        for idx in nodes
    }

    bootstrap = talos.machine.Bootstrap(
        "rkube-bootstrap",
        node = str(cluster_vip + bootstrap_idx),
        client_configuration = secrets.client_configuration,
        opts = pu.ResourceOptions(depends_on = nodes_install[bootstrap_idx]),
    )


    kubeconfig = talos.cluster.get_kubeconfig_output(
        client_configuration = talos.cluster.GetKubeconfigClientConfigurationArgs(
            # WTF, why does passing secrets.client_configuration not work?
            ca_certificate = secrets.client_configuration.ca_certificate,
            client_certificate = secrets.client_configuration.client_certificate,
            client_key = secrets.client_configuration.client_key,
        ),
        node = str(k8s_vip),
    )
    pu.export("kubeconfig", kubeconfig.kubeconfig_raw)
