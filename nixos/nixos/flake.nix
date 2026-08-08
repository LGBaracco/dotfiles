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
    {
      nixosConfigurations.nixdesktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/nixdesktop
          ./modules
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [ helium.overlays.default ];

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.backupFileExtension = "bak";
            home-manager.users.lorenzo = {
              imports = [
                ./hosts/nixdesktop/lorenzo.nix
                ./lorenzo
                nvf.homeManagerModules.default
              ];
            };
          }
        ];
      };

      nixosConfigurations.nixlorenzo = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/nixlaptop
          ./modules
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [ helium.overlays.default ];

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.backupFileExtension = "bak";
            home-manager.users.lorenzo = {
              imports = [
                ./hosts/nixlaptop/lorenzo.nix
                ./lorenzo
                nvf.homeManagerModules.default
              ];
            };
          }
        ];
      };
    };
}
