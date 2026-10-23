-- Follow-up for stale swap files recovered by the SwapExists handler in config.autocmds.
local M = {}

local function notify(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = "swap" })
end

---@param bufnr integer buffer recovered from `swapname`
---@param swapname string
function M.after_recover(bufnr, swapname)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    local path = vim.api.nvim_buf_get_name(bufnr)
    local recovered = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local ok, disk = pcall(vim.fn.readfile, path)
    if not ok then
        disk = {}
    end
    -- An empty buffer reads back as { "" }; an empty file as {}.
    if #recovered == 1 and recovered[1] == "" then
        recovered = {}
    end

    if vim.deep_equal(recovered, disk) then
        vim.fn.delete(swapname)
        vim.bo[bufnr].modified = false
        notify(("Stale swap file matched disk; deleted %s"):format(vim.fn.fnamemodify(swapname, ":t")))
        return
    end

    local scratch
    -- Deleting the swap of a buffer that stays open only drops the stale copy: Nvim
    -- writes a fresh one on the next change and removes it on a clean exit.
    local function discard_swap()
        vim.fn.delete(swapname)
        pcall(vim.api.nvim_buf_del_user_command, bufnr, "SwapDiscard")
        if scratch and vim.api.nvim_buf_is_valid(scratch) then
            vim.api.nvim_buf_delete(scratch, { force = true })
        end
        local win = vim.fn.bufwinid(bufnr)
        if win ~= -1 then
            vim.api.nvim_win_call(win, function()
                vim.cmd("diffoff")
            end)
        end
    end
    vim.api.nvim_create_autocmd("BufWritePost", {
        buffer = bufnr,
        once = true,
        callback = discard_swap,
    })
    vim.api.nvim_buf_create_user_command(bufnr, "SwapDiscard", function()
        -- Swap first: :edit! with it still on disk would fire SwapExists and recover again.
        discard_swap()
        vim.cmd("edit!")
    end, { desc = "Drop the recovered swap text and reload the file from disk" })

    -- Disk version on the left, recovered buffer on the right (DiffOrig layout).
    local win = vim.fn.bufwinid(bufnr)
    if win ~= -1 then
        vim.api.nvim_set_current_win(win)
    end
    vim.cmd("vertical leftabove new")
    scratch = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, disk)
    vim.bo[scratch].buftype = "nofile"
    vim.bo[scratch].bufhidden = "wipe"
    vim.bo[scratch].swapfile = false
    vim.bo[scratch].modifiable = false
    vim.bo[scratch].filetype = vim.bo[bufnr].filetype
    pcall(vim.api.nvim_buf_set_name, scratch, path .. " (on disk)")
    vim.cmd("diffthis")
    vim.cmd("wincmd p")
    vim.cmd("diffthis")
    notify("Recovered unsaved changes from a swap file (right) vs disk (left).\n"
        .. ":w keeps them, :SwapDiscard reloads from disk. Either deletes the swap.", vim.log.levels.WARN)
end

return M
