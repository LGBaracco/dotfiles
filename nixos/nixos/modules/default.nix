{
  config,
  lib,
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
    ./jetbrains.nix
    ./desktop-environment.nix
    ./gaming.nix
    ./firewall.nix
    ./nautilus.nix
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
        "https://nix-community.cachix.org"
        "https://cache.nixos-cuda.org"
        "https://attic.xuyh0120.win/lantian"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
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
      "lp"
    ];
    shell = pkgs.fish;
  };
  users.groups.lorenzo = { };
  programs.fish.enable = true; # needed for fish as login shell

  # ── secrets / keyring ─────────────────────────────────────────────────────
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

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
      "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
    };
    config.mango = {
      "org.freedesktop.impl.portal.FileChooser" = [ "gnome" ];
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
    # L2TP/IPsec VPNs break with strict reverse-path filtering
    firewall.checkReversePath = "loose";
    networkmanager = {
      enable = true;
      # FZJ L2TP-over-IPsec (TKI-0387); profiles show up in DMS → VPN
      # Overlay pins strongswan 5.9.14 (IKEv1); see overlays.nix
      plugins = with pkgs; [ networkmanager-l2tp ];
    };
  };

  # strongSwan for nm-l2tp (TKI-0387 guide). 5.9.14 via overlay — 6.x has no IKEv1.
  services.strongswan = {
    enable = true;
    secrets = [ "ipsec.d/ipsec.nm-l2tp.secrets" ];
  };
  # NM and strongswan modules both set this; force the nm-l2tp include.
  environment.etc."ipsec.secrets".text = lib.mkForce ''
    include ipsec.d/ipsec.nm-l2tp.secrets
  '';
  # unity plugin breaks L2TP transport-mode (nm-l2tp known issue)
  environment.etc."strongswan.d/charon/unity.conf".text = ''
    unity {
      load = no
    }
  '';
  systemd.tmpfiles.rules = [
    "d /etc/ipsec.d 0755 root root -"
  ];

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

  # ── printing ──────────────────────────────────────────────────────────────
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  # ── misc ──────────────────────────────────────────────────────────────────
  programs.dconf.enable = true; # needed by some gtk apps under kde
  services.gvfs.enable = true; # needed for trash bin and partition mounts with nautilus outside of kde
}
