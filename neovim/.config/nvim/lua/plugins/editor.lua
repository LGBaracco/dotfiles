-- Eager editor plugins only. Deferred setups live in plugins.lazy after hooks.
require("which-key").setup({
	preset = "helix",
	win = { border = "rounded" },
	notify = false, -- avoid spurious which-key "no mappings" noise after leader spam
	delay = 200,
})

-- project.nvim (v6+) module is `project`, not `project_nvim`.
require("project").setup({
	manual_mode = false,
})

require("hop").setup({})

-- mappings.basic/extra disabled; replacement gc/gb/gcc/gbc maps live in
-- config.keymaps.
require("Comment").setup({
	mappings = { basic = false, extra = false },
})

-- nvim-surround v4: keymaps are no longer configured via setup(); use
-- vim.g.nvim_surround_no_*_mappings + <Plug> maps instead.
vim.g.nvim_surround_no_mappings = true
require("nvim-surround").setup({})
vim.keymap.set("i", "<C-g>z", "<Plug>(nvim-surround-insert)", {
	desc = "Add a surrounding pair around the cursor (insert mode)",
})
vim.keymap.set("i", "<C-g>Z", "<Plug>(nvim-surround-insert-line)", {
	desc = "Add a surrounding pair around the cursor, on new lines (insert mode)",
})
vim.keymap.set("n", "gz", "<Plug>(nvim-surround-normal)", {
	desc = "Add a surrounding pair around a motion (normal mode)",
})
vim.keymap.set("n", "gZ", "<Plug>(nvim-surround-normal-cur)", {
	desc = "Add a surrounding pair around the current line (normal mode)",
})
vim.keymap.set("n", "gzz", "<Plug>(nvim-surround-normal-line)", {
	desc = "Add a surrounding pair around a motion, on new lines (normal mode)",
})
vim.keymap.set("n", "gZZ", "<Plug>(nvim-surround-normal-cur-line)", {
	desc = "Add a surrounding pair around the current line, on new lines (normal mode)",
})
vim.keymap.set("x", "gz", "<Plug>(nvim-surround-visual)", {
	desc = "Add a surrounding pair around a visual selection",
})
vim.keymap.set("x", "gZ", "<Plug>(nvim-surround-visual-line)", {
	desc = "Add a surrounding pair around a visual selection, on new lines",
})
vim.keymap.set("n", "gzd", "<Plug>(nvim-surround-delete)", {
	desc = "Delete a surrounding pair",
})
vim.keymap.set("n", "gzr", "<Plug>(nvim-surround-change)", {
	desc = "Change a surrounding pair",
})
vim.keymap.set("n", "gZR", "<Plug>(nvim-surround-change-line)", {
	desc = "Change a surrounding pair, putting replacements on new lines",
})

require("smart-splits").setup({})
require("todo-comments").setup({})
require("toggleterm").setup({
	direction = "horizontal",
})

require("nvim-autopairs").setup({})
require("luasnip").setup({})
-- TODO: load friendly-snippets into luasnip, e.g.
--   require("luasnip.loaders.from_vscode").lazy_load()
-- (plugin is already on the runtimepath via module.nix.)
