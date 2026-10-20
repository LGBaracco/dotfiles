{ inputs, ... }:
{
  flake.modules.nixos.common =
    { ... }:
    {
      nixpkgs.overlays = [
        inputs.helium.overlays.default

        (final: prev: {
          tabctl = final.callPackage ../pkgs/tabctl.nix { };
          yamis-icon-theme = final.callPackage ../pkgs/yamis-icon-theme.nix { };

          # FZJ L2TP/IPsec (TKI-0387) needs IKEv1. strongSwan 6 dropped it; take
          # 5.9.14 from nixpkgs 24.11 (matches the guide's Ubuntu/strongSwan stack).
          strongswan =
            inputs.nixpkgs-strongswan5.legacyPackages.${final.stdenv.hostPlatform.system}.strongswan;
          # nm-l2tp closes over prev.strongswan; force rebuild against 5.9.14.
          networkmanager-l2tp = prev.networkmanager-l2tp.override {
            strongswan = final.strongswan;
          };
        })

        # Kernels built against an older nixpkgs (e.g. Nyx's cached CachyOS) ship no
        # modules.cer, which aggregateModules now requires (nixpkgs#571181, #575192).
        # Skip the certificate merge when it's absent. Drop once upstream handles it.
        (final: prev: {
          aggregateModules =
            modules:
            (prev.aggregateModules modules).overrideAttrs (old: {
              postBuild =
                let
                  from = ''cd -- "$out/lib/modules/$kernelVersion"'';
                  patched = builtins.replaceStrings [ from ] [
                    ''
                      cd -- "$out/lib/modules/$kernelVersion"
                              if ! test -e modules.cer; then echo "no modules.cer, skipping cert merge"; exit 0; fi''
                  ] old.postBuild;
                in
                if patched == old.postBuild then
                  throw "aggregateModules overlay: postBuild changed upstream, remove the workaround"
                else
                  patched;
            });
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
