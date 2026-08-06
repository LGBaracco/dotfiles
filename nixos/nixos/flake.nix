{
  description = "My NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nvf,
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
