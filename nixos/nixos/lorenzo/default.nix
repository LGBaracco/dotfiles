{ pkgs, inputs, ... }: {
  imports = [
    ./git.nix
    ./home-packages.nix
    ./starfish.nix
    ./chromium.nix
    ./theming
    ./dcal.nix
  ];

  # Neovim via nix-wrapper-modules (flake at ~/dotfiles/neovim/.config/nvim).
  wrappers.neovim.enable = true;

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
  #home.sessionVariables = {
  #};

}
