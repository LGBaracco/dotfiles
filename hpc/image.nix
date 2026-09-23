{
  pkgs,
  neovim-hpc,
}:
let
  # Same Quarto patch as home-packages.nix (pandoc highlight-style key).
  quarto = pkgs.quarto.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace bin/quarto.js \
        --replace-fail "syntax-highlighting" "highlight-style"
    '';
  });

  hpc-devbox = pkgs.buildEnv {
    name = "hpc-devbox";
    paths = [
      neovim-hpc
      pkgs.tmux
      pkgs.fish
      pkgs.starship
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnused
      pkgs.gnugrep
      pkgs.gawk
      pkgs.less
      pkgs.ncurses
      pkgs.cacert
      pkgs.git
      pkgs.openssh
      pkgs.curl
      pkgs.wget
      pkgs.uv
      pkgs.python3
      pkgs.ripgrep
      pkgs.fd
      pkgs.fzf
      pkgs.eza
      pkgs.bat
      pkgs.lazygit
      pkgs.zoxide
      pkgs.htop
      pkgs.jq
      pkgs.gnumake
      pkgs.file
      pkgs.which
      quarto
      pkgs.julia-bin
    ];
    pathsToLink = [
      "/bin"
      "/share"
      "/etc"
    ];
  };
in
{
  inherit hpc-devbox quarto;

  oci = pkgs.dockerTools.buildLayeredImage {
    name = "nvim-hpc";
    tag = "latest";
    contents = [
      hpc-devbox
      pkgs.dockerTools.binSh
      pkgs.dockerTools.usrBinEnv
      pkgs.dockerTools.caCertificates
    ];
    config = {
      Env = [
        "PATH=/bin"
        "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
        "TERM=xterm-256color"
        "EDITOR=nvim"
        "VISUAL=nvim"
      ];
      Cmd = [ "/bin/bash" ];
      WorkingDir = "/";
    };
    maxLayers = 120;
  };
}
