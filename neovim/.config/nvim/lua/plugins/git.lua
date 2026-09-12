-- Git: gitsigns (gutter), neogit (status/commit/push/pull), diffview.
-- Telescope git pickers (<leader>fv*) are in plugins.files.
local map = vim.keymap.set

require("lze").load({
    {
        "gitsigns.nvim",
        event = "DeferredUIEnter",
        after = function()
            require("gitsigns").setup({})
        end,
    },
    {
        "neogit",
        cmd = { "Neogit" },
        after = function()
            require("neogit").setup({})
        end,
    },
    {
        "diffview.nvim",
        cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory" },
        after = function()
            require("diffview").setup({})
        end,
    },
})

--- Neogit (<leader> g) ---
map("n", "<leader>gs", "<Cmd>Neogit<CR>", { desc = "Git Status [Neogit]" })
map("n", "<leader>gc", "<Cmd>Neogit commit<CR>", { desc = "Git Commit [Neogit]" })
map("n", "<leader>gp", "<Cmd>Neogit pull<CR>", { desc = "Git pull [Neogit]" })
map("n", "<leader>gP", "<Cmd>Neogit push<CR>", { desc = "Git push [Neogit]" })
