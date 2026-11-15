{
  flake.modules.nixos.common = {
    # AppImages run like normal binaries: `chmod +x foo.AppImage && ./foo.AppImage`.
    # binfmt hands any AppImage (type 1 and 2) to appimage-run, which unpacks it into
    # an FHS env with the usual desktop libs. The module also enables FUSE.
    # If an AppImage still misses a library, add it via
    #   package = pkgs.appimage-run.override { extraPkgs = pkgs: [ pkgs.<lib> ]; };
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}
