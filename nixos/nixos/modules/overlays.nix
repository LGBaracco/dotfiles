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
          # Dropped from nixpkgs 2026-11-03; vendored, bump by hand (see pkgs/brave/default.nix).
          brave = final.callPackage ../pkgs/brave { };
        })

        # Stable packages through pkgs.stable.<pkg>
        (final: _prev: {
          stable = import inputs.nixpkgs-stable {
            system = final.stdenv.hostPlatform.system;
            config.allowUnfree = true;

          };
        })

        # Unstable packages through pkgs.unstable.<pkg>
        # Policy: reference pkgs.unstable.<pkg> only where it is used (package lists,
        # `package = ...` options). Never overlay a base attribute with an unstable package
        # (e.g. `rustc = final.unstable.rustc`): every stable package that depends on it
        # would then be rebuilt from source.
        # Overlays for unstable packages go in the `overlays` list below, not in the list above.
        (final: _prev: {
          unstable = import inputs.nixpkgs-unstable {
            system = final.stdenv.hostPlatform.system;
            config.allowUnfree = true;
            overlays = [
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
              # Neovim-wrapper tools broken on nixos-unstable 2026-11-07 (Hydra failed, so no cache).
              # Drop each once nixos-unstable includes the nixpkgs fix commit.
              (ufinal: prev: {
                # No pkg-config for onig_sys; fixed by 5246ebb2. Stable's 0.10.1 is cached.
                neocmakelsp = final.stable.neocmakelsp;
                # `cannot find -lsqlite3`; same change as upstream fix b023ece2.
                gersemi = prev.gersemi.overrideAttrs (old: {
                  buildInputs = (old.buildInputs or [ ]) ++ [ ufinal.sqlite ];
                });
              })
            ];
          };
        })

      ];

    };
}
