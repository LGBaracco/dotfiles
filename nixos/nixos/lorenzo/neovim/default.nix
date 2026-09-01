{
  pkgs,
  lib,
  ...
}:
let
  keymaps = import ./keymaps.nix;
  languages = import ./languages.nix;
  appearance = import ./appearance.nix;
  plugins = import ./plugins.nix { inherit pkgs lib; };
in
{

  programs.nvf = {
    enable = true;

    settings.vim = lib.recursiveUpdate (lib.recursiveUpdate {
      globals.mapleader = " ";
      globals.maplocalleader = ",";

      inherit keymaps;

      opts = {
        shada.enable = true;
        expandtab = true;
        smartindent = true;
        shiftwidth = 4;
        softtabstop = 4;
        tabstop = 4;
        scrolloff = 6;
        sidescrolloff = 3;
        timeoutlen = 5000;
      };

      # Two-spacing for nix and configuration find_files
      autocmds = [
        {
          event = [ "FileType" ];
          pattern = [
            "nix"
            "json"
            "yaml"
            "toml"
            "xml"
          ];
          command = "setlocal shiftwidth=2 tabstop=2 softtabstop=2";
        }
      ];

      spellcheck = {
        enable = false;
      };

      inherit languages;
    } appearance) plugins;
  };
}
