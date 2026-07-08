{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{
  home.stateVersion = "26.05";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ── User packages ─────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # --- Browsers ---
    brave

    # --- Editors / Dev ---
    vscode # or vscodium for the libre build
    neovim

    # --- Dev tools ---
    stow
    ripgrep # needed by Doom Emacs / Neovim telescope
    fd
    fzf
    bat
    eza # modern ls
    zoxide # smarter cd
    jq
    yq
    lazygit
    gnumake
    coreutils

    # --- Nix tooling ---
    nix-output-monitor # prettier `nix build` output
    nvd # diff nixos generations
    alejandra # nix formatter
    nixfmt # Doom compatible formatter

    # --- Python (scientific) ---
    (python312.withPackages (
      ps: with ps; [
        numpy
        scipy
        matplotlib
        pandas
        jupyter
        ipython
      ]
    ))

    uv
    ruff

    # --- Julia ---
    julia-bin # official Julia binary (faster than building from source)

    # --- C/C++ ---
    clang
    cmake

    sbcl # Common Lisp
    proselint # Markdown linter
    pandoc # Markdown syntax highlighting
    shellcheck

    # --- Fonts / theming ---
    #papirus-icon-theme

    # --- Misc ---
    dms-shell
    quickshell
    ghostty
    foot
    mpv
    imv
    xdg-utils
    brightnessctl
    playerctl
  ];

  # ── Brave / Chromium flags for Wayland ──────────────────────────
  # Brave reads from ~/.config/brave-flags.conf
  # home.file.".config/brave-flags.conf".text = ''
  # Currently managed by dms and niri, one day create xdg.desktopEntry here

  # ── Git ───────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings = {

      user.email = "lorenzobaracco01@gmail.com";
      user.name = "LGBaracco";
      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "https";
  };

  # ── Neovim ────────────────────────────────────────────────────────────────
  # Minimal bootstrap — declarative configuration will need to live here
  # programs.neovim = {
  #   enable        = true;
  #   defaultEditor = true;
  #   viAlias       = true;
  #   vimAlias      = true;
  # };

  programs.emacs = {
    enable = true;
    package = pkgs.emacs30-pgtk;
    extraPackages = epkgs: [ epkgs.vterm ];
  };

  # ── Doom Emacs ────────────────────────────────────────────────────────────
  # Add doom's bin to PATH:
  home.sessionPath = [
    "$HOME/.config/emacs/bin"
    "$HOME/.local/bin"
  ];

  # ── Fish shell ────────────────────────────────────────────────────────────
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      zoxide init fish | source
      set -gx EDITOR nvim
      set -gx VISUAL nvim
    '';
    shellAliases = {
      #ls   = "eza --icons";
      ll = "eza -lah --icons";
      tree = "eza --tree --icons";
      #cat  = "bat";
      cd = "z"; # zoxide
      gs = "git status";
      lg = "lazygit";
      vi = "nvim";
      vim = "nvim";
      # Rebuild shortcut
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos#nixlorenzo";
    };
  };

  # ── niri config ───────────────────────────────────────────────────────────
  # niri-flake exposes a home-manager module for niri's config.kdl
  # Uncomment and extend once you've imported niri-flake's HM module:
  #
  # programs.niri.settings = {
  #   outputs."eDP-1" = {
  #     scale = 1.0;
  #   };
  #   binds = with config.lib.niri.actions; {
  #     "Mod+Return".action = spawn "kitty";
  #     "Mod+Space".action  = spawn "fuzzel";
  #     "Mod+Q".action      = close-window;
  #   };
  # };
  # ── XDG ──────────────────────────────────────────────────────────────────
  # xdg.portal is a system-level option; configured in configuration.nix
  xdg.enable = true;

  # # ── GTK theming ───────────────────────────────────────────────────────────
  # TODO eventually make theming fully declarative by finding oxocarbon flake
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

  # ── Environment variables ─────────────────────────────────────────────────
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # forces Electron/CEF apps to use Wayland
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    # NVIDIA-specific Wayland env vars
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1"; # fixes cursor rendering on NVIDIA+Wayland
  };
}
