{ config, inputs, ... }:
{
  flake.nixosConfigurations.nixlaptop = inputs.nixpkgs.lib.nixosSystem {
    modules = with config.flake.modules.nixos; [
      common
      nixlaptop
    ];
  };

  flake.modules.nixos.nixlaptop =
    { ... }:

    {
      imports = [
        ./hardware/_hardware-configuration.nix
      ];
      networking.hostName = "nixlaptop";
      system.stateVersion = "26.05";
      home-manager.users.lorenzo.imports = [ ./_lorenzo.nix ];
    };
}
