{ inputs, ... }:
{
  # Dux Files (dfiles), trial install. Deliberately not using the upstream
  # nixosModule: no portal file chooser, no autostart service, and the
  # org.freedesktop.FileManager1 D-Bus service is stripped so it can't take
  # "show in folder" away from Nautilus. Launch with `dfiles`.
  flake.modules.homeManager.lorenzo =
    { pkgs, ... }:
    {
      home.packages = [
        (inputs.dux-files.packages.${pkgs.stdenv.hostPlatform.system}.dux-files.overrideAttrs (old: {
          postInstall = old.postInstall + ''
            rm $out/share/dbus-1/services/dev.duxlabs.files.FileManager1.service
          '';
        }))
      ];
    };
}
