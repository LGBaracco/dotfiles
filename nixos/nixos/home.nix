{ config, pkgs, inputs, lib, ... }:

{
  home.stateVersion = "26.05";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ── User packages ─────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # --- Browsers ---
    brave

    # --- Editors / Dev ---
    vscode                     # or vscodium for the libre build
    emacs30-pgtk               # pgtk = pure GTK, best for Wayland; Doom goes on top

    # --- Dev tools ---
    git
    gh                         # GitHub CLI
    ripgrep                    # needed by Doom Emacs / Neovim telescope
    fd
    fzf
    bat
    eza                        # modern ls
    zoxide                     # smarter cd
    jq
    yq
    lazygit

    # --- Nix tooling ---
    nix-output-monitor         # prettier `nix build` output
    nvd                        # diff nixos generations
    alejandra                  # nix formatter

    # --- Python (scientific) ---
    (python312.withPackages (ps: with ps; [
      numpy
      scipy
      matplotlib
      pandas
      jupyter
      ipython
    ]))

    # --- Julia ---
    julia-bin                  # official Julia binary (faster than building from source)

    clang
    # --- Wayland / niri utilities ---
    # rofi-wayland              # alternative if you prefer rofi

    # --- Fonts / theming ---
    papirus-icon-theme
    catppuccin-gtk             # optional; remove if you don't want it

    # --- Misc ---
    dms-shell
    ghostty                    # terminal (works great with niri)
    foot
    mpv
    imv                        # image viewer
    zathura                    # PDF viewer
    xdg-utils
    brightnessctl
    playerctl
  ];

  # ── Brave / Chromium flags for Wayland + KWallet ──────────────────────────
  # Brave reads from ~/.config/brave-flags.conf
  home.file.".config/brave-flags.conf".text = ''
    --ozone-platform=wayland
    --enable-features=WaylandWindowDecorations
    --password-store=gnome
    # --password-store=kwallet6
  '';

  # ── Git ───────────────────────────────────────────────────────────────────
  programs.git = {
    enable      = true;
    settings = {

      user.email   = "lorenzobaracco01@gmail.com";
      user.name    = "LGBaracco";
      init.defaultBranch = "main";
      pull.rebase        = true;
      rebase.autoStash   = true;
    };
  };

  programs.gh = {
    enable	= true;
    settings.git_protocol = "https";
    };

  # ── Neovim ────────────────────────────────────────────────────────────────
  # Minimal bootstrap — assumes you manage your own config in ~/.config/nvim
  # programs.neovim = {
  #   enable        = true;
  #   defaultEditor = true;
  #   viAlias       = true;
  #   vimAlias      = true;
  # };
  
  # ── Doom Emacs ────────────────────────────────────────────────────────────
  # Doom is not packaged in nixpkgs; install it the normal way after first boot:
  #   git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
  #   ~/.config/emacs/bin/doom install
  # The emacs30-pgtk package above is the underlying Emacs binary Doom will use.
  # Add doom's bin to PATH:
  home.sessionPath = [ "$HOME/.config/emacs/bin" ];

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
      ll   = "eza -lah --icons";
      tree = "eza --tree --icons";
      #cat  = "bat";
      cd   = "z";                   # zoxide
      gs   = "git status";
      lg   = "lazygit";
      vi   = "nvim";
      vim  = "nvim";
      # Rebuild shortcut
      nrs  = "sudo nixos-rebuild switch --flake ~/nixos#nixlorenzo";  # CHANGE ME
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

  # ── GTK theming ───────────────────────────────────────────────────────────
  gtk = {
    enable = true;
    theme = {
      name    = "Catppuccin-Mocha-Standard-Blue-Dark";
      package = pkgs.catppuccin-gtk;
    };
    iconTheme = {
      name    = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # ── Cursor ────────────────────────────────────────────────────────────────
  home.pointerCursor = {
    gtk.enable  = true;
    name        = "Catppuccin-Mocha-Dark-Cursors";
    package     = pkgs.catppuccin-cursors.mochaDark;
    size        = 24;
  };

  # ── Environment variables ─────────────────────────────────────────────────
  home.sessionVariables = {
    NIXOS_OZONE_WL   = "1";         # forces Electron/CEF apps to use Wayland
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM  = "wayland";
    SDL_VIDEODRIVER  = "wayland";
    # NVIDIA-specific Wayland env vars
    GBM_BACKEND          = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS  = "1";   # fixes cursor rendering on NVIDIA+Wayland
  };
}
