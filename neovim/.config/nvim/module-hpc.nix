{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
# HPC (JSC) profile: module.nix minus desktop-only plugins (LaTeX, noice/notify,
# cinnamon, neo-tree, precognition) and with curated treesitter grammars.
# Built on the desktop as the `nvim-hpc` flake output; hpc/bundle.nix packs its
# nvim-packdir with a release nvim into the self-contained nvim-hpc.tar.gz that
# `nvim-hpc-sync` installs on the cluster. runtimePkgs stay for local testing
# only (/nix/store binaries can't run there); the bundle ships static tools.
# Lua guards absent plugins via config.has.
{
  imports = [ wlib.wrapperModules.neovim ];

  options.liveLua = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      When true, load Lua from vim.fn.stdpath("config").
      When false, bake this directory into the store (pure).
    '';
  };

  config.settings.config_directory =
    if config.liveLua then lib.generators.mkLuaInline "vim.fn.stdpath('config')" else ./.;

  config.specs.lze = {
    lazy = false;
    data = with pkgs.vimPlugins; [
      lze
      lzextras
    ];
  };

  config.specs.core = {
    lazy = false;
    after = [ "lze" ];
    data = with pkgs.vimPlugins; [
      oxocarbon-nvim
      dashboard-nvim
      lualine-nvim
      nvim-navic
      nvim-web-devicons
      fidget-nvim
      nui-nvim
      plenary-nvim

      which-key-nvim
      hop-nvim
      comment-nvim
      nvim-surround
      smart-splits-nvim
      todo-comments-nvim
      toggleterm-nvim
      project-nvim
      nvim-autopairs
      luasnip
      friendly-snippets

      jupytext-nvim

      blink-cmp
      conform-nvim
      lazydev-nvim
      nvim-lightbulb
      (nvim-treesitter.withPlugins (
        grammars: with grammars; [
          bash
          c
          cmake
          comment
          cpp
          cuda
          diff
          fortran
          git_config
          git_rebase
          gitattributes
          gitcommit
          gitignore
          json
          julia
          lua
          luadoc
          luap
          make
          markdown
          markdown_inline
          python
          query
          regex
          rst
          toml
          vim
          vimdoc
          yaml
        ]
      ))
      nvim-treesitter-textobjects
      nvim-treesitter-context
      nvim-ts-autotag
    ];
  };

  config.specs.deferred = {
    lazy = true;
    data = with pkgs.vimPlugins; [
      nvim-scrollbar
      highlight-undo-nvim
      indent-blankline-nvim
      nvim-colorizer-lua
      vim-illuminate
      fastaction-nvim
      nvim-navbuddy

      telescope-nvim
      oil-nvim
      grug-far-nvim
      undotree
      diffview-nvim
      img-clip-nvim
      snacks-nvim
      run-nvim

      gitsigns-nvim
      neogit

      otter-nvim
      nvim-docs-view
      trouble-nvim

      nvim-dap
      nvim-dap-ui
      nvim-nio

      iron-nvim
      molten-nvim
      quarto-nvim
      render-markdown-nvim

      vim-be-good
    ];
  };

  config.runtimePkgs = with pkgs; [
    ripgrep
    fd
    tree-sitter
    imagemagick
    python3Packages.jupytext

    # Formatters (conform) — no nixfmt; ruff/ty stay uv tools
    stylua
    shfmt
    clang-tools
    prettier
    astyle
    taplo
    deno
    gersemi
    sqlfluff
    jsonfmt

    julia-bin

    # LSPs — desktop/Nix/Java/QML/Docker/fennel/fish/TeX dropped
    bash-language-server
    harper
    lemminx
    lua-language-server
    marksman
    neocmakelsp
    sqls
    superhtml
    vscode-langservers-extracted
  ];
}
