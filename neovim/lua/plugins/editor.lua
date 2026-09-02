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

require("neo-tree").setup({})
require("oil").setup({})

require("hop").setup({})
require("precognition").setup({
  -- Welcome/dashboard must not show motion hints (nvf effectively kept this clean).
  disabled_fts = {
    "startify",
    "dashboard",
    "neo-tree",
    "neo-tree-popup",
    "DressingInput",
    "TelescopePrompt",
  },
})

-- mappings.basic/extra disabled; replacement gc/gb/gcc/gbc maps live in
-- config.keymaps-nvf.
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
-- mbbill/undotree is pure Vimscript; nothing to `require()`/setup, it's
-- driven entirely by the `:UndotreeToggle` command.
require("grug-far").setup({})
require("diffview").setup({})

require("todo-comments").setup({})

require("toggleterm").setup({
  direction = "horizontal",
})

require("img-clip").setup({})
require("image").setup({
  backend = "kitty",
  processor = "magick_cli",
})

require("cheatsheet").setup({})
require("nvim-autopairs").setup({})
require("luasnip").setup({})

require("run").setup({})

-- conjure configures itself per-filetype (fennel/clojure/etc.); nothing to
-- call here, just make sure the plugin is on the runtimepath.
