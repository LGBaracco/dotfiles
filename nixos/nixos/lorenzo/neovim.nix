{
  pkgs,
  lib,
  ...
}:
{
  programs.neovim.enable = true;

  programs.nvf = {
    enable = true;

    settings.vim = {
      # Set Space as the leader key
      globals.mapleader = " ";

      # User-defined keymaps overwrite nvf defaults, preventing conflicts
      keymaps = [
        # --- Global ---
        {
          key = "<leader><leader>";
          mode = "n";
          action = "<cmd>Telescope find_files<cr>";
          desc = "Fuzzy find files";
        }

        # --- Buffers (<leader> b) ---
        {
          key = "<leader>bb";
          mode = "n";
          action = "<cmd>Telescope buffers<cr>";
          desc = "Switch buffer";
        }
        {
          key = "<leader>bn";
          mode = "n";
          action = "<cmd>bnext<cr>";
          desc = "Next buffer";
        }
        {
          key = "<leader>bp";
          mode = "n";
          action = "<cmd>bprevious<cr>";
          desc = "Previous buffer";
        }
        {
          key = "<leader>bs";
          mode = "n";
          action = "<cmd>w<cr>";
          desc = "Save buffer";
        }

        {
          key = "<leader>bk";
          mode = "n";
          action = "<cmd>bdelete<cr><cmd>lua vim.schedule(function() local b = vim.fn.getbufinfo({buflisted = 1}); if #b == 0 or (#b == 1 and b[1].name == '' and vim.bo[b[1].bufnr].buftype == '') then vim.cmd('Alpha') end end)<cr>";
          desc = "Kill buffer";
        }
        {
          key = "<leader>bd";
          mode = [ "n" ];
          action = "<cmd>bdelete<cr><cmd>lua vim.schedule(function() local b = vim.fn.getbufinfo({buflisted = 1}); if #b == 0 or (#b == 1 and b[1].name == '' and vim.bo[b[1].bufnr].buftype == '') then vim.cmd('Alpha') end end)<cr>";
          desc = "kill buffer";
        }
        {
          key = "<leader>br";
          mode = "n";
          action = "<cmd>e!<cr>";
          desc = "Reload buffer";
        }

        # --- Windows (<leader> w) ---
        {
          key = "<leader>wv";
          mode = "n";
          action = "<C-w>v";
          desc = "Split vertical";
        }
        {
          key = "<leader>ws";
          mode = "n";
          action = "<C-w>s";
          desc = "Split horizontal";
        }
        {
          key = "<leader>wd";
          mode = "n";
          action = "<C-w>q";
          desc = "Close window";
        }
        {
          key = "<leader>wo";
          mode = "n";
          action = "<C-w>o";
          desc = "Close other windows";
        }
        {
          key = "<leader>wh";
          mode = "n";
          action = "<C-w>h";
          desc = "Focus left";
        }
        {
          key = "<leader>wl";
          mode = "n";
          action = "<C-w>l";
          desc = "Focus right";
        }
        {
          key = "<leader>wj";
          mode = "n";
          action = "<C-w>j";
          desc = "Focus down";
        }
        {
          key = "<leader>wk";
          mode = "n";
          action = "<C-w>k";
          desc = "Focus up";
        }
        {
          key = "<leader>w=";
          mode = "n";
          action = "<C-w>=";
          desc = "Balance windows";
        }
        {
          key = "s";
          mode = [
            "n"
            "x"
          ];
          action = "<cmd>HopChar2<cr>";
          desc = "Hop to a 2-character sequence";
        }
        {
          key = "S";
          mode = [
            "n"
            "x"
          ];
          action = "<cmd>HopWord<cr>";
          desc = "Hop to a word";
        }
      ];

      debugMode = {
        enable = false;
        level = 16;
        logFile = "/tmp/nvim.log";
      };

      opts = {
        shada.enable = true;
        expandtab = true;
        smartindent = true;
        shiftwidth = 4;
        softtabstop = 4;
        tabstop = 4;
        scrolloff = 6;
        sidescrolloff = 3;
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

      formatter.conform-nvim.enable = true;

      lsp = {
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

        servers.fennel_ls = {
          cmd = [ (lib.getExe pkgs.fennel-ls) ];
        };
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
        nix.format.type = [ "nixfmt" ];

        python = {
          enable = true;
          format.type = [ "ruff" ];
          lsp.servers = [ "ty" ];
        };

        julia.enable = true;
        markdown.enable = true;
        bash.enable = true;
        fish.enable = true;
        clang.enable = true;
        cmake.enable = true;
        css.enable = true;
        html.enable = true;
        json.enable = true;
        sql.enable = true;
        java.enable = true;
        lua.enable = true;
        r.enable = false;
        toml.enable = true;
        xml.enable = true;
        tex.enable = true;
        docker.enable = true;
        env.enable = true;
        make.enable = true;

        typst.enable = false;
        scss.enable = false;
        kotlin.enable = false;
        typescript.enable = false;
        go.enable = false;
        rust.enable = false;
        zig.enable = false;
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

      treesitter = {
        enable = true;
        context.enable = true;
        grammars = [ pkgs.vimPlugins.nvim-treesitter.builtGrammars.fennel ]; # non-packages fennel-grammar      };
      };

      binds = {
        whichKey = {
          enable = true;
          setupOpts = {
            preset = "helix";
            win.border = "rounded";
          };
        };
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
        project-nvim.setupOpts.manual_mode = false;
      };

      utility = {
        ccc.enable = false;
        vim-wakatime.enable = false;
        diffview-nvim.enable = true;
        #yanky-nvim.enable = true; # TODO disable until figure out fix for buffer access prompt
        qmk-nvim.enable = false;
        icon-picker.enable = true;
        surround.enable = true;
        multicursors.enable = false;
        smart-splits.enable = true;
        undotree.enable = true;
        nvim-biscuits.enable = true;
        grug-far-nvim.enable = true;

        motion = {
          hop.enable = true;
          #leap.enable = true;
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
          #mappings.open = "<leader>ot";
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
            go = [
              "90"
              "130"
            ];
          };
        };
        fastaction.enable = true;
      };

      assistant = {
        chatgpt.enable = false;
        copilot = {
          enable = false;
          cmp.enable = false;
        };
        codecompanion-nvim.enable = false;
        avante-nvim.enable = false;
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

      runner.run-nvim = {
        enable = true;
        mappings = {
          run = "<leader>rr";
          runCommand = "<leader>ri";
        };
      };

      extraPlugins.iron-nvim = {
        package = pkgs.vimPlugins.iron-nvim;
        setup = ''
          require("iron.core").setup({
            config = {
              repl_definition = {
                python = {
                  command = { "uv", "run", "ipython", "--no-autoindent" },
                  format = require("iron.fts.common").bracketed_paste_python,
                  block_dividers = { "# %%", "#%%" },
                },
                julia = {
                  command = { "julia" },
                },
              },
              repl_open_cmd = require("iron.view").bottom(15),
            },
            keymaps = {
              send_motion = "<leader>rc",
              visual_send = "<leader>rc",
              send_file = "<leader>rf",
              send_line = "<leader>rl",
              send_mark = "<leader>rm",
              cr = "<leader>r<cr>",
              interrupt = "<leader>r<space>",
              exit = "<leader>rq",
              clear = "<leader>rl",
            },
          })
        '';
      };

      repl.conjure.enable = true;
    };
  };
}
