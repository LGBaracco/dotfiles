{
  pkgs,
  lib,
  config,
  ...
}:
let
  themeGen = import ./generate.nix { inherit lib; };
  generated = themeGen.generated;
  themeLib = import ./lib.nix { inherit lib; };

  kdeColorSchemePath = "${config.home.homeDirectory}/.local/share/color-schemes/DankMatugen.colors";

  kdeglobals = themeLib.kdeglobalsHeader generated.kdeDarkScheme;

  qtCtConf = ''
    [Appearance]
    color_scheme_path=${kdeColorSchemePath}
    custom_palette=true
    icon_theme=breeze
  '';

  gtkCssImports = ''
    @import 'dank-colors.css';
    @import 'colors.css';
  '';

  # Overwrite DMS/imperative leftovers without fighting stale .bak files
  forceText = text: {
    inherit text;
    force = true;
  };
  forceSource = source: {
    inherit source;
    force = true;
  };

in
{
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "breeze-dark";
      package = pkgs.kdePackages.breeze-icons;
    };
    cursorTheme = {
      name = "breeze_cursors";
      package = pkgs.kdePackages.breeze;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "adw-gtk3-dark";
      icon-theme = "breeze-dark";
      cursor-theme = "breeze_cursors";
    };
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    name = "breeze_cursors";
    package = pkgs.kdePackages.breeze;
    size = 24;
  };

  home.sessionVariables = {
    GTK_THEME = "adw-gtk3-dark";
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "gtk3";
    QT_QPA_PLATFORMTHEME_QT6 = "gtk3";
  };

  home.file.".local/share/color-schemes/DankMatugen.colors" = forceText generated.kdeScheme;
  home.file.".local/share/color-schemes/DankMatugenDark.colors" = forceText generated.kdeDarkScheme;

  # gtk.enable also writes settings.ini; force so activation never fights DMS leftovers
  xdg.configFile = {
    "gtk-3.0/settings.ini".force = true;
    "gtk-3.0/gtk.css" = forceText gtkCssImports;
    "gtk-3.0/dank-colors.css" = forceText generated.gtkCss;
    "gtk-3.0/colors.css" = forceSource themeGen.gtkBreezeColors;

    "gtk-4.0/settings.ini".force = true;
    "gtk-4.0/gtk.css" = forceText ''
      @import url("dank-colors.css");
      @import 'colors.css';
    '';
    "gtk-4.0/dank-colors.css" = forceText generated.gtkCss;
    "gtk-4.0/colors.css" = forceSource themeGen.gtkBreezeColors;

    "kdeglobals" = forceText kdeglobals;

    "kdedefaults/kdeglobals" = forceText ''
      [General]
      ColorScheme=DankMatugenDark

      [Icons]
      Theme=breeze-dark

      [KDE]
      widgetStyle=Breeze
    '';

    "qt5ct/qt5ct.conf" = forceText qtCtConf;
    "qt6ct/qt6ct.conf" = forceText qtCtConf;
    "qt5ct/colors/matugen.conf" = forceText generated.qtCtConf;
    "qt6ct/colors/matugen.conf" = forceText generated.qtCtConf;
  };
}
