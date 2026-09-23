{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
# HPC / Apptainer profile: same plugin surface as module.nix (Quarto/Molten kept),
# but curated treesitter + trimmed LSPs/formatters. Lua stays live via stdpath
# (bind-mount $PROJECT/hpc-env/config). See hpc/README.md.
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
      noice-nvim
      nvim-notify
      nui-nvim
      plenary-nvim

      which-key-nvim
      hop-nvim
      precognition-nvim
      comment-nvim
      nvim-surround
      smart-splits-nvim
      todo-comments-nvim
      toggleterm-nvim
      project-nvim
      nvim-autopairs
      luasnip
      friendly-snippets

      vimtex
      jupytext-nvim

      blink-cmp
      conform-nvim
      lazydev-nvim
      nvim-lightbulb
      (nvim-treesitter.withPlugins (
        grammars: with grammars; [
          bash
          bibtex
          c
          cmake
          comment
          cpp
          css
          cuda
          diff
          dockerfile
          fish
          fortran
          git_config
          git_rebase
          gitattributes
          gitcommit
          gitignore
          html
          javascript
          json
          json5
          julia
          latex
          lua
          luadoc
          luap
          make
          markdown
          markdown_inline
          nix
          python
          query
          r
          regex
          rst
          rust
          toml
          tsx
          typescript
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
      cinnamon-nvim
      highlight-undo-nvim
      indent-blankline-nvim
      nvim-colorizer-lua
      vim-illuminate
      fastaction-nvim
      nvim-navbuddy

      telescope-nvim
      neo-tree-nvim
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
    ];
  };

  config.runtimePkgs = with pkgs; [
    ripgrep
    fd
    tree-sitter
    imagemagick
    python3Packages.jupytext

    # Formatters (conform) — no nixfmt; ruff/ty stay uv tools on $PROJECT
    stylua
    shfmt
    clang-tools
    prettier
    astyle
    taplo
    tex-fmt
    deno
    gersemi
    sqlfluff
    jsonfmt

    julia-bin

    # LSPs — desktop/Nix/Java/QML/Docker/fennel/fish dropped
    bash-language-server
    harper
    lemminx
    lua-language-server
    marksman
    neocmakelsp
    sqls
    superhtml
    texlab
    vscode-langservers-extracted
  ];
}
