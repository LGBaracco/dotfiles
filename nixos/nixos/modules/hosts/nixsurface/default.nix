{ config, inputs, ... }:
{
  flake.nixosConfigurations.nixsurface = inputs.nixpkgs.lib.nixosSystem {
    modules = with config.flake.modules.nixos; [
      common
      nixsurface
    ];
  };

  flake.modules.nixos.nixsurface =
    { ... }:

    {
      imports = [
        ./hardware/_hardware-configuration.nix
      ];
      networking.hostName = "nixsurface";
      system.stateVersion = "26.11";
      home-manager.users.lorenzo.imports = [ ./_lorenzo.nix ];
    };
}
