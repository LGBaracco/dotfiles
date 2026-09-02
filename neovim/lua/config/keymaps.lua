-- User-authored keymaps only. Vendored/preset keymaps (LSP, Telescope
-- pickers, Gitsigns, DAP, etc.) live in config.keymaps-nvf.
local map = vim.keymap.set

--- Global ---

map("n", "<leader><leader>", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files" })

--- Buffers (<leader> b) ---

map("n", "<leader>bb", "<cmd>Telescope buffers<cr>", { desc = "Switch buffer" })
map("n", "<leader>bn", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<leader>bs", "<cmd>w<cr>", { desc = "Save buffer", nowait = true })
map("n", "<leader>bS", "<cmd>wa<cr>", { desc = "Save all buffers", nowait = true })
map("n", "<leader>br", "<cmd>e!<cr>", { desc = "Reload buffer" })

-- Kill the current buffer; if nothing but an empty scratch buffer is left,
-- return to the dashboard.
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
-- Mirror Doom: after split, prompt for which buffer to show.

map("n", "<leader>wv", "<cmd>vsplit | Telescope buffers<cr>", { desc = "Split vertical" })
map("n", "<leader>ws", "<cmd>split | Telescope buffers<cr>", { desc = "Split horizontal" })
map("n", "<C-w>v", "<cmd>vsplit | Telescope buffers<cr>", { desc = "Split vertical" })
map("n", "<C-w>s", "<cmd>split | Telescope buffers<cr>", { desc = "Split horizontal" })

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

--- Files (<leader> f) ---

map("n", "<leader>fn", "<cmd>Neotree toggle reveal<cr>", { desc = "Toggle Neo-tree" })
map("n", "<leader>fo", "<cmd>Oil<cr>", { desc = "Open oil.nvim" })

--- which-key groups ---

local ok, wk = pcall(require, "which-key")
if ok then
  wk.add({
    { "<leader>b", desc = "+buffer" },
    { "<leader>w", desc = "+window" },
  })
end
