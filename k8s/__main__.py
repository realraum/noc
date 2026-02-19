import pulumi as pu

import talos, cilium


cfg = pu.Config()
# TODO: generate kube config
cni = cilium.deploy(
    cfg,
    deps = talos.bootstrap,
    #features = { "gatewayAPI" },
)
