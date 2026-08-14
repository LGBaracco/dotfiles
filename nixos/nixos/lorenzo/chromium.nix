{ pkgs, ... }:

let
  # Universal function to inject flags into ANY package after it finishes building
  withGnomeKeyring =
    pkg:
    pkgs.symlinkJoin {
      name = "${pkg.pname or pkg.name}-keyring-wrapped";
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for bin in $out/bin/*; do
          if [ -L "$bin" ]; then
            target=$(readlink -f "$bin")
            rm "$bin"
            makeWrapper "$target" "$bin" --add-flags "--password-store=gnome-libsecret"
          fi
        done
      '';
    };
in
{
  # Simply wrap whichever apps you use in your package list:
  home.packages = [
    (withGnomeKeyring pkgs.brave)
    (withGnomeKeyring pkgs.vscode)
    (withGnomeKeyring pkgs.helium)
    (withGnomeKeyring pkgs.code-cursor)
    (withGnomeKeyring pkgs.discord)
    (withGnomeKeyring pkgs.whatsapp-electron)
    (withGnomeKeyring pkgs.p3x-onenote)
  ];
}
