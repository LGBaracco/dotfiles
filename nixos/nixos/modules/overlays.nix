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
