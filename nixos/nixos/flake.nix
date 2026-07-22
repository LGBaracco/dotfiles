{
  description = "My NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
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
      niri-flake,
      silentSDDM,
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
          niri-flake.nixosModules.niri
          silentSDDM.nixosModules.default
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
          niri-flake.nixosModules.niri
          silentSDDM.nixosModules.default
          home-manager.nixosModules.home-manager
          nvf.homeManagerModules.default
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.backupFileExtension = "bak";
            home-manager.users.lorenzo = {
              imports = [
                ./hosts/nixlaptop/lorenzo.nix
                ./lorenzo
              ];
            };
          }
        ];
      };
    };
}
