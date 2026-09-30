{ lib }:

let
  themeLib = import ./lib.nix { inherit lib; };

  dmsConfigDir = ../../../../DankMaterialShell/.config/DankMaterialShell;

  templates = {
    gtk = ./templates/gtk-colors.css;
    kde = ./templates/kcolorscheme.colors;
    kdeDark = ./templates/dark-kcolorscheme.colors;
    qtCt = ./templates/qtct-colors.conf;
  };

  generated = themeLib.generateFromDmsSettings {
    inherit dmsConfigDir templates;
    mode = "dark";
  };

in
{
  inherit generated;
  gtkBreezeColors = ./assets/gtk-breeze-colors.css;
}
