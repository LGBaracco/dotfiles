{ inputs, ... }:
{
  flake.modules.nixos.common =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.chaotic.nixosModules.default ];
      nixpkgs.hostPlatform = "x86_64-linux";

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
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
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

      # ── locale / time ─────────────────────────────────────────────────────────
      time.timeZone = "Europe/Amsterdam";
      i18n.defaultLocale = "en_US.UTF-8";
      console.keyMap = "us";

      # ── misc ──────────────────────────────────────────────────────────────────
      programs.fuse.userAllowOther = true;
    };
}
