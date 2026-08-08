{ inputs, ... }:
{
  nixpkgs.overlays = [
    inputs.helium.overlays.default

    (final: prev: {
      stable = import inputs.nixpkgs-stable {
        inherit (final) system;
        config.allowUnfree = true;
      };
    })
  ];
}
