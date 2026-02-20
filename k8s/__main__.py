import pulumi as pu
import pulumi_kubernetes as k8s

import talos, cilium


cfg = pu.Config()
if cfg.get_int("bootstrapNode"):
    rkube = k8s.Provider(
        "rkube",
        kubeconfig = talos.kubeconfig.kubeconfig_raw,
    )
    cni = cilium.deploy(
        cfg,
        rkube,
        deps = talos.bootstrap,
        #features = { "gatewayAPI" },
    )
