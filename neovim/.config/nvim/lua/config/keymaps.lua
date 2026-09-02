-- Eager keymaps only. Deferred-plugin maps live in plugins.lazy (lze keys).
-- Iron REPL maps: plugins.iron (registered after iron loads). Surround: plugins.editor.
local map = vim.keymap.set

--- which-key groups ---

do
  local ok, wk = pcall(require, "which-key")
  if ok then
    wk.add({
      { "<leader>b", desc = "+buffer" },
      { "<leader>d", desc = "+debugger" },
      { "<leader>f", desc = "+file" },
      { "<leader>fl", desc = "Telescope LSP" },
      { "<leader>fv", desc = "Telescope Git" },
      { "<leader>fvc", desc = "Commits" },
      { "<leader>g", desc = "+Git" },
      { "<leader>l", desc = "+lsp" },
      { "<leader>lw", desc = "+Workspace" },
      { "<leader>r", desc = "+run/repl" }, -- run-nvim rr; iron rc/rf/rl/rm/rx/rq/…
      { "<leader>w", desc = "+window" },
      { "<leader>x", desc = "+Trouble" },
    })
  end
end

--- Buffers (<leader> b) ---

map("n", "<leader>bn", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<leader>bs", "<cmd>w<cr>", { desc = "Save buffer", nowait = true })
map("n", "<leader>bS", "<cmd>wa<cr>", { desc = "Save all buffers", nowait = true })
map("n", "<leader>br", "<cmd>e!<cr>", { desc = "Reload buffer" })

-- Kill buffer; reopen dashboard if only an empty scratch remains.
local function kill_buffer()
  vim.cmd("bdelete")
  vim.schedule(function()
    local bufs = vim.fn.getbufinfo({ buflisted = 1 })
    local only_empty_scratch = #bufs == 1 and bufs[1].name == "" and vim.bo[bufs[1].bufnr].buftype == ""
    if #bufs == 0 or only_empty_scratch then
      vim.cmd("Dashboard")
    end
  end)
end

map("n", "<leader>bk", kill_buffer, { desc = "Kill buffer" })
map("n", "<leader>bd", kill_buffer, { desc = "Kill buffer" })

--- Windows (<leader> w) ---

map("n", "<leader>wd", "<C-w>q", { desc = "Close window" })
map("n", "<leader>wo", "<C-w>o", { desc = "Close other windows" })
map("n", "<leader>wh", "<C-w>h", { desc = "Focus left" })
map("n", "<leader>wl", "<C-w>l", { desc = "Focus right" })
map("n", "<leader>wj", "<C-w>j", { desc = "Focus down" })
map("n", "<leader>wk", "<C-w>k", { desc = "Focus up" })
map("n", "<leader>w=", "<C-w>=", { desc = "Balance windows" })

--- Motion ---

map({ "n", "x" }, "s", "<cmd>HopChar2<cr>", { desc = "Hop to a 2-character sequence" })
map({ "n", "x" }, "S", "<cmd>HopWord<cr>", { desc = "Hop to a word" })

--- LSP (<leader> l) ---

vim.api.nvim_create_autocmd("LspAttach", {
  desc = "LSP on-attach keybinds",
  callback = function(event)
    local bufnr = event.buf
    local function lmap(mode, lhs, rhs, desc)
      map(mode, lhs, rhs, { buffer = bufnr, noremap = true, silent = true, desc = desc })
    end

    lmap("n", "<leader>lgD", vim.lsp.buf.declaration, "Go to declaration")
    lmap("n", "<leader>lgd", vim.lsp.buf.definition, "Go to definition")
    lmap("n", "<leader>lgt", vim.lsp.buf.type_definition, "Go to type")
    lmap("n", "<leader>lgi", vim.lsp.buf.implementation, "List implementations")
    lmap("n", "<leader>lgr", vim.lsp.buf.references, "List references")
    lmap("n", "<leader>lgn", function()
      vim.diagnostic.jump({
        count = 1,
        on_jump = function(_, jump_bufnr)
          vim.diagnostic.open_float({ scope = "cursor", bufnr = jump_bufnr, focus = false })
        end,
      })
    end, "Go to next diagnostic")
    lmap("n", "<leader>lgp", function()
      vim.diagnostic.jump({
        count = -1,
        on_jump = function(_, jump_bufnr)
          vim.diagnostic.open_float({ scope = "cursor", bufnr = jump_bufnr, focus = false })
        end,
      })
    end, "Go to previous diagnostic")
    lmap("n", "<leader>le", vim.diagnostic.open_float, "Open diagnostic float")
    lmap("n", "<leader>lH", vim.lsp.buf.document_highlight, "Document highlight")
    lmap("n", "<leader>lS", vim.lsp.buf.document_symbol, "List document symbols")
    lmap("n", "<leader>lwa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
    lmap("n", "<leader>lwr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
    lmap("n", "<leader>lwl", function()
      vim.notify(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, "List workspace folders")
    lmap("n", "<leader>lws", vim.lsp.buf.workspace_symbol, "List workspace symbols")
    lmap("n", "<leader>lh", vim.lsp.buf.hover, "Trigger hover")
    lmap("n", "<leader>ls", vim.lsp.buf.signature_help, "Signature help")
    lmap("n", "<leader>ln", vim.lsp.buf.rename, "Rename symbol")
    lmap("n", "<leader>la", vim.lsp.buf.code_action, "Code action")
    lmap("n", "<leader>lf", vim.lsp.buf.format, "Format")
    lmap("n", "<leader>ltf", function()
      vim.b.disableFormatSave = not vim.b.disableFormatSave
    end, "Toggle format on save")
  end,
})

--- Terminal ---

map({ "n", "t" }, "<c-t>", '<Cmd>execute v:count . "ToggleTerm"<CR>', {
  noremap = true,
  silent = true,
  desc = "Toggle terminal",
})

--- Comment ---
-- mappings.basic/extra disabled in Comment.setup; these replace them.

map("n", "gc", "<Plug>(comment_toggle_linewise)", { desc = "Toggle line comment", noremap = true, silent = true })
map("n", "gb", "<Plug>(comment_toggle_blockwise)", { desc = "Toggle block comment", noremap = true, silent = true })
map("n", "gcc", function()
  return vim.api.nvim_get_vvar("count") == 0 and "<Plug>(comment_toggle_linewise_current)"
    or "<Plug>(comment_toggle_linewise_count)"
end, { desc = "Toggle current line comment", expr = true, noremap = true, silent = true })
map("n", "gbc", function()
  return vim.api.nvim_get_vvar("count") == 0 and "<Plug>(comment_toggle_blockwise_current)"
    or "<Plug>(comment_toggle_blockwise_count)"
end, { desc = "Toggle current block comment", expr = true, noremap = true, silent = true })
map("x", "gc", "<Plug>(comment_toggle_linewise_visual)", { desc = "Toggle selected comment", noremap = true, silent = true })
map("x", "gb", "<Plug>(comment_toggle_blockwise_visual)", { desc = "Toggle selected block", noremap = true, silent = true })

--- smart-splits ---
-- Resize Alt+hjkl, focus Ctrl+hjkl. Do not bind <leader><leader>hjkl (races find_files).

do
  local function ss()
    return require("smart-splits")
  end
  map("n", "<A-h>", function() ss().resize_left() end, { desc = "Resize Window/Pane Left" })
  map("n", "<A-j>", function() ss().resize_down() end, { desc = "Resize Window/Pane Down" })
  map("n", "<A-k>", function() ss().resize_up() end, { desc = "Resize Window/Pane Up" })
  map("n", "<A-l>", function() ss().resize_right() end, { desc = "Resize Window/Pane Right" })
  map("n", "<C-h>", function() ss().move_cursor_left() end, { desc = "Focus Window/Pane on the Left" })
  map("n", "<C-j>", function() ss().move_cursor_down() end, { desc = "Focus Window/Pane Below" })
  map("n", "<C-k>", function() ss().move_cursor_up() end, { desc = "Focus Window/Pane Above" })
  map("n", "<C-l>", function() ss().move_cursor_right() end, { desc = "Focus Window/Pane on the Right" })
  map("n", "<C-\\>", function() ss().move_cursor_previous() end, { desc = "Focus Previous Window/Pane" })
end
