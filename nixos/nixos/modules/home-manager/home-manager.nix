{ config, inputs, ... }:
{
  flake.modules.nixos.common =
    { ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
      ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        users.lorenzo = {
          imports = [
            config.flake.modules.homeManager.lorenzo
            (inputs.wrappers.lib.getInstallModule {
              name = "neovim";
              value = inputs.nvim-config.homeModules.neovim;
            })
          ];
        };
      };
    };

  flake.modules.nixos.workstation = {
    home-manager.users.lorenzo.imports = [ config.flake.modules.homeManager.workstation ];
  };
}
