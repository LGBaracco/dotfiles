{
  pkgs,
  lib,
  ...
}:
{
  # ── Display Manager: DMS Greeter ─────────────────────────────────────────────────
  services.displayManager.dms-greeter = {
    enable = true;
    configHome = "/home/lorenzo"; # copies that user's DMS settings (and wallpaper) into the greeter data directory before greetd starts
    compositor.name = "niri"; # greeter UI compositor only; sessions come from wayland-sessions (niri, mango, plasma, …)
  };

  environment.etc."greetd/niri_overrides.kdl".text = ''
    input {
      keyboard {
        numlock
      }
    }
  '';
  # All DEs try to enforce their own session as default, override to fix
  services.displayManager.defaultSession = lib.mkForce "niri";

  # ── KDE Plasma
  services.desktopManager.plasma6.enable = true;
  environment.plasma6.excludePackages = with pkgs; [
    kdePackages.discover
  ];

  # ── niri
  programs.niri = {
    enable = true;
  };

  # ── mango (mangowc) — selectable alongside niri in the DMS greeter
  programs.mango = {
    enable = true;
  };
  # systemd target started from mango autostart
  systemd.user.targets.mango-session = {
    description = "Mango compositor session";
    unitConfig = {
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
    };
  };

  # DMS shell
  programs.dms-shell = {
    enable = true;
    systemd = {
      enable = true;
      # Primary: niri.service; mango also pulls DMS via mango-session.target below
      target = "niri.service";
      restartIfChanged = true;
    };
    plugins = {
      calculator.enable = true;
      nixPackageRunner.enable = true;
      tabsLauncher.enable = true;
    };
    enableCalendarEvents = true;
  };

  # Also start DMS when logging into mango
  systemd.user.services.dms.wantedBy = [ "mango-session.target" ];

}
