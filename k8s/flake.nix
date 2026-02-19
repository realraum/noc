{
  description = "Tools needed to cope with the k8s deployment";

  inputs = {
		# Actual versions are pinned in lockfile
		flake-utils.url = "github:numtide/flake-utils";
		nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

		# Allow users of the flake to override the set of supported systems
		systems.url = "github:nix-systems/default-linux";
		flake-utils.inputs.systems.follows = "systems";
  };

  outputs = { flake-utils, nixpkgs, ... }: flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs { inherit system; config.allowAliases = false; };
    inherit (pkgs) lib;
  in {
    devShells.default = let
      pulumiSDKs = with pkgs.pulumi.pkgs; [
        pulumiverse-talos
        pulumi-kubernetes
      ];
    in pkgs.mkShellNoCC {
      buildInputs = with pkgs; [
        jq
        wget

        # Talos
        talosctl

        # kubernetes
        kubernetes-helm
        kubectl
        k9s

        # cilium (k8s networking)
        cilium-cli
        hubble

        # Pulumi (infra-as-code)
        (pulumi.withPackages (pu: [ pu.pulumi-python ] ++ pulumiSDKs))
        (python313.withPackages (py: with py; [
          pip ipython pulumi zstd
        ] ++ (map (drv: drv.sdks.python) pulumiSDKs)))

        # static analysis
        pyright
        ruff
      ];

      LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.stdenv.cc.cc ];  # hack so the cygrpc wheel works
    };
  });
}
