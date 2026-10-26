{
  flake.modules.nixos.nixlaptop =
    {
      programs.dux-shell.plugins = {
        dmsLenovoBatterySettings.enable = true;
      };
    };
}
