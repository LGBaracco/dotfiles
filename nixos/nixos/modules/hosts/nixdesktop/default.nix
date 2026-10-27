{ config, inputs, ... }:
{
  flake.nixosConfigurations.nixdesktop = inputs.nixpkgs.lib.nixosSystem {
    modules = with config.flake.modules.nixos; [
      common
      workstation
      nixdesktop
    ];
  };

  flake.modules.nixos.nixdesktop =
    { ... }:

    {
      imports = [
        ./hardware/_hardware-configuration.nix
      ];
      networking.hostName = "nixdesktop";
      system.stateVersion = "26.05";
      home-manager.users.lorenzo.imports = [ ./_lorenzo.nix ];
    };
}
