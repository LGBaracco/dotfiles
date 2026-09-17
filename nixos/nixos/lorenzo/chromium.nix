{ pkgs, ... }:

let
  # Wrap Chromium/Electron bins and rewrite .desktop Exec= paths that otherwise
  # bypass the wrapper (absolute /nix/store/.../bin/... from the original pkg).
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

        # Packages like discord symlink the whole share/ tree into the store.
        # Rewrite desktop files via a temp dir, then materialize share/applications
        # under $out so we never write through a read-only symlink.
        if [ -d "$out/share/applications" ]; then
          tmp=$(mktemp -d)
          for desktop in "$out/share/applications"/*.desktop; do
            [ -e "$desktop" ] || continue
            name=$(basename "$desktop")
            cp "$(readlink -f "$desktop")" "$tmp/$name"
            # Point absolute Exec=/TryExec= at our wrapped bins (CLI name-only Exec= is fine via PATH).
            sed -i -E "s#^(Exec|TryExec)=/nix/store/[^/]+/bin/#\1=$out/bin/#g" "$tmp/$name"
          done

          if [ -L "$out/share" ]; then
            share_target=$(readlink -f "$out/share")
            rm "$out/share"
            mkdir -p "$out/share"
            for entry in "$share_target"/*; do
              [ -e "$entry" ] || continue
              name=$(basename "$entry")
              [ "$name" = applications ] && continue
              ln -s "$entry" "$out/share/$name"
            done
          else
            rm -rf "$out/share/applications"
          fi

          mkdir -p "$out/share/applications"
          cp "$tmp"/*.desktop "$out/share/applications/"
          rm -rf "$tmp"
        fi
      '';
    };
in
{
  home.packages = [
    (withGnomeKeyring pkgs.brave)
    (withGnomeKeyring pkgs.vscode)
    (withGnomeKeyring pkgs.helium)
    (withGnomeKeyring pkgs.discord)
    (withGnomeKeyring pkgs.code-cursor)
    (withGnomeKeyring pkgs.whatsapp-electron)
    (withGnomeKeyring pkgs.p3x-onenote)
  ];
}
