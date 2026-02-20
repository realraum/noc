"""Set up the Cilium CNI, as well as (optionally) Hubble observability platform.

Cilium handles basic inter-node networking, service mesh, as well as security functions:
- traffic policy enforcement, from L2/L3 firewalling to L7 policies ;
- logging of network flows, via the Hubble feature.

Cilium implements as much functionality as possible through eBPF programs executed
in-kernel, to avoid the overhead of copying data to userspace and switching contexts.
"""

from collections.abc import Set
from typing import Literal

import pulumi as pu
import pulumi_kubernetes as k8s

from talos import cluster_vip


Feature = Literal["gatewayAPI", "hubble"]

def deploy(
    cfg: pu.Config,
    cluster: k8s.Provider,
    deps,
    *,
    features: Set[Feature] = frozenset()
) -> k8s.helm.v4.Chart:
    """Deploy Cilium with a given set of features.

    Requires `k8sEndpoint` to be set in the Pulumi configuration;
      possible values can be obtained from `kubectl get endpoints kubernetes`.
    """
    # TODO centralize the network config & tie to Netbox
    cluster_net = "2a02:3e0:4000:cafe::/64"

    return k8s.helm.v4.Chart(
        "cilium",
        chart = "oci://quay.io/cilium/charts/cilium",
        version = "1.18.7",  # TODO: autoupdate?
        namespace = "kube-system",
        opts = pu.ResourceOptions(depends_on = deps, provider = cluster),
        # TODO signature verification?
        values = {
            # Necessary permissions for Cilium to function on Talos
            "securityContext" : { "capabilities": {
                "ciliumAgent": (
                    "CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN",
                    "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID",
                ),
                "cleanCiliumState": ( "NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE" ),
            } },
            "cgroup": {
                "autoMount": { "enabled": False },
                "hostRoot": "/sys/fs/cgroup",
            },

            "ipam": {
                # Use a prefix for each node
                #  see https://docs.cilium.io/en/stable/network/concepts/ipam/kubernetes/
                "mode": "kubernetes",
                "operator": {
                    # Use only IPv6 addresses for pods
                    #"clusterPoolIPv4PodCIDRList": [],
                    #"clusterPoolIPv6PodCIDRList": [ cluster_net ],
                    #"clusterPoolIPv6MaskSize": 96,
                },
            },
            #"ipv6": { "enabled": True },
            #"ipv4": { "enabled": False },
            #"k8s": {
            #    "requireIPv4PodCIDR": False,
            #    "requireIPv6PodCIDR": True,
            #},

            # Avoid `kube-proxy`, let Cilium sling packets around
            "kubeProxyReplacement": True,
            "k8sServiceHost": str(cluster_vip),
            "k8sServicePort": 6443,

            # TODO: Use native routing, rather than VXLAN encapsulation
            # TODO: control which interface(s) Cilium routes over
            #"autoDirectNodeRoutes": True,
            #"routingMode": "native",
            #"ipv6NativeRoutingCIDR": cluster_net,
            #"enableIPv4Masquerade": False,
            #"enableIPv6Masquerade": False,

            # TCP optimizations
            ## BIG frames (require native routing mode)
            #"enableIPv4BIGTCP": True,
            #"enableIPv6BIGTCP": True,

            ## BBR congestion control
            #"bandwidthManager": {
            #    "enabled": True,
            #    "bbr": True,
            #},

            # Optionally enable Gateway API support
            "gatewayAPI": {
                "enabled": True,
                "enableAlpn": True,
                "enableAppProtocol": True,
            } if "gatewayAPI" in features else {},

            # Optionally enable the Hubble observability tool
            "hubble": {
                "relay": { "enabled": True },
                "ui": { "enabled": True },
            } if "hubble" in features else {},
        },
    )
