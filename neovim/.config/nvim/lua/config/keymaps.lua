-- Eager / core keymaps. Maps for deferred plugins live next to their lze spec
-- (plugins.files, plugins.git, plugins.lsp, plugins.dap, plugins.repl.*). Surround: plugins.editor.
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
            { "<leader>r", desc = "+run/repl" }, -- run-nvim rr; iron rc/rf/rl/rm/rx/rq/… (plugins.repl.*)
            { "<leader>w", desc = "+window" },
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
---@param force boolean|nil If true, discard unsaved changes (`:bdelete!`).
local function kill_buffer(force)
    vim.cmd({ cmd = "bdelete", bang = not not force })
    vim.schedule(function()
        local bufs = vim.fn.getbufinfo({ buflisted = 1 })
        local only_empty_scratch = #bufs == 1 and bufs[1].name == "" and vim.bo[bufs[1].bufnr].buftype == ""
        if #bufs == 0 or only_empty_scratch then
            vim.cmd("Dashboard")
        end
    end)
end

map("n", "<leader>bk", function()
    kill_buffer()
end, { desc = "Kill buffer" })
map("n", "<leader>bd", function()
    kill_buffer()
end, { desc = "Kill buffer" })
map("n", "<leader>bK", function()
    kill_buffer(true)
end, { desc = "Kill buffer without saving" })

--- Windows (<leader> w) ---

map("n", "<leader>wd", "<C-w>q", { desc = "Close window" })
map("n", "<leader>wo", "<C-w>o", { desc = "Close other windows" })
map("n", "<leader>wh", "<C-w>h", { desc = "Focus left" })
map("n", "<leader>wl", "<C-w>l", { desc = "Focus right" })
map("n", "<leader>wj", "<C-w>j", { desc = "Focus down" })
map("n", "<leader>wk", "<C-w>k", { desc = "Focus up" })
map("n", "<leader>w=", "<C-w>=", { desc = "Balance windows" })

-- Window hydra: <C-w><head> runs the head, then heads repeat without <C-w> until a
-- non-head key (red: that key exits and runs). Only <C-w><head> is mapped, so native
-- <C-w> commands that aren't heads (<C-w>gf, <C-w>], …) are untouched.
do
    local ok, Hydra = pcall(require, "hydra")
    if ok then
        local function wincmd(c)
            return function()
                vim.cmd.wincmd(c)
            end
        end
        local function resize(dir)
            return function()
                require("smart-splits")["resize_" .. dir]()
            end
        end
        Hydra({
            name = "Windows",
            mode = "n",
            body = "<C-w>",
            config = { hint = { type = "window", float_opts = { border = "rounded" } } },
            heads = {
                -- Plain wincmd (not smart-splits) so focus never leaves nvim for a tmux pane.
                { "h", wincmd("h"), { desc = "focus ←" } },
                { "j", wincmd("j"), { desc = "focus ↓" } },
                { "k", wincmd("k"), { desc = "focus ↑" } },
                { "l", wincmd("l"), { desc = "focus →" } },
                { "H", resize("left"), { desc = "resize ←" } },
                { "J", resize("down"), { desc = "resize ↓" } },
                { "K", resize("up"), { desc = "resize ↑" } },
                { "L", resize("right"), { desc = "resize →" } },
                -- Native <C-w>HJKL (move window to far side), relocated.
                { "<C-h>", wincmd("H"), { desc = "move far ←" } },
                { "<C-j>", wincmd("J"), { desc = "move far ↓" } },
                { "<C-k>", wincmd("K"), { desc = "move far ↑" } },
                { "<C-l>", wincmd("L"), { desc = "move far →" } },
                { "w", wincmd("w"), { desc = "next" } },
                { "<C-w>", wincmd("w"), { desc = false } },
                { "p", wincmd("p"), { desc = "previous" } },
                { "x", wincmd("x"), { desc = "swap" } },
                { "r", wincmd("r"), { desc = "rotate" } },
                { "n", wincmd("n"), { desc = "new" } },
                { "=", wincmd("="), { desc = "balance" } },
                -- desc = false: the auto hint wraps heads in _…_, so a "_" head breaks its parser.
                { "_", wincmd("_"), { desc = false } },
                { "|", wincmd("|"), { desc = false } },
                { "o", wincmd("o"), { desc = "only" } },
                { "q", wincmd("q"), { desc = "close" } },
                { "c", wincmd("c"), { desc = false } },
                -- Splits hand focus to Telescope, so they exit. Exit heads get no <C-w><head>
                -- entry map; <C-w>v / <C-w>s from normal mode stay in plugins.files.
                { "s", "<cmd>split | Telescope buffers<cr>", { exit = true, desc = "split" } },
                { "v", "<cmd>vsplit | Telescope buffers<cr>", { exit = true, desc = "vsplit" } },
                { "T", wincmd("T"), { exit = true, desc = "to tab" } },
                { "<Esc>", nil, { exit = true, desc = false } },
            },
        })
    end
end

--- hop ---

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
        -- Reuse existing <leader>la; fastaction is deferred (on_require + DeferredUIEnter).
        lmap({ "n", "x" }, "<leader>la", function()
            require("fastaction").code_action()
        end, "Code action")
        lmap("n", "<leader>lf", vim.lsp.buf.format, "Format")
        lmap("n", "<leader>ltf", function()
            vim.b.disableFormatSave = not vim.b.disableFormatSave
        end, "Toggle format on save")
        lmap("n", "<leader>lti", function()
            local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
            vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
        end, "Toggle inlay hints")
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
map(
    "x",
    "gc",
    "<Plug>(comment_toggle_linewise_visual)",
    { desc = "Toggle selected comment", noremap = true, silent = true }
)
map(
    "",
    "gb",
    "<Plug>(comment_toggle_blockwise_visual)",
    { desc = "Toggle selected block", noremap = true, silent = true }
)

--- smart-splits ---
-- Resize Ctrl+Shift+hjkl, focus Ctrl+hjkl. Do not bind <leader><leader>hjkl (races find_files).
-- Use <C-S-*> (not <C-H>): in terminals <C-H> == <C-h>, so focus maps were overwriting resize.

do
    local function ss()
        return require("smart-splits")
    end
    map("n", "<C-S-h>", function()
        ss().resize_left()
    end, { desc = "Resize Window/Pane Left" })
    map("n", "<C-S-j>", function()
        ss().resize_down()
    end, { desc = "Resize Window/Pane Down" })
    map("n", "<C-S-k>", function()
        ss().resize_up()
    end, { desc = "Resize Window/Pane Up" })
    map("n", "<C-S-l>", function()
        ss().resize_right()
    end, { desc = "Resize Window/Pane Right" })
    map("n", "<C-h>", function()
        ss().move_cursor_left()
    end, { desc = "Focus Window/Pane on the Left" })
    map("n", "<C-j>", function()
        ss().move_cursor_down()
    end, { desc = "Focus Window/Pane Below" })
    map("n", "<C-k>", function()
        ss().move_cursor_up()
    end, { desc = "Focus Window/Pane Above" })
    map("n", "<C-l>", function()
        ss().move_cursor_right()
    end, { desc = "Focus Window/Pane on the Right" })
    map("n", "<C-\\>", function()
        ss().move_cursor_previous()
    end, { desc = "Focus Previous Window/Pane" })
end
