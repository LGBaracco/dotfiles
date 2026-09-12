-- File navigation / search: telescope, neo-tree, oil, grug-far, undotree.
-- All deferred; commands are stubbed by lze so the maps below trigger loading.
local map = vim.keymap.set

require("lze").load({
    {
        "telescope.nvim",
        cmd = "Telescope",
        dep_of = { "run.nvim" },
        after = function()
            local projects = require("plugins.projects")
            require("telescope").setup({
                defaults = {
                    sorting_strategy = "ascending",
                    layout_config = {
                        height = 0.8,
                        prompt_position = "top",
                    },
                },
                pickers = {
                    find_files = {
                        -- Dynamic: :Telescope find_files and keymaps pick this up.
                        find_command = function()
                            local cmd = { "fd", "--type", "f", "--color", "never" }
                            if projects.is_project() then
                                vim.list_extend(cmd, { "--hidden", "--exclude", ".git" })
                            end
                            return cmd
                        end,
                    },
                    live_grep = {
                        additional_args = function()
                            if projects.is_project() then
                                return { "--hidden", "--glob", "!.git/*" }
                            end
                            return {}
                        end,
                    },
                },
            })
            pcall(require("telescope").load_extension, "projects")
        end,
    },
    {
        "neo-tree.nvim",
        cmd = { "Neotree" },
        after = function()
            require("neo-tree").setup({})
        end,
    },
    {
        "oil.nvim",
        cmd = { "Oil" },
        after = function()
            local projects = require("plugins.projects")
            require("oil").setup({
                view_options = {
                    show_hidden = false,
                    is_hidden_file = function(name, bufnr)
                        if name == ".." then
                            return false
                        end
                        local dir = require("oil").get_current_dir(bufnr)
                        if projects.path_is_inside(dir) or projects.is_project(bufnr) then
                            return false
                        end
                        return vim.startswith(name, ".")
                    end,
                },
            })
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
        "vim-be-good",
        cmd = { "VimBeGood" },
    },
})

--- Telescope ---
map("n", "<leader><leader>", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files" })
map("n", "<leader>bb", "<cmd>Telescope buffers<cr>", { desc = "Switch buffer" })
map("n", "<leader>wv", "<cmd>vsplit | Telescope buffers<cr>", { desc = "Split vertical" })
map("n", "<leader>ws", "<cmd>split | Telescope buffers<cr>", { desc = "Split horizontal" })
map("n", "<C-w>v", "<cmd>vsplit | Telescope buffers<cr>", { desc = "Split vertical" })
map("n", "<C-w>s", "<cmd>split | Telescope buffers<cr>", { desc = "Split horizontal" })
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files [Telescope]" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep [Telescope]" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Buffers [Telescope]" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Help tags [Telescope]" })
map("n", "<leader>ft", "<cmd>Telescope<CR>", { desc = "Open [Telescope]" })
map("n", "<leader>fr", "<cmd>Telescope resume<CR>", { desc = "Resume (previous search) [Telescope]" })
map("n", "<leader>fs", "<cmd>Telescope treesitter<CR>", { desc = "Treesitter [Telescope]" })
map("n", "<leader>fp", "<cmd>Telescope projects<CR>", { desc = "Find projects [Telescope]" })
map("n", "<leader>fvf", "<cmd>Telescope git_files<CR>", { desc = "Git files [Telescope]" })
map("n", "<leader>fvcw", "<cmd>Telescope git_commits<CR>", { desc = "Git commits [Telescope]" })
map("n", "<leader>fvcb", "<cmd>Telescope git_bcommits<CR>", { desc = "Git buffer commits [Telescope]" })
map("n", "<leader>fvb", "<cmd>Telescope git_branches<CR>", { desc = "Git branches [Telescope]" })
map("n", "<leader>fvs", "<cmd>Telescope git_status<CR>", { desc = "Git status [Telescope]" })
map("n", "<leader>fvx", "<cmd>Telescope git_stash<CR>", { desc = "Git stash [Telescope]" })
map("n", "<leader>flsb", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "LSP Document Symbols [Telescope]" })
map("n", "<leader>flsw", "<cmd>Telescope lsp_workspace_symbols<CR>", { desc = "LSP Workspace Symbols [Telescope]" })
map("n", "<leader>flr", "<cmd>Telescope lsp_references<CR>", { desc = "LSP References [Telescope]" })
map("n", "<leader>fli", "<cmd>Telescope lsp_implementations<CR>", { desc = "LSP Implementations [Telescope]" })
map("n", "<leader>flD", "<cmd>Telescope lsp_definitions<CR>", { desc = "LSP Definitions [Telescope]" })
map("n", "<leader>flt", "<cmd>Telescope lsp_type_definitions<CR>", { desc = "LSP Type Definitions [Telescope]" })
map("n", "<leader>fld", "<cmd>Telescope diagnostics<CR>", { desc = "Diagnostics [Telescope]" })

--- Explorers ---
map("n", "<leader>fn", "<cmd>Neotree toggle reveal<cr>", { desc = "Toggle Neo-tree" })
map("n", "<leader>fo", "<cmd>Oil<cr>", { desc = "Open oil.nvim" })
