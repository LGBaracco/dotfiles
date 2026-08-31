{ lib }:

let
  themeLib = import ./lib.nix { inherit lib; };

  themeJsonPath = ../../../../DankMaterialShell/.config/DankMaterialShell/themes/myoxocarbon/theme.json;

  templates = {
    gtk = ./templates/gtk-colors.css;
    kde = ./templates/kcolorscheme.colors;
    kdeDark = ./templates/dark-kcolorscheme.colors;
    qtCt = ./templates/qtct-colors.conf;
  };

  generated = themeLib.generateFromTheme {
    inherit themeJsonPath templates;
    variant = "Purple";
    mode = "dark";
  };

in
{
  inherit generated;
  gtkBreezeColors = ./assets/gtk-breeze-colors.css;
}
