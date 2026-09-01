{
  pkgs,
  lib,
  ...
}:
let
  keymaps = import ./keymaps.nix;
  languages = import ./languages.nix;
  dashboard = import ./dashboard.nix;
in
{

  programs.nvf = {
    enable = true;

    settings.vim = {
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

      formatter.conform-nvim.enable = true;

      lsp = {
        enable = true;
        formatOnSave = true;
        lightbulb.enable = true;
        trouble.enable = true;
        otter-nvim.enable = true;
        nvim-docs-view.enable = true;
        presets.harper.enable = true; # Grammar check, might delete

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

      inherit languages;

      visuals = {
        nvim-scrollbar.enable = true;
        nvim-web-devicons.enable = true;
        nvim-cursorline.enable = true;
        cinnamon-nvim.enable = true;
        fidget-nvim.enable = true;

        highlight-undo.enable = true;
        blink-indent.enable = true;

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
        extraConfig = dashboard.themeExtraConfig;
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

      dashboard = dashboard.dashboard;

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
        };
      };

      ui = {
        borders.enable = true;
        noice.enable = true;
        colorizer.enable = true;
        illuminate.enable = true;
        
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
