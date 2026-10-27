{
  flake.modules.homeManager.lorenzo =
    { pkgs, ... }: {
      home.packages = with pkgs; [

        # --- Desktop apps ---
        nautilus
        nextcloud-client

        # --- terminals ---
        ghostty
        foot
        tmux

        # --- TUI ---
        lazygit
        alsa-utils
        htop
        claude-code

        # --- Cli tools ---
        stow
        imv
        eza # ls
        zoxide # cd
        starship
        babelfish # translates hm-session-vars.sh for fish
        fastfetch
        bat
        jq

        # --- Nix tooling ---
        nix-output-monitor # prettier `nix build` output
        nvd # diff nixos generations
        nh

        # --- Fuzzy finders ---
        fzf
        ripgrep
        fd

        # --- Misc ---
        wl-clipboard
        libsForQt5.qt5ct
        qt6Packages.qt6ct
        brightnessctl
        playerctl
        xwayland-satellite
      ];
    };

  flake.modules.homeManager.workstation =
    { pkgs, ... }:
    let
      # scheme-medium + what my documents, org export and Quarto PDFs need on top.
      # A document failing with "x.sty not found": add x's TeX Live package here.
      latex = pkgs.texliveMedium.withPackages (
        ps: with ps; [
          # my documents
          a4wide
          apacite
          cleveref
          footmisc
          fourier
          glossaries
          imakeidx
          pgfplots
          preprint
          supertabular
          titlesec
          tocbibind
          wrapfig
          # org-mode export
          capt-of
          # Quarto/pandoc PDF template
          csquotes
          fontawesome5
          framed
          multirow
          tcolorbox
          upquote
          xurl
          # tcolorbox libraries (skins, breakable, listingsutf8)
          tikzfill
          pdfcol
          listingsutf8
        ]
      );
    in
    {
      home.packages = with pkgs; [

        # --- Desktop apps ---
        mpv
        system-config-printer
        proton-pass
        heroic
        firefox-bin
        spotify
        thunderbird-bin
        stable.zotero
        zoom-us
        godot

        # --- Editors ---
        neovide

        # --- TUI ---
        spotify-player
        btop-cuda # NVIDIA GPU stats (driver runpath); no global cudaSupport
        dux-gop
        opencode

        # --- Cli tools ---
        yq
        gnumake
        rclone

        # --- Nix tooling ---
        nixfmt # Doom compatible formatter
        nil # nix lsp

        # --- Python ---
        # debugpy, ipython, jupyter, pynvim) are uv-managed (`uv tool` / `uv run`).
        uv
        python3

        # --- Julia ---
        julia-bin

        # --- Javascript/Typescript
        nodejs

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
        # quarto (patched) lives in the Neovim wrapper: neovim/.config/nvim/module.nix
        proselint # Markdown linter
        pandoc # Markdown syntax highlighting
        shellcheck

        # --- Misc ---
        latex # LaTeX (Neovim VimTeX + emacs org export)
        (zathura.override {
          plugins = with zathuraPkgs; [ zathura_pdf_mupdf ];
        })
        imagemagick
        tabctl
      ];
    };
}
