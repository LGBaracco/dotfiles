{
  flake.modules.nixos.nixlaptop =
    {
      programs.dms-shell.plugins = {
        dmsLenovoBatterySettings.enable = true;
      };
    };
}
