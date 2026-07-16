{ pkgs, inputs, lib, config, ... }:

{
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
    gparted

    # --- Nix tooling ---
    nix-output-monitor # prettier `nix build` output
    nvd # diff nixos generations
    alejandra # nix formatter
    nixfmt # Doom compatible formatter
    nix-index

    # --- Python (scientific) ---
    # (python3.withPackages (
    #   ps: with ps; [
    #     numpy
    #     scipy
    #     # torch-bin
    #     matplotlib
    #     pandas
    #     jupyter
    #     ipython
    #   ]
    # ))
    # uv

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
    ghostty
    foot
    mpv
    imv
    xdg-utils
    brightnessctl
    playerctl
    fastfetch
    spotify
  ];
}
