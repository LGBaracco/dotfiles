{ pkgs, ... }: {
  imports = [
    ./git.nix
    ./home-packages.nix
    ./starfish.nix
    ./neovim.nix
    ./chromium.nix
  ];

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk; # emacs30-pgtk
    extraPackages = epkgs: [ epkgs.vterm ];
  };

  programs.ghostty = {
    enable = true;
    settings = {
      theme = "Oxocarbon";
      font-size = 12;
    };
  };

  home.sessionPath = [
    "$HOME/.config/emacs/bin" # Doom emacs
    "$HOME/.local/bin"
  ];

  # ── Environment variables ─────────────────────────────────────────────────
  # These are either magical or already set in niri config
  #home.sessionVariables = {
  # NIXOS_OZONE_WL = "1"; # forces Electron/CEF apps to use Wayland
  # MOZ_ENABLE_WAYLAND = "1";
  # #SDL_VIDEODRIVER = "wayland";
  # # NVIDIA-specific Wayland env vars
  # GBM_BACKEND = "nvidia-drm";
  # __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  # WLR_NO_HARDWARE_CURSORS = "1"; # fixes cursor rendering on NVIDIA+Wayland
  #};

  # ── niri config ───────────────────────────────────────────────────────────
  # niri-flake exposes a home-manager module for niri's config.kdl
  # Uncomment and extend once you've imported niri-flake's HM module:
  #
  # programs.niri.settings = {
  #   outputs."eDP-1" = {
  #     scale = 1.0;
  #   };
  #   binds = with config.lib.niri.actions; {
  #     "Mod+Q".action      = close-window;
  #   };
  # };
  # # ── GTK theming ───────────────────────────────────────────────────────────
  # gtk = {
  #    enable = true;
  #   iconTheme = {
  #     name    = "Papirus-Dark";
  #     package = pkgs.papirus-icon-theme;
  #   };
  # };

  # ── Cursor ────────────────────────────────────────────────────────────────
  # home.pointerCursor = {
  #   gtk.enable  = true;
  #   name        = "Catppuccin-Mocha-Dark-Cursors";
  #   package     = pkgs.catppuccin-cursors.mochaDark;
  #   size        = 24;
  # };
}
