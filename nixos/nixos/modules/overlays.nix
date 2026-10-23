{ inputs, ... }:
{
  flake.modules.nixos.common =
    { ... }:
    {
      nixpkgs.overlays = [
        inputs.helium.overlays.default

        (final: _prev: {
          tabctl = final.callPackage ../pkgs/tabctl.nix { };
          yamis-icon-theme = final.callPackage ../pkgs/yamis-icon-theme.nix { };
        })

        # Stable packages through pkgs.stable.<pkg>
        (final: _prev: {
          stable = import inputs.nixpkgs-stable {
            system = final.stdenv.hostPlatform.system;
            config.allowUnfree = true;

          };
        })

      ];

    };
}
