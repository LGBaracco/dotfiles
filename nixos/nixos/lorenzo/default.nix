{ pkgs, inputs, ... }: {
  imports = [
    ./git.nix
    ./home-packages.nix
    ./starfish.nix
    ./chromium.nix
    ./theming
    ./dcal.nix
    ./desktop-entries.nix
  ];

  # Neovim via nix-wrapper-modules (liveLua=true by default: ~/.config/nvim via stow)
  wrappers.neovim = {
    enable = true;
    # liveLua = false;  # uncomment to force rebuild after lua edits
  };

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
      # DMS writes ~/.config/ghostty/themes/dankcolors; keep Ghostty in sync.
      theme = "Oxocarbon";
      confirm-close-surface = false;
      font-size = 12;
    };
  };

  home.sessionPath = [
    "$HOME/.config/emacs/bin" # Doom emacs
    "$HOME/.local/bin"
  ];

  # ── Environment variables ────────────────────────────────────────────────
  #home.sessionVariables = {
  #};

}
