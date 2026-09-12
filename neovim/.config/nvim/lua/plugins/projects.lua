-- project.nvim (auto-cd to project root; `:Telescope projects`) plus helpers for
-- treating ~/dotfiles as a special project (show hidden files in telescope/oil).

-- project.nvim (v6+) module is `project`, not `project_nvim`.
require("project").setup({
    manual_mode = false,
})

local M = {}

---@return string
function M.root()
    return vim.fn.resolve(vim.fn.expand("~/dotfiles"))
end

---@param path string|nil
---@return boolean
function M.path_is_inside(path)
    if not path or path == "" then
        return false
    end
    local root = M.root()
    path = vim.fn.resolve(path)
    return path == root or vim.startswith(path .. "/", root .. "/")
end

---True when project.nvim's root (or current project) is ~/dotfiles.
---@param bufnr integer|nil
---@return boolean
function M.is_project(bufnr)
    local ok, project = pcall(require, "project")
    if not ok then
        return M.path_is_inside(vim.fn.getcwd())
    end
    local root = project.current_root(bufnr)
    if root and M.path_is_inside(root) then
        return true
    end
    local curr = select(1, project.current_project())
    return curr ~= nil and M.path_is_inside(curr)
end

return M
