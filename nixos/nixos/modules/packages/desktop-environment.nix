{ pkgs, inputs, ... }:

{

  # ── Display Manager: SDDM ─────────────────────────────────────────────────
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = false;
    autoNumlock = true;
  };

  programs.silentSDDM = {
    enable = true;
    theme = "default";
    # settings = { ... }; see example in module
  };

  # ── KDE Plasma (Wayland session) ──────────────────────────────────────────
  services.desktopManager.plasma6.enable = true;
  environment.plasma6.excludePackages = with pkgs; [
    kdePackages.discover
  ];

  # ── niri (tiling Wayland compositor) ─────────────────────────────────────
  programs.niri = {
    enable = true;
    package = inputs.niri-flake.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  };
  systemd.user.services.niri-flake-polkit.enable = false;

  # DMS shell
  programs.dms-shell = {
    enable = true;
    systemd = {
      enable = false;
    };
  };
}
