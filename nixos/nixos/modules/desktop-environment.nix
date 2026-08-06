{ pkgs, inputs, lib, ... }:
{
  # ── Display Manager: DMS Greeter ─────────────────────────────────────────────────
  services.displayManager.dms-greeter = {
    enable = true;
    configHome = "/home/lorenzo"; # copies that user's DMS settings (and wallpaper) into the greeter data directory before greetd starts
    compositor.name = "niri"; # or hyprland, sway, labwc, mango, scroll, miracle
  };
  # Check whether monitor settings create trouble on laptop
  environment.etc."greetd/niri_overrides.kdl".text = ''
      input {
        keyboard {
          numlock
        }
      }

      output "DVI-D-1" {
        position x=3840 y=0
      }
      output "DP-2" {
        position x=1920 y=0
        focus-at-startup
      }
      output "HDMI-A-4" {
        position x=0 y=0
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

  # DMS shell
  programs.dms-shell = {
    enable = true;
    systemd = {
      enable = true;
      target = "niri-session.target";
      restartIfChanged = true;
    };
  };

  # systemd.user.services.dankmaterialshell = {
  #   unitConfig = {
  #     Conflicts = [ "plasma-workspace.target" "plasma-workspace-wayland.target" ];
  #   };
  # };

  # Old SDDM setup
  # services.displayManager.sddm = {
  #   enable = true;
  #   wayland.enable = false;
  #   autoNumlock = true;
  # };
  # programs.silentSDDM = {
  #   enable = true;
  #   theme = "default";
  #   # settings = { ... }; see example in module
  # };

}
