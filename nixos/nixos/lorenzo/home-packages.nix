{ pkgs, ... }: {
  home.packages = with pkgs; [

    # --- Desktop apps ---
    mpv
    system-config-printer
    proton-pass
    heroic
    firefox-bin
    nautilus

    # --- terminals ---
    ghostty
    foot
    tmux

    # --- Editors ---
    neovide

    # --- TUI ---
    spotify-player
    lazygit
    alsa-utils
    nvtopPackages.full
    htop
    btop
    dgop

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
    cursor-cli

    # --- Nix tooling ---
    nix-output-monitor # prettier `nix build` output
    nvd # diff nixos generations
    nh
    nixfmt # Doom compatible formatter
    nil # nix lsp

    # --- Python ---
    uv
    python3
    # (python3.withPackages (
    #   ps: with ps; [
    #     torch-bin
    #     ipython
    #   ]
    # ))

    # --- Julia ---
    julia-bin

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
    # Quarto 1.10 emits pandoc's new `syntax-highlighting` key; nixpkgs pandoc is
    # still 3.7 (`highlight-style`). Patch until pandoc >= 3.8 lands (nixpkgs#519484).
    (quarto.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace bin/quarto.js \
          --replace-fail "syntax-highlighting" "highlight-style"
      '';
    }))
    proselint # Markdown linter
    pandoc # Markdown syntax highlighting
    shellcheck

    # --- Fuzzy finders ---
    fzf
    ripgrep
    fd

    # --- Misc ---
    texliveFull # LaTeX (Neovim VimTeX + emacs org export)
    (zathura.override {
      plugins = with zathuraPkgs; [ zathura_pdf_mupdf ];
    })
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
