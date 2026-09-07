{ inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.nix-flatpak.nixosModules.nix-flatpak
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    backupFileExtension = "bak";
    users.lorenzo = {
      imports = [
        ../lorenzo
        (inputs.wrappers.lib.getInstallModule {
          name = "neovim";
          value = ../../../neovim/.config/nvim/module.nix;
        })
      ];
    };
  };
}
