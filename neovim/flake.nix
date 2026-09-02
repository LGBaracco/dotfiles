{
  description = "Neovim config via nix-wrapper-modules (lua + nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    wrappers.url = "github:BirdeeHub/nix-wrapper-modules";
    wrappers.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      wrappers,
      ...
    }@inputs:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all;
      module = nixpkgs.lib.modules.importApply ./module.nix inputs;
      wrapper = wrappers.lib.evalModule module;
    in
    {
      wrapperModules = {
        neovim = module;
        default = self.wrapperModules.neovim;
      };
      wrappers = {
        neovim = wrapper.config;
        default = self.wrappers.neovim;
      };
      overlays = {
        neovim = final: prev: {
          neovim = self.wrappers.neovim.wrap { pkgs = final; };
        };
        default = self.overlays.neovim;
      };
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          neovim = self.wrappers.neovim.wrap { inherit pkgs; };
          default = self.packages.${system}.neovim;
        }
      );
      nixosModules = {
        default = self.nixosModules.neovim;
        neovim = wrappers.lib.getInstallModule {
          name = "neovim";
          value = module;
        };
      };
      homeModules = {
        default = self.homeModules.neovim;
        neovim = self.nixosModules.neovim;
      };
    };
}
