{ pkgs, inputs, lib, config, ... }:

{
  home.packages = with pkgs; [
    # --- Browsers ---
    brave

    # --- Desktop apps ---
    p3x-onenote
    whatsapp-electron
    ghostty
    foot
    spotify
    mpv
    imv
    gparted
    nautilus

    # --- Editors / Dev ---
    vscode # or vscodium 
    neovim

    # --- Dev tools ---
    stow
    ripgrep # fuzzy finder
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
    uv

    # --- Julia ---
    julia-bin # official Julia binary (faster than building from source)

    # --- C/C++ ---
    clang
    cmake

    sbcl # Common Lisp
    racket
    proselint # Markdown linter
    pandoc # Markdown syntax highlighting
    shellcheck

    # --- Fonts / theming ---
    #papirus-icon-theme

    # --- Misc ---
    xdg-utils
    brightnessctl
    playerctl
    fastfetch
  ];
}
