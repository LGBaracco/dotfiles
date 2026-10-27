{ lib }:

let
  themeLib = import ./_lib.nix { inherit lib; };

  duxConfigDir = ../../../../DankMaterialShell/.config/DankMaterialShell;

  templates = {
    gtk = ./templates/gtk-colors.css;
    kde = ./templates/kcolorscheme.colors;
    kdeDark = ./templates/dark-kcolorscheme.colors;
    qtCt = ./templates/qtct-colors.conf;
  };

  generated = themeLib.generateFromDuxSettings {
    inherit duxConfigDir templates;
    mode = "dark";
  };

in
{
  inherit generated;
  gtkBreezeColors = ./assets/gtk-breeze-colors.css;
}
