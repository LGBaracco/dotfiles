{
  inputs,
  pkgs,
  config,
  ...
}: {
  programs.neovim.enable = true;

  programs.nvf = {
    enable = true;

    settings.vim = {
      debugMode = {
        enable = false;
        level = 16;
        logFile = "/tmp/nvim.log";
      };

      # vim.opts and vim.options are aliased
      opts.expandtab = true;
      opts.smartindent = true;

      spellcheck = {
        enable = true;
      };

      lsp = {
        # This must be enabled for the language modules to hook into
        # the LSP API.
        enable = true;

        formatOnSave = true;
        lspkind.enable = false;
        lightbulb.enable = true;
        lspsaga.enable = false;
        trouble.enable = true;
        lspSignature.enable = false; # conflicts with blink in maximal
        otter-nvim.enable = true;
        nvim-docs-view.enable = true;
        presets.harper.enable = true;
      };

      debugger = {
        nvim-dap = {
          enable = true;
          ui.enable = true;
        };
      };

      languages = {
        enableFormat = true;
        enableTreesitter = true;
        enableExtraDiagnostics = true;

        nix.enable = true;
        markdown.enable = true;
        bash.enable = true;
        fish.enable = true;
        clang.enable = true;
        cmake.enable = true;
        css.enable = true;
        scss.enable = true;
        html.enable = true;
        json.enable = true;
        sql.enable = true;
        java.enable = true;
        kotlin.enable = false;
        typescript.enable = false;
        go.enable = false;
        lua.enable = true;
        zig.enable = false;
        python.enable = true;
        julia.enable = true;
        r.enable = true;
        typst.enable = true;
        rust.enable = false;
        toml.enable = true;
        xml.enable = true;
        tex.enable = true;
        docker.enable = true;
        env.enable = true;

        openscad.enable = false;
        arduino.enable = false;
        assembly.enable = false;
        astro.enable = false;
        nu.enable = false;
        csharp.enable = false;
        vala.enable = false;
        scala.enable = false;
        gleam.enable = false;
        glsl.enable = false;
        dart.enable = false;
        ocaml.enable = false;
        elixir.enable = false;
        haskell.enable = false;
        hcl.enable = false;
        ruby.enable = false;
        fsharp.enable = false;
        just.enable = false;
        make.enable = false;
        qml.enable = false;
        jinja.enable = false;
        svelte.enable = false;
        vue.enable = false;
        tsx.enable = false;
        liquid.enable = false;
        tera.enable = false;
        twig.enable = false;
        gettext.enable = false;
        fluent.enable = false;
        jq.enable = false;
        standard-ml.enable = false;
        pug.enable = false;
        zsh.enable = false;
      };

      visuals = {
        nvim-scrollbar.enable = true;
        nvim-web-devicons.enable = true;
        nvim-cursorline.enable = true;
        cinnamon-nvim.enable = true;
        fidget-nvim.enable = true;

        highlight-undo.enable = true;
        blink-indent.enable = true;
        indent-blankline.enable = true;

        cellular-automaton.enable = false;
      };

      statusline = {
        lualine = {
          enable = true;
        };
      };

      theme = {
        enable = true;
        name = "oxocarbon";
        style = "dark";
        transparent = false;
      };

      autopairs.nvim-autopairs.enable = true;

      autocomplete = {
        nvim-cmp.enable = false;
        blink-cmp.enable = true;
      };

      snippets.luasnip.enable = true;

      filetree = {
        neo-tree = {
          enable = true;
        };
      };

      tabline = {
        nvimBufferline.enable = true;
      };

      treesitter.enable = true;
      treesitter.context.enable = true;

      binds = {
        whichKey.enable = true;
        cheatsheet.enable = true;
      };

      telescope.enable = true;

      git = {
        enable = true;
        gitsigns.enable = true;
        gitsigns.codeActions.enable = false;
        neogit.enable = true;
      };

      minimap = {
        minimap-vim.enable = false;
        codewindow.enable = false;
      };

      dashboard = {
        dashboard-nvim.enable = false;
        alpha.enable = true;
      };

      notify = {
        nvim-notify.enable = true;
      };

      projects = {
        project-nvim.enable = true;
      };

      utility = {
        ccc.enable = false;
        vim-wakatime.enable = false;
        diffview-nvim.enable = true;
        yanky-nvim.enable = false;
        qmk-nvim.enable = false;
        icon-picker.enable = true;
        surround.enable = true;
        leetcode-nvim.enable = true;
        multicursors.enable = true;
        smart-splits.enable = true;
        undotree.enable = true;
        nvim-biscuits.enable = true;
        grug-far-nvim.enable = true;

        motion = {
          hop.enable = true;
          leap.enable = true;
          precognition.enable = true;
        };
        images = {
          image-nvim.enable = false;
          img-clip.enable = true;
        };
      };

      notes = {
        neorg.enable = false;
        orgmode.enable = false;
        todo-comments.enable = true;
      };

      terminal = {
        toggleterm = {
          enable = true;
          lazygit.enable = true;
        };
      };

      ui = {
        borders.enable = true;
        noice.enable = true;
        colorizer.enable = true;
        modes-nvim.enable = false;
        illuminate.enable = true;
        breadcrumbs = {
          enable = true;
          navbuddy.enable = true;
        };
        smartcolumn = {
          enable = true;
          setupOpts.custom_colorcolumn = {
            nix = "110";
            ruby = "120";
            java = "130";
            go = ["90" "130"];
          };
        };
        fastaction.enable = true;
      };

      assistant = {
        chatgpt.enable = false;
        copilot = {
          enable = false;
          cmp.enable = true;
        };
        codecompanion-nvim.enable = false;
        avante-nvim.enable = true;
      };

      session = {
        nvim-session-manager.enable = false;
      };

      gestures = {
        gesture-nvim.enable = false;
      };

      comments = {
        comment-nvim.enable = true;
      };

      presence = {
        neocord.enable = false;
        cord-nvim.enable = false;
      };

      repl.conjure.enable = true;
    };
  };
}
