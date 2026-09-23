{
  description = "HPC Neovim/tmux Apptainer image built from Nix (no Nix on the cluster)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    wrappers = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvim-config = {
      url = "path:../neovim/.config/nvim";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      wrappers,
      nvim-config,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true; # jupytext.nvim
      };

      neovim-hpc = wrappers.lib.evalPackage (
        { ... }:
        {
          inherit pkgs;
          imports = [ "${nvim-config}/module-hpc.nix" ];
          # Live Lua: bind-mount $PROJECT/hpc-env/config/nvim → ~/.config/nvim
          liveLua = true;
        }
      );

      image = import ./image.nix { inherit pkgs neovim-hpc; };
    in
    {
      packages.${system} = {
        neovim-hpc = neovim-hpc;
        hpc-devbox = image.hpc-devbox;
        hpc-devbox-oci = image.oci;
        default = image.hpc-devbox;
      };

      # Convenience: convert the OCI tarball to a SIF when apptainer is available locally.
      apps.${system}.build-sif = {
        type = "app";
        program = "${pkgs.writeShellApplication {
          name = "hpc-build-sif";
          runtimeInputs = [ pkgs.coreutils ];
          text = ''
            set -euo pipefail
            out="''${1:-nvim-hpc.sif}"
            oci="$(nix build --no-link --print-out-paths "${self}#hpc-devbox-oci")"
            if [[ ! -f "$oci" ]]; then
              echo "Expected a docker-archive file at $oci" >&2
              exit 1
            fi
            if command -v apptainer >/dev/null 2>&1; then
              apptainer build --force "$out" "docker-archive:$oci"
            elif command -v singularity >/dev/null 2>&1; then
              singularity build --force "$out" "docker-archive:$oci"
            else
              echo "Neither apptainer nor singularity found." >&2
              echo "OCI archive: $oci" >&2
              echo "On the cluster: apptainer build $out docker-archive:$oci" >&2
              exit 2
            fi
            echo "Wrote $out"
          '';
        }}/bin/hpc-build-sif";
      };
    };
}
