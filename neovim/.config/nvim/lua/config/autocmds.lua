-- Two-space indentation for config/markup filetypes.
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "nix", "json", "yaml", "toml", "xml", "kdl" },
    desc = "Use 2-space indentation for config/markup filetypes",
    callback = function()
        vim.opt_local.shiftwidth = 2
        vim.opt_local.tabstop = 2
        vim.opt_local.softtabstop = 2
    end,
})

-- Swap file left by a killed Nvim (the owner check for a live Nvim is the built-in
-- nvim.swapfile group, which already set v:swapchoice): recover it instead of prompting.
-- Recovered text identical to the file on disk → delete the swap silently. Otherwise diff
-- it against disk; the swap is deleted on the next :w, or by :SwapDiscard (reload disk).
local swap_group = vim.api.nvim_create_augroup("stale_swap", { clear = true })

vim.api.nvim_create_autocmd("SwapExists", {
    group = swap_group,
    desc = "Recover stale swap files, then auto-delete or diff against disk",
    callback = function(ev)
        if vim.v.swapchoice ~= "" then
            return
        end
        local swapname = vim.v.swapname
        local info = vim.fn.swapinfo(swapname)
        if info.error then
            return
        end
        vim.v.swapchoice = "r"
        vim.api.nvim_create_autocmd("BufWinEnter", {
            group = swap_group,
            buffer = ev.buf,
            once = true,
            callback = function()
                vim.schedule(function()
                    require("config.swap").after_recover(ev.buf, swapname)
                end)
            end,
        })
    end,
})
