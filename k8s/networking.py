from collections.abc import Set
from dataclasses import dataclass
from ipaddress import ip_address, ip_network
from typing import Optional

import pulumi as pu

@dataclass(frozen=True)
class VLAN:
    id: int
    nets: Set[ip_network]
    gw: Optional[ip_address]

# TODO centralize the network config & tie to Netbox
cfg = pu.Config()
mgmt_net = ip_network(cfg.get_str("mgmtNet") or "192.168.32.0/24")
vlans = {
    "mgmt":   VLAN(32,  {mgmt_net}, mgmt_net[-2]),
    #"iot":    VLAN(33,  {ip_network("192.168.32.0/24")}, None),
    #"guests": VLAN(127, {ip_network("192.168.127.0/24"), ip_network("89.106.211.32/27"), ip_network("2a02:3e0:4000:1::/64")}, None)
}

# Addresses in the mgmt VLAN
## Failover virtual address for the k8s API server
k8s_vip = mgmt_net[80]
## mgmt address of a given node
node_ip = lambda idx: k8s_vip + idx

# Network(s) used exclusively for the cluster
## The prefix containing it all
cluster_net = ip_network("2a02:3e0:4000:c0de::/64")

## The prefix used for k8s Services, the first address of which is the API server
svc_net = ip_network("2a02:3e0:4000:c0de::/96")

## The prefix used for pod addresses
## Cilium (as of v1.18.7) cannot deal with larger node prefixes
##  see https://github.com/cilium/cilium/issues/20756
## TODO: fix Cilium's allocator, so we can use the whole /65 (and a /96 per node?)
pod_net = ip_network("2a02:3e0:4000:c0de:8000::/96")
pod_prefix_len = 112
