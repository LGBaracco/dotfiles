-- Eager UI chrome, then deferred light-UI plugins. Dashboard: plugins.dashboard.
vim.cmd.colorscheme("oxocarbon")

require("nvim-web-devicons").setup()
require("fidget").setup()
require("noice").setup({
    views = {
        cmdline_popup = {
            position = {
                row = 2,
                col = "50%",
            },
        },
    },
})
require("notify").setup({
    background_colour = "#161616",
})
vim.notify = require("notify")

require("nvim-navic").setup()
require("lualine").setup({
    sections = {
        lualine_c = {
            "filename",
            {
                function()
                    return require("nvim-navic").get_location()
                end,
                cond = require("nvim-navic").is_available,
            },
        },
    },
})

--- Deferred (one tick after UIEnter, or on filetype) ---
require("lze").load({
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
            -- setup only registers FileType; buffers opened before DeferredUIEnter
            -- (e.g. `nvim tmux.conf`) already have ft set, so attach them now.
            for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(bufnr) then
                    local ft = vim.bo[bufnr].filetype
                    if ft ~= "" and ft ~= "dashboard" then
                        pcall(require("colorizer").attach_to_buffer, bufnr)
                    end
                end
            end
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
        -- In-buffer markdown / Quarto chrome. Molten plots use image.nvim's API separately.
        "render-markdown.nvim",
        ft = { "markdown", "quarto" },
        after = function()
            require("render-markdown").setup({
                file_types = { "markdown", "quarto" },
                code = {
                    enabled = true,
                    width = "block",
                    border = "thin",
                    conceal_delimiters = true,
                },
            })
        end,
    },
})
