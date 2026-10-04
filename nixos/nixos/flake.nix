{
  description = "My NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    # strongSwan 5.9.14 (IKEv1) for FZJ L2TP; current nixpkgs is 6.x without IKEv1
    nixpkgs-strongswan5.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wrappers = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvim-config = {
      url = "path:../../neovim/.config/nvim";
    };
    helium = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms-plugin-registry = {
      url = "github:AvengeMedia/dms-plugin-registry";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms-sessionizer = {
      url = "github:LGBaracco/dms-sessionizer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dankcalendar = {
      url = "github:AvengeMedia/dankcalendar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Do not override nixpkgs — pinned overlay + attic cache need their own rev.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      mkHost =
        hostPath:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            { nixpkgs.hostPlatform = "x86_64-linux"; }
            hostPath
            ./modules
          ];
        };
    in
    {
      nixosConfigurations.nixdesktop = mkHost ./hosts/nixdesktop;
      nixosConfigurations.nixlaptop = mkHost ./hosts/nixlaptop;
    };
}
