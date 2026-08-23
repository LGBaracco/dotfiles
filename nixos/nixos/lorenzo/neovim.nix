{
  pkgs,
  lib,
  ...
}:
{

  programs.nvf = {
    enable = true;

    settings.vim = {
      globals.mapleader = " ";
      globals.maplocalleader = ",";

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
          nowait = true;
        }
        {
          key = "<leader>bS";
          mode = "n";
          action = "<cmd>wa<cr>";
          desc = "Save all buffers";
          nowait = true;
        }

        {
          key = "<leader>bk";
          mode = "n";
          # All this to have dashboard when closing all buffers
          action = "<cmd>bdelete<cr><cmd>lua vim.schedule(function() local b = vim.fn.getbufinfo({buflisted = 1}); if #b == 0 or (#b == 1 and b[1].name == '' and vim.bo[b[1].bufnr].buftype == '') then vim.cmd('Dashboard') end end)<cr>";
          desc = "Kill buffer";
        }
        {
          key = "<leader>bd";
          mode = [ "n" ];
          action = "<cmd>bdelete<cr><cmd>lua vim.schedule(function() local b = vim.fn.getbufinfo({buflisted = 1}); if #b == 0 or (#b == 1 and b[1].name == '' and vim.bo[b[1].bufnr].buftype == '') then vim.cmd('Dashboard') end end)<cr>";
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

        # --- Files (<leader> f) ---
        {
          key = "<leader>fn";
          mode = "n";
          action = "<cmd>Neotree toggle reveal<cr>";
          desc = "Toggle Neo-tree";
        }
        {
          key = "<leader>fo";
          mode = "n";
          action = "<cmd>Oil<cr>";
          desc = "Open oil.nvim";
        }
      ];

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

      formatter.conform-nvim.enable = true;

      lsp = {
        enable = true;
        formatOnSave = true;
        lightbulb.enable = true;
        trouble.enable = true;
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
        r.enable = true;
        toml.enable = true;
        xml.enable = true;
        tex.enable = true;
        docker.enable = true;
        env.enable = true;
        make.enable = true;
        qml.enable = true;

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
          integrations.breadcrumbs = {
            nvim-navic.enable = true;
            navbuddy.enable = true;
          };
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
        nvimBufferline.enable = false; # will see, maybe ill activate eventually
      };

      treesitter = {
        enable = true;
        context.enable = true;
        grammars = [ pkgs.vimPlugins.nvim-treesitter.builtGrammars.fennel ]; # non-packages fennel-grammar
      };

      binds = {
        whichKey = {
          enable = true;
          register = {
            "<leader>b" = "+buffer";
            "<leader>w" = "+window";
            "<leader>d" = "+debugger";
            "<leader>l" = "+lsp";
            "<leader>f" = "+file";
          };
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
        alpha.enable = false;
        dashboard-nvim = {
          enable = true;
          setupOpts = {
            theme = "doom";
            hide = {
              statusline = true;
              tabline = true;
              winbar = true;
            };
            config = {
              header = [
                ""
                "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣶⣶⠿⠿⠿⣶⣦⣀⠀⠀⠀"
                "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡾⠛⠉⠀⠀⠀⠀⠀⠀⠉⠻⣧⡀⠀"
                "⢠⣄⣀⣀⣀⣀⣀⣀⣀⣴⠋⠀⠀⠀⠀⠀⣴⣆⠀⠀⠀⠀⠘⣿⡀"
                "⠀⠙⠻⣿⣟⠛⠛⠛⠋⠁⠀⠀⠀⠀⠀⠘⠿⠋⠀⠀⠀⠀⠀⣿⡇"
                "⠀⠀⠀⠀⠙⢷⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⡇"
                "⠀⠀⠀⠀⠀⠀⠘⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣽⠃"
                "⠀⠀⠀⠀⠀⠀⢰⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀"
                "⠀⠀⠀⠀⠀⠀⣾⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⡿⠀"
                "⠀⠀⠀⠀⠀⢸⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠃⠀"
                "⠀⠀⠀⠀⢀⡿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡟⠀⠀"
                "⠀⠀⠀⠀⣾⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⠇⠀⠀"
                ""
              ];
              vertical_center = true;
              footer = [ "" ];
              center = [
                {
                  icon = " ";
                  desc = "Open project           ";
                  key = "p";
                  keymap = "SPC f";
                  key_format = " %s";
                  action = "Telescope projects";
                }
                {
                  icon = "󰈞 ";
                  desc = "Find file              ";
                  key = "f";
                  keymap = "SPC f";
                  key_format = " %s";
                  action = "Telescope find_files";
                }
                {
                  icon = " ";
                  desc = "Recently opened files  ";
                  key = "r";
                  key_format = " %s";
                  action = "Telescope oldfiles";
                }
                {
                  icon = " ";
                  desc = "New file               ";
                  key = "e";
                  key_format = " %s";
                  action = "enew";
                }
              ];
            };
          };
        };
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
        grug-far-nvim.enable = true;
        oil-nvim.enable = true;

        motion = {
          hop.enable = true;
          #leap.enable = true;
          precognition.enable = true;
        };
        images = {
          image-nvim = {
            enable = true;
            setupOpts = {
              backend = "kitty";
              processor = "magick_cli";
            };
          };
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
        avante-nvim = {
          enable = true;
          setupOpts = {
            provider = "cursor";
            mode = "agentic";
            acp_providers = {
              cursor = {
                command = lib.getExe pkgs.cursor-cli;
                args = [ "acp" ];
                auth_method = "cursor_login";
                env = {
                  HOME = lib.generators.mkLuaInline "os.getenv('HOME')";
                  PATH = lib.generators.mkLuaInline "os.getenv('PATH')";
                };
              };
            };
          };
        };
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
