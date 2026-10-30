{
  flake.modules.homeManager.lorenzo =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      themeGen = import ./_generate.nix { inherit lib; };
      generated = themeGen.generated;
      themeLib = import ./_lib.nix { inherit lib; };

      kdeColorSchemePath = "${config.home.homeDirectory}/.local/share/color-schemes/DankMatugen.colors";

      # Qt6 uses the kde platform theme (see sessionVariables), which reads this file directly.
      # Icons/widgetStyle also live in kdedefaults/, but that dir is only on XDG_CONFIG_DIRS in Plasma.
      kdeglobals = themeLib.kdeglobalsHeader generated.kdeDarkScheme + ''

        [Icons]
        Theme=yet-another-monochrome-icon-set

        [KDE]
        widgetStyle=Breeze
      '';

      qtCtConf = ''
        [Appearance]
        color_scheme_path=${kdeColorSchemePath}
        custom_palette=true
        icon_theme=yet-another-monochrome-icon-set
      '';

      gtkCssImports = ''
        @import 'dank-colors.css';
        @import 'colors.css';
      '';

      # Overwrite Dux Shell/imperative leftovers without fighting stale .bak files
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
          name = "yet-another-monochrome-icon-set";
          package = pkgs.yamis-icon-theme;
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
          icon-theme = "yet-another-monochrome-icon-set";
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
        # GTK3 FileChooserNative -> portal (dfiles). GTK4 >= 4.22 uses the portal by default.
        GTK_USE_PORTAL = "1";
        QT_QPA_PLATFORM = "wayland";
        # Qt6: kde theme (colors/icons/style from kdeglobals) + portal file dialogs (dfiles).
        # Not xdgdesktopportal: its base theme comes from XDG_CURRENT_DESKTOP, and "niri" yields
        # the generic theme. Qt5 has no kde theme installed, so it stays on gtk3.
        QT_QPA_PLATFORMTHEME = "gtk3";
        QT_QPA_PLATFORMTHEME_QT6 = "kde";
        PLASMA_INTEGRATION_USE_PORTAL = "1";
      };

      home.file.".local/share/color-schemes/DankMatugen.colors" = forceText generated.kdeScheme;
      home.file.".local/share/color-schemes/DankMatugenDark.colors" = forceText generated.kdeDarkScheme;

      # gtk.enable also writes settings.ini; force so activation never fights Dux Shell leftovers
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
          Theme=yet-another-monochrome-icon-set

          [KDE]
          widgetStyle=Breeze
        '';

        "qt5ct/qt5ct.conf" = forceText qtCtConf;
        "qt6ct/qt6ct.conf" = forceText qtCtConf;
        "qt5ct/colors/matugen.conf" = forceText generated.qtCtConf;
        "qt6ct/colors/matugen.conf" = forceText generated.qtCtConf;
      };
    };
}
