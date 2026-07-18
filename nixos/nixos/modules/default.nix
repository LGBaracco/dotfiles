{ config,
  pkgs,
  inputs,
  lib,
  ... }:

{
  imports = [
    ./boot
    ./hardware
    ./packages
    ./theming
    ];

  # ── Nix / Flakes ──────────────────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      # Recommended binary caches
      substituters = [
        "https://cache.nixos.org"
        "https://niri.cachix.org" # niri flake cache
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBo="
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
  #   stdenv.cc.cc.lib
  #   libgcc
  #   zlib
    config.hardware.nvidia.package
  ];

  # ── Kernel ────────────────────────────────────────────────────────────────
  # boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.kernelPackages = pkgs.linuxPackages_latest; # as opposed to default LTS kernel

  # ── User ──────────────────────────────────────────────────────────────────
  users.users.lorenzo = {
    isNormalUser = true;
    group = "lorenzo";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
    ];
    shell = pkgs.fish;
  };
  users.groups.lorenzo = { };
  programs.fish.enable = true; # needed for fish as login shell


  # ── Secrets / Keyring ─────────────────────────────────────────────────────
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  security.polkit.enablePkexecWrapper = true;
  # security.polkit.enable = true;

  # ── XDG portals ───────────────────────────────────────────────────────────
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      kdePackages.xdg-desktop-portal-kde
    ];
    config.common.default = "*";
    config.niri = {
      "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
    };
  };

  # ── X11 ─────────────────────────────────────────────────────────
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  # ── Locale / Time ─────────────────────────────────────────────────────────
  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # ── Networking ────────────────────────────────────────────────────────────
  networking = {
    networkmanager.enable = true;
  };

  # ── Audio ─────────────────────────────────────────────────────────────────
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  hardware.bluetooth.enable = true;

   # ── Misc ──────────────────────────────────────────────────────────────────
  programs.dconf.enable = true; # needed by some GTK apps under KDE
  services.gvfs.enable = true; # needed for trash bin and partition mounts with nautilus outside of kde
  services.flatpak.enable = false;

}
