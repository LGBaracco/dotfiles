{ inputs, ... }:
{
  nixpkgs.overlays = [
    inputs.helium.overlays.default
    inputs.nix-cachyos-kernel.overlays.pinned

    (final: prev: {
      tabctl = final.callPackage ../pkgs/tabctl.nix { };
      # Pin 1.18.31: 1.18.30 crashes on prompt with
      # TypeError: undefined is not an object (evaluating 'a.name')
      # in SystemPrompt.environment (Bun 1.4 code-splitting bug).
      # Drop once nixos-unstable carries this bump.
      opencode = final.callPackage ../pkgs/opencode/package.nix { };
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

    # Stable packages through pkgs.stable.<pkg>
    (final: _prev: {
      stable = import inputs.nixpkgs-stable {
        system = final.stdenv.hostPlatform.system;
        config.allowUnfree = true;

      };
    })

  ];

}
