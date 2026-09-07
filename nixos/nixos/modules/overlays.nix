{ inputs, ... }:
{
  nixpkgs.overlays = [
    inputs.helium.overlays.default
    inputs.nix-cachyos-kernel.overlays.pinned

    (final: prev: {
      tabctl = final.callPackage ../pkgs/tabctl.nix { };
    })

    # Stable packages through pkgs.stable.<pkg>
    (final: _prev: {
      stable = import inputs.nixpkgs-stable {
        system = final.stdenv.hostPlatform.system;
        config.allowUnfree = true;

      };
    })

  ];

}
