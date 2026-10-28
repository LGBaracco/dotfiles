-- Editor plugins. Comment, nvim-surround, autopairs and LuaSnip stay eager (their
-- operator / insert-mode maps must work from the first keypress); the rest load one
-- tick after UIEnter. Their keymaps are defined eagerly in config.keymaps, so
-- which-key lists them before the plugin loads; on_require covers code that needs a
-- module earlier (e.g. which-key.add() from a FileType callback, smart-splits maps).
require("lze").load({
    {
        "which-key.nvim",
        event = "DeferredUIEnter",
        on_require = "which-key",
        after = function()
            require("which-key").setup({
                preset = "helix",
                win = { border = "rounded" },
                notify = false, -- avoid spurious which-key "no mappings" noise after leader spam
                delay = 200,
            })
        end,
    },
    -- Built by their users on DeferredUIEnter: window hydra (config.keymaps), debug
    -- step hydra (plugins.dap).
    { "hydra.nvim", on_require = "hydra" },
    {
        "hop.nvim",
        event = "DeferredUIEnter",
        cmd = { "HopChar2", "HopWord" }, -- s / S (config.keymaps)
        after = function()
            require("hop").setup({})
        end,
    },
    {
        "smart-splits.nvim",
        event = "DeferredUIEnter",
        on_require = "smart-splits", -- <C-hjkl> / <C-S-hjkl> (config.keymaps)
        after = function()
            require("smart-splits").setup({})
        end,
    },
    {
        "todo-comments.nvim",
        event = "DeferredUIEnter",
        after = function()
            -- start() also highlights windows that were open before the load.
            require("todo-comments").setup({})
        end,
    },
    {
        -- No cmd stub: <C-t> runs `{count}ToggleTerm`, and lze's stub would replay
        -- that count as a range.
        "toggleterm.nvim",
        event = "DeferredUIEnter",
        after = function()
            require("toggleterm").setup({
                direction = "horizontal",
            })
        end,
    },
})

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

require("nvim-autopairs").setup({})
local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

ls.setup({})
-- friendly-snippets is on the runtimepath via pack.json (includes LaTeX).
require("luasnip.loaders.from_vscode").lazy_load()

ls.add_snippets("quarto", {
  s("pycell", {
    t({ "```{python}", "" }),
    i(1),
    t({ "", "```", "" }),
  }),
})

-- Jump only in insert/select so normal-mode <C-hjkl> window focus stays free.
vim.keymap.set({ "i", "s" }, "<C-j>", function()
  if ls.expand_or_jumpable() then
    ls.expand_or_jump()
  end
end, { silent = true, desc = "LuaSnip expand or jump forward" })
vim.keymap.set({ "i", "s" }, "<C-k>", function()
  if ls.jumpable(-1) then
    ls.jump(-1)
  end
end, { silent = true, desc = "LuaSnip jump backward" })
