-- Mid-tier lazy loading via lze. Pack names match nixpkgs vimPlugins.pname.
-- Eager plugins are set up in plugins.{ui,editor,lsp}; deferred setups run in `after`.
require("lze").load({
  --- Light UI (one tick after UIEnter) ---
  {
    "nvim-scrollbar",
    event = "DeferredUIEnter",
    after = function()
      require("scrollbar").setup({
        excluded_filetypes = {
          "prompt",
          "TelescopePrompt",
          "noice",
          "NvimTree",
          "neo-tree",
          "dashboard",
          "alpha",
          "notify",
          "Navbuddy",
          "fastaction_popup",
        },
      })
    end,
  },
  {
    "cinnamon.nvim",
    event = "DeferredUIEnter",
    after = function()
      require("cinnamon").setup()
    end,
  },
  {
    "highlight-undo.nvim",
    event = "DeferredUIEnter",
    after = function()
      require("highlight-undo").setup({
        ignored_filetypes = {
          "dashboard",
          "neo-tree",
          "fugitive",
          "TelescopePrompt",
          "mason",
          "lazy",
          "notify",
        },
      })
    end,
  },
  {
    "indent-blankline.nvim",
    event = "DeferredUIEnter",
    after = function()
      require("ibl").setup({
        exclude = {
          filetypes = {
            "dashboard",
            "lspinfo",
            "checkhealth",
            "help",
            "man",
            "gitcommit",
            "TelescopePrompt",
            "TelescopeResults",
            "neo-tree",
            "",
          },
          buftypes = { "terminal", "nofile", "quickfix", "prompt" },
        },
      })
    end,
  },
  {
    "nvim-colorizer.lua",
    event = "DeferredUIEnter",
    after = function()
      require("colorizer").setup({
        filetypes = { "*", "!dashboard" },
      })
    end,
  },
  {
    "vim-illuminate",
    event = "DeferredUIEnter",
    after = function()
      require("illuminate").configure({
        filetypes_denylist = {
          "dirvish",
          "fugitive",
          "help",
          "dashboard",
          "neo-tree",
          "notify",
          "NvimTree",
          "TelescopePrompt",
          "DressingInput",
        },
      })
    end,
  },
  {
    "fastaction.nvim",
    event = "DeferredUIEnter",
    after = function()
      require("fastaction").setup({
        popup = { border = "rounded" },
      })
    end,
  },
  {
    "nvim-navbuddy",
    cmd = { "Navbuddy" },
    keys = { { "<leader>lN", "<cmd>Navbuddy<CR>", desc = "Navbuddy" } },
    after = function()
      require("nvim-navbuddy").setup({
        lsp = { auto_attach = true },
      })
    end,
  },

  --- Telescope ---
  {
    "telescope.nvim",
    cmd = "Telescope",
    dep_of = { "run.nvim" },
    keys = {
      { "<leader><leader>", "<cmd>Telescope find_files<cr>", desc = "Fuzzy find files" },
      { "<leader>bb", "<cmd>Telescope buffers<cr>", desc = "Switch buffer" },
      { "<leader>wv", "<cmd>vsplit | Telescope buffers<cr>", desc = "Split vertical" },
      { "<leader>ws", "<cmd>split | Telescope buffers<cr>", desc = "Split horizontal" },
      { "<C-w>v", "<cmd>vsplit | Telescope buffers<cr>", desc = "Split vertical" },
      { "<C-w>s", "<cmd>split | Telescope buffers<cr>", desc = "Split horizontal" },
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files [Telescope]" },
      { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep [Telescope]" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers [Telescope]" },
      { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help tags [Telescope]" },
      { "<leader>ft", "<cmd>Telescope<CR>", desc = "Open [Telescope]" },
      { "<leader>fr", "<cmd>Telescope resume<CR>", desc = "Resume (previous search) [Telescope]" },
      { "<leader>fs", "<cmd>Telescope treesitter<CR>", desc = "Treesitter [Telescope]" },
      { "<leader>fp", "<cmd>Telescope projects<CR>", desc = "Find projects [Telescope]" },
      { "<leader>fvf", "<cmd>Telescope git_files<CR>", desc = "Git files [Telescope]" },
      { "<leader>fvcw", "<cmd>Telescope git_commits<CR>", desc = "Git commits [Telescope]" },
      { "<leader>fvcb", "<cmd>Telescope git_bcommits<CR>", desc = "Git buffer commits [Telescope]" },
      { "<leader>fvb", "<cmd>Telescope git_branches<CR>", desc = "Git branches [Telescope]" },
      { "<leader>fvs", "<cmd>Telescope git_status<CR>", desc = "Git status [Telescope]" },
      { "<leader>fvx", "<cmd>Telescope git_stash<CR>", desc = "Git stash [Telescope]" },
      { "<leader>flsb", "<cmd>Telescope lsp_document_symbols<CR>", desc = "LSP Document Symbols [Telescope]" },
      { "<leader>flsw", "<cmd>Telescope lsp_workspace_symbols<CR>", desc = "LSP Workspace Symbols [Telescope]" },
      { "<leader>flr", "<cmd>Telescope lsp_references<CR>", desc = "LSP References [Telescope]" },
      { "<leader>fli", "<cmd>Telescope lsp_implementations<CR>", desc = "LSP Implementations [Telescope]" },
      { "<leader>flD", "<cmd>Telescope lsp_definitions<CR>", desc = "LSP Definitions [Telescope]" },
      { "<leader>flt", "<cmd>Telescope lsp_type_definitions<CR>", desc = "LSP Type Definitions [Telescope]" },
      { "<leader>fld", "<cmd>Telescope diagnostics<CR>", desc = "Diagnostics [Telescope]" },
    },
    after = function()
      require("telescope").setup({
        defaults = {
          sorting_strategy = "ascending",
          layout_config = {
            height = 0.8,
            prompt_position = "top",
          },
        },
      })
      pcall(require("telescope").load_extension, "projects")
    end,
  },

  --- Files ---
  {
    "neo-tree.nvim",
    cmd = { "Neotree" },
    keys = {
      { "<leader>fn", "<cmd>Neotree toggle reveal<cr>", desc = "Toggle Neo-tree" },
    },
    after = function()
      require("neo-tree").setup({})
    end,
  },
  {
    "oil.nvim",
    cmd = { "Oil" },
    keys = {
      { "<leader>fo", "<cmd>Oil<cr>", desc = "Open oil.nvim" },
    },
    after = function()
      require("oil").setup({})
    end,
  },
  {
    "grug-far.nvim",
    cmd = { "GrugFar", "GrugFarWithin" },
    after = function()
      require("grug-far").setup({})
    end,
  },
  {
    "undotree",
    cmd = { "UndotreeToggle", "UndotreeShow", "UndotreeHide", "UndotreeFocus" },
  },
  {
    "diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory" },
    after = function()
      require("diffview").setup({})
    end,
  },
  {
    "img-clip.nvim",
    cmd = { "PasteImage", "ImgClipDebug", "ImgClipConfig" },
    after = function()
      require("img-clip").setup({})
    end,
  },
  {
    "image.nvim",
    ft = { "markdown", "norg", "vimwiki" },
    after = function()
      require("image").setup({
        backend = "kitty",
        processor = "magick_cli",
      })
    end,
  },
  {
    "run.nvim",
    cmd = { "Run" },
    keys = {
      { "<leader>rr", "<cmd>Run<cr>", desc = "Run actions [run-nvim]" },
    },
    after = function()
      require("run").setup({})

      -- Prepend "Run current file" for common filetypes (plugin only ships cargo/godot).
      local actions_mod = require("run.actions")
      local orig_get = actions_mod.get_actions
      actions_mod.get_actions = function()
        local list = orig_get()
        local out = vim.list_extend({}, list)
        local file = vim.fn.expand("%:p")
        if file == "" then
          return out
        end
        local ft = vim.bo.filetype
        local shellescape = vim.fn.shellescape
        local cmd_by_ft = {
          python = "python3 " .. shellescape(file),
          lua = "lua " .. shellescape(file),
          sh = "bash " .. shellescape(file),
          bash = "bash " .. shellescape(file),
          javascript = "node " .. shellescape(file),
          typescript = "node " .. shellescape(file),
        }
        local cmd = cmd_by_ft[ft]
        if cmd then
          table.insert(out, 1, {
            name = "Run current file",
            cmd = cmd,
          })
        end
        return out
      end
    end,
  },
  {
    "conjure",
    ft = { "clojure", "fennel", "janet", "hy", "julia", "racket", "scheme", "lua", "lisp", "python", "sql", "r" },
  },

  --- Git ---
  {
    "neogit",
    cmd = { "Neogit" },
    keys = {
      { "<leader>gs", "<Cmd>Neogit<CR>", desc = "Git Status [Neogit]" },
      { "<leader>gc", "<Cmd>Neogit commit<CR>", desc = "Git Commit [Neogit]" },
      { "<leader>gp", "<Cmd>Neogit pull<CR>", desc = "Git pull [Neogit]" },
      { "<leader>gP", "<Cmd>Neogit push<CR>", desc = "Git push [Neogit]" },
    },
    after = function()
      require("plugins.git")
    end,
  },

  --- LSP UI extras ---
  {
    "otter.nvim",
    keys = {
      { "<leader>lo", "<cmd>OtterActivate<CR>", desc = "Activate LSP on Cursor Position [otter-nvim]" },
    },
    cmd = { "OtterActivate", "OtterDeactivate" },
    after = function()
      require("otter").setup({})
    end,
  },
  {
    "nvim-docs-view",
    cmd = { "DocsViewToggle", "DocsViewUpdate" },
    keys = {
      { "<leader>lvt", "<cmd>DocsViewToggle<CR>", desc = "Open or close the docs view panel" },
      { "<leader>lvu", "<cmd>DocsViewUpdate<CR>", desc = "Manually update the docs view panel" },
    },
    after = function()
      require("docs-view").setup({})
    end,
  },
  {
    "trouble.nvim",
    cmd = { "Trouble" },
    keys = {
      { "<leader>lwd", "<cmd>Trouble toggle diagnostics<CR>", desc = "Workspace diagnostics [trouble]" },
      { "<leader>ld", "<cmd>Trouble toggle diagnostics filter.buf=0<CR>", desc = "Document diagnostics [trouble]" },
      { "<leader>lr", "<cmd>Trouble toggle lsp_references<CR>", desc = "LSP References [trouble]" },
      { "<leader>xq", "<cmd>Trouble toggle quickfix<CR>", desc = "QuickFix [trouble]" },
      { "<leader>xl", "<cmd>Trouble toggle loclist<CR>", desc = "LOCList [trouble]" },
      { "<leader>xs", "<cmd>Trouble toggle symbols<CR>", desc = "Symbols [trouble]" },
    },
    after = function()
      require("trouble").setup({})
    end,
  },

  --- Debug ---
  {
    "nvim-nio",
    dep_of = { "nvim-dap", "nvim-dap-ui" },
  },
  {
    "nvim-dap-ui",
    dep_of = "nvim-dap",
  },
  {
    "nvim-dap",
    keys = {
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
      { "<leader>dR", function() require("dap").restart() end, desc = "Restart" },
      { "<leader>dq", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>d.", function() require("dap").run_last() end, desc = "Re-run Last Debug Session" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle Repl" },
      { "<leader>dh", function() require("dap.ui.widgets").hover() end, desc = "Hover" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      { "<leader>dgc", function() require("dap").run_to_cursor() end, desc = "Continue to the current cursor" },
      { "<leader>dgi", function() require("dap").step_into() end, desc = "Step into function" },
      { "<leader>dgo", function() require("dap").step_out() end, desc = "Step out of function" },
      { "<leader>dgj", function() require("dap").step_over() end, desc = "Next step" },
      { "<leader>dgk", function() require("dap").step_back() end, desc = "Step back" },
      { "<leader>dvo", function() require("dap").up() end, desc = "Go up stacktrace" },
      { "<leader>dvi", function() require("dap").down() end, desc = "Go down stacktrace" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle DAP-UI" },
    },
    after = function()
      require("plugins.dap")
    end,
  },

  --- AI / REPL ---
  {
    "avante.nvim",
    cmd = {
      "AvanteAsk",
      "AvanteBuild",
      "AvanteChat",
      "AvanteChatNew",
      "AvanteToggle",
      "AvanteEdit",
      "AvanteRefresh",
      "AvanteClear",
      "AvanteFocus",
      "AvanteStop",
      "AvanteSwitchProvider",
    },
    on_require = "avante",
    after = function()
      require("plugins.ai")
    end,
  },
  {
    -- Keys without rhs: packadd + iron setup (registers maps) + re-feed lhs.
    "iron.nvim",
    keys = {
      { "<leader>rc", mode = { "n", "v" }, desc = "Iron send motion/visual" },
      { "<leader>rf", desc = "Iron send file" },
      { "<leader>rl", desc = "Iron send line" },
      { "<leader>rm", desc = "Iron send mark" },
      { "<leader>rx", desc = "Iron clear" },
      { "<leader>rq", desc = "Iron exit" },
      { "<leader>r<cr>", desc = "Iron CR" },
      { "<leader>r<space>", desc = "Iron interrupt" },
    },
    after = function()
      require("plugins.iron")
    end,
  },
})
