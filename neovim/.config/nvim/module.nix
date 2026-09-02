inputs:
{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
{
  imports = [ wlib.wrapperModules.neovim ];

  # Pure: bake this directory (init.lua + lua/) into the store.
  config.settings.config_directory = ./.;

  # Lazy-load library (must be on start so Lua can require it at boot).
  config.specs.lze = {
    lazy = false;
    data = with pkgs.vimPlugins; [
      lze
      lzextras
    ];
  };

  # Startup plugins (always packadd'd).
  config.specs.core = {
    lazy = false;
    after = [ "lze" ];
    data = with pkgs.vimPlugins; [
      # UI / theme (eager chrome)
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

      # Editor essentials
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
      friendly-snippets # TODO: wire into luasnip (from_vscode loader)

      # LSP / completion / treesitter
      blink-cmp
      conform-nvim
      nvim-lightbulb
      nvim-treesitter.withAllGrammars
      nvim-treesitter-context
      nvim-ts-autotag
    ];
  };

  # Deferred plugins (opt/ until lze packadd's them).
  config.specs.deferred = {
    lazy = true;
    data = with pkgs.vimPlugins; [
      # Light UI (DeferredUIEnter)
      nvim-scrollbar
      cinnamon-nvim
      highlight-undo-nvim
      indent-blankline-nvim
      nvim-colorizer-lua
      vim-illuminate
      fastaction-nvim
      nvim-navbuddy

      # Pickers / files
      telescope-nvim
      neo-tree-nvim
      oil-nvim
      grug-far-nvim
      undotree
      diffview-nvim
      img-clip-nvim
      image-nvim
      run-nvim
      conjure

      # Git
      neogit

      # LSP UI extras
      otter-nvim
      nvim-docs-view
      trouble-nvim

      # Debug
      nvim-dap
      nvim-dap-ui
      nvim-nio

      # AI / REPL
      avante-nvim
      iron-nvim
    ];
  };

  config.runtimePkgs = with pkgs; [
    # Tools used by plugins
    ripgrep
    fd
    tree-sitter
    imagemagick
    cursor-cli

    # Formatters (conform)
    nixfmt
    ruff
    stylua
    shfmt
    clang-tools # clangd + clang-format
    prettier
    astyle
    taplo
    tex-fmt
    deno
    gersemi
    sqlfluff
    dockerfmt
    jsonfmt
    mbake
    fish # fish_indent

    # Language runtimes used by LSPs / REPLs
    julia-bin
    # R + languageserver come from the system/user env when needed

    # LSPs
    bash-language-server
    docker-language-server
    fennel-ls
    fish-lsp
    harper
    jdt-language-server
    lemminx
    lua-language-server
    marksman
    neocmakelsp
    nil
    kdePackages.qtdeclarative # qmlls
    sqls
    superhtml
    texlab
    ty
    vscode-langservers-extracted
  ];
}
