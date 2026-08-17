{ pkgs, ... }: {
  home.packages = with pkgs; [
    # --- Browsers ---
    firefox-bin

    # --- Desktop apps ---
    spotify-player
    mpv
    imv
    gparted
    nautilus
    ghostty
    foot

    # --- Editors / Dev ---
    neovide
    jetbrains.pycharm

    # --- Dev tools ---
    stow
    fd
    ripgrep
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
    nixfmt # Doom compatible formatter
    nil

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

    # --- Rust ---
    cargo
    rustc

    # --- Other languages ---
    sbcl # Common Lisp
    racket
    proselint # Markdown linter
    pandoc # Markdown syntax highlighting
    shellcheck

    # --- Gaming ---
    heroic

    # --- Fonts / theming ---
    #papirus-icon-theme

    # --- Misc ---
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    brightnessctl
    playerctl
    xwayland-satellite
    fastfetch
    proton-pass
  ];
}
