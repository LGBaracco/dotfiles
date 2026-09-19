-- Shared UV / Python project helpers (Molten, DAP, Iron, run.nvim).
-- Project tooling (ruff, ty, debugpy, ipython, jupyter) lives in uv tools on PATH;
-- Home Manager only ships a bare python3 for casual non-project use.

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

---@return string uv absolute path, or "" if missing
function M.uv_exepath()
  return vim.fn.exepath("uv")
end

---Build `uv run --project <root> [--with pkg ...] <cmd...>` argv.
---@param root string
---@param with_pkgs? string[] packages layered via --with (e.g. debugpy, ipython)
---@param cmd string[] trailing command (e.g. { "python", "-m", "debugpy.adapter" })
---@return string[]|nil argv, or nil if uv is missing
function M.uv_run_argv(root, with_pkgs, cmd)
  local uv = M.uv_exepath()
  if uv == "" then
    return nil
  end
  local argv = { uv, "run", "--project", root }
  for _, pkg in ipairs(with_pkgs or {}) do
    vim.list_extend(argv, { "--with", pkg })
  end
  vim.list_extend(argv, cmd)
  return argv
end

---True when buffer/cwd sits under a pyproject.toml and uv is on PATH.
---@param start? string
---@return boolean
---@return string|nil root
function M.is_uv_project(start)
  local root, pyproject = M.find_project_root(start)
  if not pyproject or M.uv_exepath() == "" then
    return false, root
  end
  return true, root
end

---Shell command to run a Python file: `uv run` in projects, else bare python3.
---@param file string absolute path
---@return string
function M.run_file_shell_cmd(file)
  local ok, root = M.is_uv_project()
  local shellescape = vim.fn.shellescape
  if ok and root then
    return table.concat({
      shellescape(M.uv_exepath()),
      "run",
      "--project",
      shellescape(root),
      "python",
      shellescape(file),
    }, " ")
  end
  local py = vim.fn.exepath("python3")
  if py == "" then
    py = "python"
  end
  return shellescape(py) .. " " .. shellescape(file)
end

---Iron REPL argv: project `uv run --with ipython`, else uv-tool ipython, else python3.
---Uses the buffer Iron is opening from (meta.current_bufnr) so root discovery
---still works if focus has already moved.
---@param meta? { current_bufnr?: integer }
---@return string[]
function M.ipython_repl_command(meta)
  local start = nil
  if meta and meta.current_bufnr and vim.api.nvim_buf_is_valid(meta.current_bufnr) then
    local name = vim.api.nvim_buf_get_name(meta.current_bufnr)
    if name ~= "" then
      start = vim.fs.dirname(name)
    end
  end
  local ok, root = M.is_uv_project(start)
  if ok and root then
    -- `python -m IPython` keeps the project interpreter; `--with` only layers the REPL.
    local argv = M.uv_run_argv(root, { "ipython" }, { "python", "-m", "IPython", "--no-autoindent" })
    if argv then
      return argv
    end
  end
  if vim.fn.executable("ipython") == 1 then
    return { "ipython", "--no-autoindent" }
  end
  return { vim.fn.executable("python3") == 1 and "python3" or "python" }
end

return M
