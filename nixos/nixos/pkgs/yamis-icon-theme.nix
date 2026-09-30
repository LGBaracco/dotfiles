{
  lib,
  stdenvNoCC,
  fetchFromBitbucket,
  gtk3,
  python3,
  hicolor-icon-theme,
  papirus-icon-theme,
  kdePackages,
  # GTK fallback for ColorScheme-Text (Plasma recolors; GTK uses this hex).
  # Oxocarbon Purple primary from myoxocarbon/theme.json.
  fallbackColor ? "#be95ff",
}:

stdenvNoCC.mkDerivation {
  pname = "yamis-icon-theme";
  version = "1.5.7";

  src = fetchFromBitbucket {
    owner = "dirn-typo";
    repo = "yet-another-monochrome-icon-set";
    rev = "367da5db6c03ac581e7105da071f2b961d587a2a";
    hash = "sha256-+9nRIn1xfjSCuf3E18IeCX/nPSvaQNQynjT/OCKHosM=";
  };

  nativeBuildInputs = [
    gtk3
    python3
  ];

  # index.theme: Inherits=Papirus-Dark,breeze-dark,...
  propagatedBuildInputs = [
    hicolor-icon-theme
    papirus-icon-theme
    kdePackages.breeze-icons
  ];

  # breeze-icons propagates qtbase
  dontWrapQtApps = true;

  dontDropIconThemeCache = true;

  installPhase = ''
    runHook preInstall

    themeDir=$out/share/icons/yet-another-monochrome-icon-set
    mkdir -p "$themeDir"
    cp -a . "$themeDir"
    rm -rf "$themeDir"/.git

    ${python3.interpreter} ${./yamis-fix-gtk.py} "$themeDir" ${lib.escapeShellArg fallbackColor}

    gtk-update-icon-cache --force "$themeDir"

    runHook postInstall
  '';

  meta = {
    description = "Yet Another Monochrome Icon Set for KDE Plasma";
    homepage = "https://bitbucket.org/dirn-typo/yet-another-monochrome-icon-set";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
