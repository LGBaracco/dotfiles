{
  description = "My NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      nvf,
      helium,
      ...
    }@inputs:
    let # Scope for all common configurations among flakes
      mkHost =
        {
          hostPath,
          userConfigPath,
        }:
        nixpkgs.lib.nixosSystem {

          specialArgs = { inherit inputs; };
          modules = [
            { nixpkgs.hostPlatform = "x86_64-linux"; }
            hostPath
            ./modules
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.backupFileExtension = "bak";
              home-manager.users.lorenzo = {
                imports = [
                  userConfigPath
                  ./lorenzo
                  nvf.homeManagerModules.default
                ];
              };
            }
          ];
        };
    in
    # Here the actual unique flakes
    {
      nixosConfigurations.nixdesktop = mkHost {
        hostPath = ./hosts/nixdesktop;
        userConfigPath = ./hosts/nixdesktop/lorenzo.nix;
      };
      nixosConfigurations.nixlaptop = mkHost {
        hostPath = ./hosts/nixlaptop;
        userConfigPath = ./hosts/nixlaptop/lorenzo.nix;
      };
    };
}
