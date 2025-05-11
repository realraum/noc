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
        # Use TPM-backed disk encryption from the start
        yaml.dump({ "machine": {
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
        }}),
    ],
)

pu.export(
    "talosconfig",
    secrets.client_configuration.apply(lambda ccfg: yaml.dump({
        "context": "rkube",
        "contexts": { "rkube": {
            "endpoints": [ str(cluster_vip) ],
            "ca":  ccfg.ca_certificate,
            "crt": ccfg.client_certificate,
            "key": ccfg.client_key,
        } },
    }))
)

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
