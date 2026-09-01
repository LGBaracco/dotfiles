{ pkgs, ... }: {
  home.packages = with pkgs; [
    # --- Browsers ---
    firefox-bin

    # --- Desktop apps ---
    spotify-player
    mpv
    system-config-printer
    gparted
    kdePackages.partitionmanager
    nautilus
    proton-pass

    # --- terminals ---
    ghostty
    foot
    zellij

    # --- Editors ---
    neovide
    cursor-cli

    # --- Cli tools ---
    stow
    imv
    eza # ls
    zoxide # smarter cd
    bat
    yq
    jq
    gnumake
    fastfetch
    rclone

    # --- Fuzzy finders ---
    fzf
    ripgrep
    fd

    # --- TUI ---
    lazygit
    alsa-utils
    nvtopPackages.full
    htop
    btop
    dgop

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
    coreutils

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

    # --- Misc ---
    texliveMedium # emacs org/latex export
    mu
    isync
    imagemagick
    wl-clipboard
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    brightnessctl
    playerctl
    tabctl
    xwayland-satellite
  ];
}
