{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
# Plugin and tool sets come from pack.json, shared with the non-Nix bootstrap
# (lua/config/pack.lua: vim.pack + mason). Here every entry with a `nix` attr is
# used: `desktopOnly` and the treesitter lists only matter off Nix, `nix = null`
# entries (mason.nvim, uv tools) are skipped. List order is kept, so the
# wrapper's PATH suffix follows the `tools` order.
let
  manifest = lib.importJSON ./pack.json;
  fromAttr = set: path: lib.getAttrFromPath (lib.splitString "." path) set;

  nixPlugins = builtins.filter (p: p.nix or null != null) manifest.plugins;
  plugins = pred: map (p: fromAttr pkgs.vimPlugins p.nix) (builtins.filter pred nixPlugins);

  # Tools that need more than an attribute lookup.
  toolOverrides = with pkgs; {
    # Quarto 1.10 emits pandoc's new `syntax-highlighting` key; nixpkgs pandoc is
    # still 3.7 (`highlight-style`). Patch until pandoc >= 3.8 lands (nixpkgs#519484).
    quarto = quarto.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace bin/quarto.js \
          --replace-fail "syntax-highlighting" "highlight-style"
      '';
    });
    # Same expression as home-packages, so NixOS shares the store path.
    zathura = zathura.override {
      plugins = with zathuraPkgs; [ zathura_pdf_mupdf ];
    };
  };
  tool = attr: toolOverrides.${attr} or (fromAttr pkgs attr);
  # clang-tools and vscode-langservers-extracted each back two `bin` entries.
  toolAttrs = lib.unique (map (t: t.nix) (builtins.filter (t: t.nix or null != null) manifest.tools));
in
{
  imports = [ wlib.wrapperModules.neovim ];

  options.liveLua = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      When true, load Lua from vim.fn.stdpath("config") (~/.config/nvim).
      When false, bake this directory into the store (pure).
    '';
  };

  config.settings.config_directory =
    if config.liveLua then lib.generators.mkLuaInline "vim.fn.stdpath('config')" else ./.;

  # Lazy-load library (must be on start so Lua can require it at boot).
  config.specs.lze = {
    lazy = false;
    data = plugins (p: p.group or null == "lze");
  };

  # Startup plugins (always packadd'd). Eager on purpose: vimtex (inverse search
  # breaks if lazy-loaded), jupytext.nvim (owns BufReadCmd *.ipynb), nvim-lspconfig
  # (lsp/ configs that vim.lsp.config merges; a dependency nixpkgs would add anyway).
  config.specs.core = {
    lazy = false;
    after = [ "lze" ];
    data = plugins (p: p.group or null != "lze" && !(p.lazy or false));
  };

  # Deferred plugins (opt/ until lze packadd's them).
  config.specs.deferred = {
    lazy = true;
    data = plugins (p: p.lazy or false);
  };

  # Tools used by plugins, formatters (conform), LSPs, REPL runtimes. ruff/ty are
  # uv tools on ~/.local/bin (`nix = null`), see home-packages Python note.
  config.runtimePkgs = map tool toolAttrs;
}
