-- nvf vendored/preset keybinds (ported from nvf-print-config).
-- Keep separate from config.keymaps so presets can be trimmed later.
--
-- These are the keymaps nvf itself registers for vendored/preset plugins
-- (LSP, Telescope, Gitsigns, DAP, etc). User-authored keymaps (buffer/window
-- management, hop `s`/`S`, `<leader><leader>` find_files, neo-tree, oil) live
-- in config.keymaps instead.
--
-- Notes:
--   * iron.nvim's `<leader>r{c,f,l,m,cr,space,q}` keys are configured via
--     `require("iron.core").setup({ keymaps = ... })` in plugins/iron.lua,
--     NOT here.
--   * nvim-surround's `gz*`/`<C-g>z` keys are set via <Plug> maps in
--     plugins/editor.lua (v4 no longer accepts keymaps in setup()).
--   * Gitsigns / git-conflict / lazygit were removed; git UI is neogit.

local M = {}

-- nvim-surround setup, reproduced here only as a reference for the keymaps
-- table that must accompany the real `require("nvim-surround").setup(...)`
-- call in your surround plugin config:
--   keymaps = {
--     insert = "<C-g>z", insert_line = "<C-g>Z",
--     normal = "gz", normal_cur = "gZ", normal_line = "gzz", normal_cur_line = "gZZ",
--     visual = "gz", visual_line = "gZ",
--     delete = "gzd", change = "gzr", change_line = "gZR",
--   }

function M.setup()
  M.setup_which_key_groups()
  M.setup_lsp_attach()
  M.setup_telescope()
  M.setup_dap()
  M.setup_git()
  M.setup_terminal()
  M.setup_trouble()
  M.setup_misc()
end

function M.setup_which_key_groups()
  local ok, wk = pcall(require, "which-key")
  if not ok then
    return
  end

  wk.add({
    { "<leader>d", desc = "+debugger" },
    { "<leader>f", desc = "+file" },
    { "<leader>fl", desc = "Telescope LSP" },
    { "<leader>fm", desc = "Cellular Automaton" },
    { "<leader>fv", desc = "Telescope Git" },
    { "<leader>fvc", desc = "Commits" },
    { "<leader>g", desc = "+Git" },
    { "<leader>l", desc = "+lsp" },
    { "<leader>lw", desc = "+Workspace" },
    { "<leader>r", desc = "+Run" },
    { "<leader>x", desc = "+Trouble" },
  })
end

-- LSP on_attach keymaps. Call `M.attach_keymaps(client, bufnr)` from your
-- LSP `on_attach`/`LspAttach` handler.
function M.attach_keymaps(_, bufnr)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, noremap = true, silent = true, desc = desc })
  end

  map("n", "<leader>lgD", vim.lsp.buf.declaration, "Go to declaration")
  map("n", "<leader>lgd", vim.lsp.buf.definition, "Go to definition")
  map("n", "<leader>lgt", vim.lsp.buf.type_definition, "Go to type")
  map("n", "<leader>lgi", vim.lsp.buf.implementation, "List implementations")
  map("n", "<leader>lgr", vim.lsp.buf.references, "List references")
  map("n", "<leader>lgn", function()
    vim.diagnostic.jump({
      count = 1,
      on_jump = function(_, jump_bufnr)
        vim.diagnostic.open_float({ scope = "cursor", bufnr = jump_bufnr, focus = false })
      end,
    })
  end, "Go to next diagnostic")
  map("n", "<leader>lgp", function()
    vim.diagnostic.jump({
      count = -1,
      on_jump = function(_, jump_bufnr)
        vim.diagnostic.open_float({ scope = "cursor", bufnr = jump_bufnr, focus = false })
      end,
    })
  end, "Go to previous diagnostic")
  map("n", "<leader>le", vim.diagnostic.open_float, "Open diagnostic float")
  map("n", "<leader>lH", vim.lsp.buf.document_highlight, "Document highlight")
  map("n", "<leader>lS", vim.lsp.buf.document_symbol, "List document symbols")
  map("n", "<leader>lwa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
  map("n", "<leader>lwr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
  map("n", "<leader>lwl", function()
    vim.notify(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, "List workspace folders")
  map("n", "<leader>lws", vim.lsp.buf.workspace_symbol, "List workspace symbols")
  map("n", "<leader>lh", vim.lsp.buf.hover, "Trigger hover")
  map("n", "<leader>ls", vim.lsp.buf.signature_help, "Signature help")
  map("n", "<leader>ln", vim.lsp.buf.rename, "Rename symbol")
  map("n", "<leader>la", vim.lsp.buf.code_action, "Code action")
  map("n", "<leader>lf", vim.lsp.buf.format, "Format")
  map("n", "<leader>ltf", function()
    vim.b.disableFormatSave = not vim.b.disableFormatSave
  end, "Toggle format on save")
end

function M.setup_lsp_attach()
  vim.api.nvim_create_autocmd("LspAttach", {
    desc = "LSP on-attach keybinds",
    callback = function(event)
      M.attach_keymaps(vim.lsp.get_client_by_id(event.data.client_id), event.buf)
    end,
  })

  -- otter.nvim: activate LSP on embedded code (e.g. code blocks in markdown)
  vim.keymap.set("n", "<leader>lo", "<cmd>OtterActivate<CR>", {
    desc = "Activate LSP on Cursor Position [otter-nvim]",
    noremap = true,
    silent = true,
  })

  -- nvim-docs-view
  vim.keymap.set("n", "<leader>lvt", "<cmd>DocsViewToggle<CR>", {
    desc = "Open or close the docs view panel",
    noremap = true,
    silent = true,
  })
  vim.keymap.set("n", "<leader>lvu", "<cmd>DocsViewUpdate<CR>", {
    desc = "Manually update the docs view panel",
    noremap = true,
    silent = true,
  })
end

function M.setup_telescope()
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { noremap = true, silent = true, desc = desc .. " [Telescope]" })
  end

  map("<leader>ff", "<cmd>Telescope find_files<CR>", "Find files")
  map("<leader>fg", "<cmd>Telescope live_grep<CR>", "Live grep")
  map("<leader>fb", "<cmd>Telescope buffers<CR>", "Buffers")
  map("<leader>fh", "<cmd>Telescope help_tags<CR>", "Help tags")
  map("<leader>ft", "<cmd>Telescope<CR>", "Open")
  map("<leader>fr", "<cmd>Telescope resume<CR>", "Resume (previous search)")
  map("<leader>fs", "<cmd>Telescope treesitter<CR>", "Treesitter")
  map("<leader>fp", "<cmd>Telescope projects<CR>", "Find projects")

  -- Git pickers
  map("<leader>fvf", "<cmd>Telescope git_files<CR>", "Git files")
  map("<leader>fvcw", "<cmd>Telescope git_commits<CR>", "Git commits")
  map("<leader>fvcb", "<cmd>Telescope git_bcommits<CR>", "Git buffer commits")
  map("<leader>fvb", "<cmd>Telescope git_branches<CR>", "Git branches")
  map("<leader>fvs", "<cmd>Telescope git_status<CR>", "Git status")
  map("<leader>fvx", "<cmd>Telescope git_stash<CR>", "Git stash")

  -- LSP pickers
  map("<leader>flsb", "<cmd>Telescope lsp_document_symbols<CR>", "LSP Document Symbols")
  map("<leader>flsw", "<cmd>Telescope lsp_workspace_symbols<CR>", "LSP Workspace Symbols")
  map("<leader>flr", "<cmd>Telescope lsp_references<CR>", "LSP References")
  map("<leader>fli", "<cmd>Telescope lsp_implementations<CR>", "LSP Implementations")
  map("<leader>flD", "<cmd>Telescope lsp_definitions<CR>", "LSP Definitions")
  map("<leader>flt", "<cmd>Telescope lsp_type_definitions<CR>", "LSP Type Definitions")
  map("<leader>fld", "<cmd>Telescope diagnostics<CR>", "Diagnostics")
end

function M.setup_dap()
  local dap = function()
    return require("dap")
  end

  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { noremap = true, silent = true, desc = desc })
  end

  map("<leader>dc", function() dap().continue() end, "Continue")
  map("<leader>dR", function() dap().restart() end, "Restart")
  map("<leader>dq", function() dap().terminate() end, "Terminate")
  map("<leader>d.", function() dap().run_last() end, "Re-run Last Debug Session")
  map("<leader>dr", function() dap().repl.toggle() end, "Toggle Repl")
  map("<leader>dh", function() require("dap.ui.widgets").hover() end, "Hover")
  map("<leader>db", function() dap().toggle_breakpoint() end, "Toggle breakpoint")
  map("<leader>dgc", function() dap().run_to_cursor() end, "Continue to the current cursor")
  map("<leader>dgi", function() dap().step_into() end, "Step into function")
  map("<leader>dgo", function() dap().step_out() end, "Step out of function")
  map("<leader>dgj", function() dap().step_over() end, "Next step")
  map("<leader>dgk", function() dap().step_back() end, "Step back")
  map("<leader>dvo", function() dap().up() end, "Go up stacktrace")
  map("<leader>dvi", function() dap().down() end, "Go down stacktrace")

  -- nvim-dap-ui
  map("<leader>du", function() require("dapui").toggle() end, "Toggle DAP-UI")
end

function M.setup_git()
  -- neogit only (gitsigns / git-conflict removed by preference)
  local neogit = function(lhs, cmd, desc)
    vim.keymap.set("n", lhs, cmd, { noremap = true, silent = true, desc = desc .. " [Neogit]" })
  end
  neogit("<leader>gs", "<Cmd>Neogit<CR>", "Git Status")
  neogit("<leader>gc", "<Cmd>Neogit commit<CR>", "Git Commit")
  neogit("<leader>gp", "<Cmd>Neogit pull<CR>", "Git pull")
  neogit("<leader>gP", "<Cmd>Neogit push<CR>", "Git push")
end

function M.setup_terminal()
  -- toggleterm: generic terminal toggle (lazygit binding removed; use neogit)
  vim.keymap.set({ "n", "t" }, "<c-t>", '<Cmd>execute v:count . "ToggleTerm"<CR>', {
    noremap = true,
    silent = true,
    desc = "Toggle terminal",
  })
end

function M.setup_trouble()
  local map = function(lhs, cmd, desc)
    vim.keymap.set("n", lhs, cmd, { noremap = true, silent = true, desc = desc .. " [trouble]" })
  end

  map("<leader>lwd", "<cmd>Trouble toggle diagnostics<CR>", "Workspace diagnostics")
  map("<leader>ld", "<cmd>Trouble toggle diagnostics filter.buf=0<CR>", "Document diagnostics")
  map("<leader>lr", "<cmd>Trouble toggle lsp_references<CR>", "LSP References")
  map("<leader>xq", "<cmd>Trouble toggle quickfix<CR>", "QuickFix")
  map("<leader>xl", "<cmd>Trouble toggle loclist<CR>", "LOCList")
  map("<leader>xs", "<cmd>Trouble toggle symbols<CR>", "Symbols")
end

function M.setup_misc()
  -- Comment.nvim (mappings.basic/extra disabled in setup; these replace them)
  vim.keymap.set("n", "gc", "<Plug>(comment_toggle_linewise)", {
    desc = "Toggle line comment",
    noremap = true,
    silent = true,
  })
  vim.keymap.set("n", "gb", "<Plug>(comment_toggle_blockwise)", {
    desc = "Toggle block comment",
    noremap = true,
    silent = true,
  })
  vim.keymap.set("n", "gcc", function()
    return vim.api.nvim_get_vvar("count") == 0 and "<Plug>(comment_toggle_linewise_current)"
      or "<Plug>(comment_toggle_linewise_count)"
  end, { desc = "Toggle current line comment", expr = true, noremap = true, silent = true })
  vim.keymap.set("n", "gbc", function()
    return vim.api.nvim_get_vvar("count") == 0 and "<Plug>(comment_toggle_blockwise_current)"
      or "<Plug>(comment_toggle_blockwise_count)"
  end, { desc = "Toggle current block comment", expr = true, noremap = true, silent = true })
  vim.keymap.set("x", "gc", "<Plug>(comment_toggle_linewise_visual)", {
    desc = "Toggle selected comment",
    noremap = true,
    silent = true,
  })
  vim.keymap.set("x", "gb", "<Plug>(comment_toggle_blockwise_visual)", {
    desc = "Toggle selected block",
    noremap = true,
    silent = true,
  })

  -- run-nvim
  vim.keymap.set("n", "<leader>rr", "<cmd>Run<cr>", {
    desc = "Run cached",
    noremap = true,
    silent = true,
  })
  vim.keymap.set("n", "<leader>ro", "<cmd>Run!<cr>", {
    desc = "Run and override",
    noremap = true,
    silent = true,
  })
  vim.keymap.set("n", "<leader>ri", "<cmd>RunPrompt<cr>", {
    desc = "Run with prompt",
    noremap = true,
    silent = true,
  })

  -- smart-splits: resize with Alt+hjkl, focus with Ctrl+hjkl
  local ss = function()
    return require("smart-splits")
  end
  local map = function(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { noremap = true, silent = true, desc = desc })
  end

  map("<A-h>", function() ss().resize_left() end, "Resize Window/Pane Left")
  map("<A-j>", function() ss().resize_down() end, "Resize Window/Pane Down")
  map("<A-k>", function() ss().resize_up() end, "Resize Window/Pane Up")
  map("<A-l>", function() ss().resize_right() end, "Resize Window/Pane Right")
  map("<C-h>", function() ss().move_cursor_left() end, "Focus Window/Pane on the Left")
  map("<C-j>", function() ss().move_cursor_down() end, "Focus Window/Pane Below")
  map("<C-k>", function() ss().move_cursor_up() end, "Focus Window/Pane Above")
  map("<C-l>", function() ss().move_cursor_right() end, "Focus Window/Pane on the Right")
  map("<C-\\>", function() ss().move_cursor_previous() end, "Focus Previous Window/Pane")
  -- NOTE: do NOT bind <leader><leader>hjkl here — it races the user's
  -- <leader><leader> find_files map and stalls which-key.
end

return M
