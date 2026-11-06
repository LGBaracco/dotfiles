{
  flake.modules.homeManager.lorenzo =
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
        unstable.heroic
        firefox-bin
        spotify
        nautilus
        nextcloud-client
        thunderbird-bin
        stable.zotero
        zoom-us
        unstable.godot

        # --- terminals ---
        unstable.ghostty
        foot
        tmux

        # --- Editors ---
        neovide

        # --- TUI ---
        spotify-player
        unstable.lazygit
        alsa-utils
        htop
        btop-cuda # NVIDIA GPU stats (driver runpath); no global cudaSupport
        unstable.dux-gop
        unstable.claude-code
        unstable.opencode

        # --- Cli tools ---
        stow
        imv
        eza # ls
        zoxide # cd
        starship
        babelfish # translates hm-session-vars.sh for fish
        fastfetch
        bat
        yq
        jq
        gnumake
        rclone

        # --- Nix tooling ---
        nix-output-monitor # prettier `nix build` output
        nvd # diff nixos generations
        nh
        nixfmt # Doom compatible formatter
        nil # nix lsp

        # --- Python ---
        # debugpy, ipython, jupyter, pynvim) are uv-managed (`uv tool` / `uv run`).
        unstable.uv
        python3

        # --- Julia ---
        unstable.julia-bin

        # --- Javascript/Typescript
        nodejs

        # --- C/C++ ---
        clang
        cmake
        coreutils

        # --- Rust ---
        unstable.cargo
        unstable.rustc

        # --- Other languages ---
        sbcl # Common Lisp
        racket
        # quarto (patched) lives in the Neovim wrapper: neovim/.config/nvim/module.nix
        proselint # Markdown linter
        pandoc # Markdown syntax highlighting
        shellcheck

        # --- Fuzzy finders ---
        fzf
        ripgrep
        fd

        # --- Misc ---
        latex # LaTeX (Neovim VimTeX + emacs org export)
        # unstable: same expression as the (unstable) Neovim wrapper, so the store path is shared
        (unstable.zathura.override {
          plugins = with unstable.zathuraPkgs; [ zathura_pdf_mupdf ];
        })
        imagemagick
        wl-clipboard
        libsForQt5.qt5ct
        qt6Packages.qt6ct
        brightnessctl
        playerctl
        tabctl
        unstable.xwayland-satellite
      ];
    };
}
