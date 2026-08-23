{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./boot
    ./hardware
    ./overlays.nix
    ./theming
    ./system-packages.nix
    ./desktop-environment.nix
    ./gaming.nix
    ./home-manager.nix
    inputs.dms-plugin-registry.nixosModules.default
  ];

  # ── nix / flakes ──────────────────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      # recommended binary caches
      substituters = [
        "https://cache.nixos.org"
        "https://niri.cachix.org" # niri flake cache
        "https://nix-community.cachix.org"
        "https://cache.flox.dev"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  nixpkgs.config.allowUnfree = true;
  #nixpkgs-stable.config.allowUnfree = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    libgcc
    zlib
    config.hardware.nvidia.package
  ];

  # ── kernel ────────────────────────────────────────────────────────────────
  # boot.kernelpackages = pkgs.linuxpackages_zen;
  #boot.kernelpackages = pkgs.linuxpackages_latest; # as opposed to default lts kernel

  # zram
  zramSwap.enable = true;

  # resize filesystem
  fileSystems."/".autoResize = true;

  # ── user ──────────────────────────────────────────────────────────────────
  users.users.lorenzo = {
    isNormalUser = true;
    group = "lorenzo";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "greeter"
    ];
    shell = pkgs.fish;
  };
  users.groups.lorenzo = { };
  programs.fish.enable = true; # needed for fish as login shell

  # ── secrets / keyring ─────────────────────────────────────────────────────
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  security.polkit.enablePkexecWrapper = true;

  # ── xdg portals ───────────────────────────────────────────────────────────
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      kdePackages.xdg-desktop-portal-kde
    ];
    config.niri = {
      "org.freedesktop.impl.portal.filechooser" = [ "gnome" ];
    };
    config.mango = {
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
    config.common.default = "*";
  };

  # ── x11 ─────────────────────────────────────────────────────────
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  # ── locale / time ─────────────────────────────────────────────────────────
  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # ── networking ────────────────────────────────────────────────────────────
  networking = {
    networkmanager.enable = true;
  };

  # ── audio ─────────────────────────────────────────────────────────────────
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  hardware.bluetooth.enable = true;

  # ── misc ──────────────────────────────────────────────────────────────────
  programs.dconf.enable = true; # needed by some gtk apps under kde
  services.gvfs.enable = true; # needed for trash bin and partition mounts with nautilus outside of kde
  services.flatpak.enable = true;
  services.flatpak.packages = [
    "com.jetbrains.PyCharm-Professional"
  ];
}
