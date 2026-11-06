{
  # Dux Files (dfiles): default file manager. Owns org.freedesktop.FileManager1
  # ("show in folder"), serves the portal FileChooser (preferred in desktop.nix),
  # and runs as a hidden session daemon so Mod+E opens instantly.
  flake.modules.nixos.common = { pkgs, ... }: {
    programs.dux-files = {
      enable = true;
      package = pkgs.unstable.dux-files;
      portal.enable = true;
      systemd.enable = true;
    };

    # System-level default; ~/.config/mimeapps.list has no inode/directory entry, so this wins.
    xdg.mime.defaultApplications."inode/directory" = "dev.duxlabs.files.desktop";
  };
}
