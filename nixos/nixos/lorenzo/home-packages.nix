{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:

{
  home.packages = with pkgs; [
    # --- Browsers ---
    brave
    firefox-bin

    # --- Desktop apps ---
    p3x-onenote
    whatsapp-electron
    ghostty
    foot
    spotify-player
    mpv
    imv
    gparted
    nautilus

    # --- Editors / Dev ---
    vscode # or vscodium
    code-cursor

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
    zellij

    # --- Nix tooling ---
    nix-output-monitor # prettier `nix build` output
    nvd # diff nixos generations
    alejandra # nix formatter
    nixfmt # Doom compatible formatter

    # --- Python (scientific) ---
    uv
    python3
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

    # --- Julia ---
    julia-bin # official Julia binary (faster than building from source)

    # --- C/C++ ---
    clang
    cmake

    # --- Other languages ---
    sbcl # Common Lisp
    racket
    proselint # Markdown linter
    pandoc # Markdown syntax highlighting
    shellcheck

    # --- Fonts / theming ---
    #papirus-icon-theme

    # --- Misc ---
    brightnessctl
    playerctl
    fastfetch
  ];
}
