{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{
  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    # If you want to keep rEFInd instead:
    # systemd-boot.enable = false;
    # and install rEFInd manually or via boot.loader.refind
  };

  # ── Kernel ────────────────────────────────────────────────────────────────
  # CachyOS uses the cachyos-kernel; closest on NixOS is zen or xanmod.
  # Default linux_zen is a solid daily-driver replacement.
  # boot.kernelPackages = pkgs.linuxPackages_zen;

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
  nixpkgs.config.allowUnfree = true; # needed for NVIDIA + Brave

  # ── Locale / Time ─────────────────────────────────────────────────────────
  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # ── Networking ────────────────────────────────────────────────────────────
  networking = {
    hostName = "nixlorenzo";
    networkmanager.enable = true;
  };

  # ── NVIDIA ────────────────────────────────────────────────────────────────
  # Hybrid Intel/NVIDIA via PRIME offload (matches your envycontrol/PRIME setup)
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Steam / 32-bit GL
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement = {
      enable = true;
      finegrained = true; # RTD3 suspend for dGPU when idle
    };
    open = false; # proprietary driver (better Wayland support currently)
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # gives you `nvidia-offload` helper
      };
      # Fill in your actual PCI bus IDs from: nixos-generate-config or lspci
      intelBusId = "PCI:00:02:0";
      nvidiaBusId = "PCI:01:00:0";
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  # ── Display Manager: SDDM ─────────────────────────────────────────────────
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
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
  # Provided by niri-flake NixOS module; adds niri to the session list in SDDM
  programs.niri = {
    enable = true;
    package = inputs.niri-flake.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
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

  # ── Secrets / Keyring ─────────────────────────────────────────────────────
  # KWallet is pulled in by Plasma automatically.
  # If you want to ditch KWallet for gnome-keyring (works better with non-KDE apps):
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  # Then set the BROWSER_KEYRING env var to "gnome" for Brave.
  systemd.user.services.niri-flake-polkit.enable = false;

  # ── Fonts ─────────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      nerd-fonts.symbols-only
      symbola
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
    };
  };

  # ── System-wide packages ───────────────────────────────────────────────────
  # Keep this lean; prefer home.nix for user tools
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    coreutils
    pciutils # lspci — useful for GPU debugging
    usbutils
    nvtopPackages.full # GPU monitor
    htop
    btop
    dgop
    efibootmgr
    gcc
  ];

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

  # ── XDG portals ───────────────────────────────────────────────────────────
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      kdePackages.xdg-desktop-portal-kde
    ];
    config.common.default = "*";
  };

  # ── Systemd
  # systed.services.battery-limit = {
  #     description = "Limits battery charging to 80%"
  #
  #   }
  #
  hardware.firmware = [
    (pkgs.runCommand "Patch firmware" {} ''
    mkdir -p $out/lib/firmware
    cp ${./firmware}/* $out/lib/firmware
    '')
  ];
  # hardware.firmware = [
  #   (pkgs.runCommandNoCC "lenovo-audio-patch" { src = ./lenovo-audio.patch; } ''
  #     mkdir -p $out/lib/firmware
  #     # Make sure the path to the patch is correct!
  #     # The path './lenovo-audio.patch' assumes the patch is
  #     # in the same directory as this .nix file.
  #     mkdir -p $out/lib/firmware
  #     cp $src $out/lib/firmware/legion-alc287.patch
  #   '')
  # ];

  # # 2. Instruct the 'snd_hda_intel' kernel module to use the patch.
  # boot.extraModprobeConfig = ''
  #   options snd-hda-intel patch=lenovo-audio.patch
  # '';
  # ── Misc ──────────────────────────────────────────────────────────────────
  programs.dconf.enable = true; # needed by some GTK apps under KDE
  services.flatpak.enable = false; # enable if you need flatpaks
  system.stateVersion = "26.05";
}
