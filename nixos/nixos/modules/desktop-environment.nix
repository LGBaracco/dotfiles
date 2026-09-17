{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  # ── Display Manager: DMS Greeter ─────────────────────────────────────────────────
  services.displayManager.dms-greeter = {
    enable = true;
    configHome = "/home/lorenzo"; # copies that user's DMS settings (and wallpaper) into the greeter data directory before greetd starts
    compositor.name = "niri"; # greeter UI compositor
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
  systemd.user.services.plasma-kwin_wayland = {
    overrideStrategy = "asDropin";
    # NixOS injects Environment=PATH=<coreutils,...> into every
    # systemd.user.services unit, even as a drop-in. That replaces the PATH the
    # upstream unit inherits from the user manager, and kwin_wayland_wrapper
    # looks up `kwin_wayland` via PATH: it then silently never spawns kwin.
    enableDefaultPath = false;
    # A previous niri session imports the Home Manager session vars into the
    # systemd user manager, and startplasma does not clear them. With
    # QT_QPA_PLATFORMTHEME=gtk3, kwin_wayland loads the GTK platform theme; GTK
    # then connects to $XDG_RUNTIME_DIR/wayland-0 (WAYLAND_DISPLAY is unset), which
    # is kwin's own not-yet-served socket, so kwin deadlocks before drawing.
    serviceConfig.UnsetEnvironment = [
      "QT_QPA_PLATFORMTHEME"
      "QT_QPA_PLATFORMTHEME_QT6"
    ];
  };

  # ── niri
  programs.niri = {
    enable = true;
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
      dmsSessionizer = {
        enable = true;
        # Override registry package with our fork (pinned via flake.lock)
        src = lib.mkForce inputs.dms-sessionizer.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };
    };
    enableCalendarEvents = true;
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
  # Also start DMS when logging into mango
  systemd.user.services.dms.wantedBy = [ "mango-session.target" ];

}
