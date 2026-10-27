{
  flake.modules.nixos.nixsurface =
    { pkgs, ... }:
    {
      # Noctalia v5 (C++, no Qt) instead of Dux Shell: a fraction of the RAM on 2 GB
      programs.noctalia = {
        enable = true;
        systemd = {
          enable = true;
          target = "niri.service";
        };
        recommendedServices.enable = true; # NetworkManager, bluetooth, UPower, power-profiles-daemon
      };
      services.displayManager.noctalia-greeter.enable = true;

      # Rotate the niri output from the accelerometer (iio-sensor-proxy)
      services.iio-niri.enable = true;

      # On-screen keyboard, shown/hidden from niri-host.kdl
      environment.systemPackages = [ pkgs.wvkbd ];
    };
}
