-- Shared UV / Python project root discovery (Molten + DAP).

local M = {}

---Find project root from start path (or current buffer / cwd).
---@param start? string
---@return string root
---@return string|nil pyproject absolute path to pyproject.toml when present
function M.find_project_root(start)
  start = start or vim.fn.expand("%:p:h")
  if start == "" then
    start = vim.fn.getcwd()
  end
  local path = vim.fs.normalize(start)
  local pyproject = vim.fs.find("pyproject.toml", { upward = true, path = path })[1]
  if pyproject then
    return vim.fs.dirname(pyproject), pyproject
  end
  local git = vim.fs.find(".git", { upward = true, path = path, type = "directory" })[1]
  if git then
    return vim.fs.dirname(git), nil
  end
  return vim.fn.getcwd(), nil
end

return M
