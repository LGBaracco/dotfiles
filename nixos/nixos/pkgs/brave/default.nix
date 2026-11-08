# brave was dropped from nixpkgs (unstable and 26.05) on 2026-11-03; this is the vendored
# derivation, used via the overlay in modules/overlays.nix as pkgs.brave.
#
# Bump (Brave ships a stable release every ~1-2 weeks; security fixes ride on these):
#   1. Latest stable: gh api 'repos/brave/brave-browser/releases?per_page=50' \
#        --jq '[.[] | select(.name | test("^Release"))][0].tag_name'
#   2. Set `version` below, then:
#        nix store prefetch-file --json https://github.com/brave/brave-browser/releases/download/v<ver>/brave-browser_<ver>_amd64.deb | jq -r .hash
#   3. Paste the hash.
# Delete this directory and the overlay entry if brave returns to nixpkgs.
import ./make-brave.nix rec {
  pname = "brave";
  version = "1.99.55";

  archives.x86_64-linux = {
    url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-browser_${version}_amd64.deb";
    hash = "sha256-Nk6VSirYTVuj4OIXoinVhzxK5xB9FeYSDkIHUpU5yI0=";
  };

  # Flavor data from nixpkgs' brave/default.nix ("browser" flavor).
  optStem = "brave";
  fileStem = "brave-browser";
  appIdStem = "com.brave.Browser";
  darwinStem = "Brave Browser";
  changelogFile = "CHANGELOG_DESKTOP.md";
  homepage = "https://brave.com/";
  innerBinary = "brave";
}
