inputs:
{
  config,
  wlib,
  lib,
  pkgs,
  options,
  ...
}:
{
  imports = [ wlib.wrapperModules.neovim ];

  options.nvim-lib.neovimPlugins = lib.mkOption {
    readOnly = true;
    type = lib.types.attrsOf wlib.types.stringable;
    default = config.nvim-lib.pluginsFromPrefix "plugins-" inputs;
  };

  # Flip to false when Lua is stable and you want the store-copied config.
  options.settings.useImpureConfig = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      When true, load Lua from ~/.config/nvim (symlink to this flake; edit without rebuild).
      When false, bake settings.config_directory = ./. into the store (pure).
    '';
  };

  config.settings.config_directory =
    if config.settings.useImpureConfig then
      "/home/lorenzo/.config/nvim"
    else
      ./.;

  # Avoid stale bytecode while iterating on impure Lua.
  config.settings.compile_generated_lua = false;

  config.specs.general = {
    lazy = false;
    data = with pkgs.vimPlugins; [
      # UI / theme
      oxocarbon-nvim
      dashboard-nvim
      lualine-nvim
      nvim-navic
      nvim-navbuddy
      nvim-scrollbar
      nvim-web-devicons
      nvim-cursorline
      cinnamon-nvim
      fidget-nvim
      highlight-undo-nvim
      blink-indent
      indent-blankline-nvim
      noice-nvim
      nvim-colorizer-lua
      vim-illuminate
      fastaction-nvim
      nvim-notify
      dressing-nvim
      nui-nvim
      plenary-nvim

      # Editor
      which-key-nvim
      telescope-nvim
      neo-tree-nvim
      oil-nvim
      hop-nvim
      precognition-nvim
      comment-nvim
      nvim-surround
      smart-splits-nvim
      undotree
      grug-far-nvim
      diffview-nvim
      todo-comments-nvim
      toggleterm-nvim
      project-nvim
      img-clip-nvim
      image-nvim
      cheatsheet-nvim
      nvim-autopairs
      luasnip
      friendly-snippets
      run-nvim
      conjure

      # Git (neogit only; gitsigns / git-conflict removed)
      neogit
      gitlinker-nvim
      hunk-nvim

      # LSP / completion / treesitter
      blink-cmp
      conform-nvim
      nvim-lightbulb
      otter-nvim
      nvim-docs-view
      trouble-nvim
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
      nvim-treesitter-context
      nvim-ts-autotag

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

    # LSPs matching former nvf language set
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

  # Spec helpers from the neovim template (pluginsFromPrefix / mkPlugin).
  options.nvim-lib.pluginsFromPrefix = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    default =
      prefix: inputs':
      lib.pipe inputs' [
        builtins.attrNames
        (builtins.filter (s: lib.hasPrefix prefix s))
        (map (
          input:
          let
            name = lib.removePrefix prefix input;
          in
          {
            inherit name;
            value = config.nvim-lib.mkPlugin name inputs'.${input};
          }
        ))
        builtins.listToAttrs
      ];
  };
}
