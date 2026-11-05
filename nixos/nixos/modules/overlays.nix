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

        # opencode 2.2.5: nixpkgs ships a stale node_modules hash (FOD mismatch).
        # Guarded to that version; remove once nixpkgs updates opencode.
        (_final: prev: {
          opencode =
            if prev.opencode.version == "2.2.5" then
              prev.opencode.overrideAttrs (old: {
                node_modules = old.node_modules.overrideAttrs {
                  outputHash = "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA=";
                };
              })
            else
              prev.opencode;
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
