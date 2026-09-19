-- nvim-dap + dap-ui. Loaded on first require("dap") / require("dapui") from the maps below.
-- Python: launch file/module via uv+debugpy.
-- Quarto: never launch the .qmd as a script (YAML/markdown → SyntaxError). Instead extract
-- Python cells (otter, with fence fallback) and launch via debugpy's `code` field.
local map = vim.keymap.set

---Strip IPython magics / shell escapes — debugpy runs plain Python, not IPython.
---@param lines string[]
---@return string[]
---@return integer stripped
local function sanitize_debug_lines(lines)
  local out = {}
  local stripped = 0
  for _, line in ipairs(lines) do
    if line:match("^%s*%%") or line:match("^%s*!") then
      stripped = stripped + 1
    else
      table.insert(out, line)
    end
  end
  return out, stripped
end

---Fence fallback when otter isn't initialized yet.
---@param bufnr integer
---@return { range: { from: integer[], to: integer[] }, text: string[], lang: string }[]
local function parse_python_fences(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cells = {}
  local i = 1
  while i <= #lines do
    local open = lines[i]
    if open:match("^```%s*{?%s*python") or open:match("^```python") then
      local text = {}
      local content_from = i -- 1-indexed first content line
      i = i + 1
      while i <= #lines and not lines[i]:match("^```%s*$") do
        table.insert(text, lines[i])
        i = i + 1
      end
      -- range is 0-indexed line numbers, matching otter/quarto.runner
      table.insert(cells, {
        lang = "python",
        text = text,
        range = {
          from = { content_from - 1, 0 },
          to = { i - 1, 0 },
        },
      })
    end
    i = i + 1
  end
  return cells
end

---@param bufnr integer
---@return { range: { from: integer[], to: integer[] }, text: string[], lang: string }[]
local function python_cells(bufnr)
  local ok, keeper = pcall(require, "otter.keeper")
  if ok then
    pcall(keeper.sync_raft, bufnr)
    local raft = keeper.rafts[bufnr]
    local chunks = raft and raft.code_chunks and raft.code_chunks.python
    if chunks and #chunks > 0 then
      return chunks
    end
  end
  return parse_python_fences(bufnr)
end

local function overlaps_cursor(cell, row0)
  return cell.range.from[1] <= row0 and row0 <= cell.range.to[1]
end

---Extract Python source for DAP from a quarto buffer.
---@param mode "cell"|"all"
---@return string|nil code
---@return string|nil err
local function extract_quarto_python(mode)
  local bufnr = vim.api.nvim_get_current_buf()
  local cells = python_cells(bufnr)
  if #cells == 0 then
    return nil, "No Python cells found in this buffer"
  end

  local picked = {}
  if mode == "all" then
    picked = cells
  else
    local row0 = vim.api.nvim_win_get_cursor(0)[1] - 1
    for _, cell in ipairs(cells) do
      if overlaps_cursor(cell, row0) then
        table.insert(picked, cell)
        break
      end
    end
    if #picked == 0 then
      return nil, "Cursor is not inside a Python cell"
    end
  end

  local parts = {}
  local magic_stripped = 0
  for _, cell in ipairs(picked) do
    local clean, n = sanitize_debug_lines(cell.text or {})
    magic_stripped = magic_stripped + n
    local body = vim.trim(table.concat(clean, "\n"))
    if body ~= "" then
      table.insert(parts, body)
    end
  end
  if #parts == 0 then
    return nil, "Python cell(s) are empty after stripping IPython magics"
  end
  if magic_stripped > 0 then
    vim.notify(
      ("Stripped %d IPython magic/shell line(s) for debugpy."):format(magic_stripped),
      vim.log.levels.INFO,
      { title = "DAP" }
    )
  end
  return table.concat(parts, "\n\n# %%\n"), nil
end

local function setup_python(dap)
  local pyproj = require("config.python_project")

  -- Launch: project `uv run --with debugpy`, else uv-tool `debugpy-adapter`.
  dap.adapters.python = function(cb, config)
    if config.request == "attach" then
      local port = (config.connect and config.connect.port) or config.port or 5678
      local host = (config.connect and config.connect.host) or config.host or "127.0.0.1"
      cb({
        type = "server",
        port = assert(port, "connect.port is required for python attach"),
        host = host,
        options = { source_filetype = "python" },
      })
      return
    end

    local ok, root = pyproj.is_uv_project()
    if ok and root then
      local argv = pyproj.uv_run_argv(root, { "debugpy" }, { "python", "-m", "debugpy.adapter" })
      if argv then
        cb({
          type = "executable",
          command = argv[1],
          args = vim.list_slice(argv, 2),
          options = { source_filetype = "python" },
        })
        return
      end
    end

    local adapter = vim.fn.exepath("debugpy-adapter")
    if adapter ~= "" then
      cb({
        type = "executable",
        command = adapter,
        options = { source_filetype = "python" },
      })
      return
    end

    vim.notify(
      "No Python DAP adapter: need uv+pyproject or uv-tool debugpy-adapter on PATH",
      vim.log.levels.ERROR,
      { title = "DAP" }
    )
  end

  local function project_cwd()
    return pyproj.find_project_root()
  end

  ---@param mode "cell"|"all"
  local function quarto_code(mode)
    return function()
      local code, err = extract_quarto_python(mode)
      if not code then
        error(err or "Failed to extract Python from Quarto buffer", 0)
      end
      return code
    end
  end

  dap.configurations.python = {
    {
      type = "python",
      request = "launch",
      name = "Launch file",
      program = "${file}",
      cwd = project_cwd,
      console = "integratedTerminal",
    },
    {
      type = "python",
      request = "launch",
      name = "Launch module",
      module = function()
        return vim.fn.input("Module: ")
      end,
      cwd = project_cwd,
      console = "integratedTerminal",
    },
    {
      type = "python",
      request = "attach",
      name = "Attach remote",
      connect = function()
        local host = vim.fn.input("Host [127.0.0.1]: ")
        if host == "" then
          host = "127.0.0.1"
        end
        local port = tonumber(vim.fn.input("Port [5678]: ")) or 5678
        return { host = host, port = port }
      end,
    },
  }

  -- Quarto: extract cells — never pass the .qmd path as `program`.
  dap.configurations.quarto = {
    {
      type = "python",
      request = "launch",
      name = "Quarto: current cell",
      code = quarto_code("cell"),
      cwd = project_cwd,
      console = "integratedTerminal",
      stopOnEntry = true,
    },
    {
      type = "python",
      request = "launch",
      name = "Quarto: all Python cells",
      code = quarto_code("all"),
      cwd = project_cwd,
      console = "integratedTerminal",
      stopOnEntry = true,
    },
    {
      type = "python",
      request = "attach",
      name = "Attach remote",
      connect = function()
        local host = vim.fn.input("Host [127.0.0.1]: ")
        if host == "" then
          host = "127.0.0.1"
        end
        local port = tonumber(vim.fn.input("Port [5678]: ")) or 5678
        return { host = host, port = port }
      end,
    },
  }
end

require("lze").load({
  {
    "nvim-nio",
    dep_of = { "nvim-dap", "nvim-dap-ui" },
  },
  {
    "nvim-dap-ui",
    dep_of = "nvim-dap",
  },
  {
    "nvim-dap",
    on_require = { "dap", "dapui" },
    after = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup({})
      setup_python(dap)

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },
})

--- Debugger (<leader> d) ---
map("n", "<leader>dc", function() require("dap").continue() end, { desc = "Continue" })
map("n", "<leader>dR", function() require("dap").restart() end, { desc = "Restart" })
map("n", "<leader>dq", function() require("dap").terminate() end, { desc = "Terminate" })
map("n", "<leader>d.", function() require("dap").run_last() end, { desc = "Re-run Last Debug Session" })
map("n", "<leader>dr", function() require("dap").repl.toggle() end, { desc = "Toggle Repl" })
map("n", "<leader>dh", function() require("dap.ui.widgets").hover() end, { desc = "Hover" })
map("n", "<leader>db", function() require("dap").toggle_breakpoint() end, { desc = "Toggle breakpoint" })
map("n", "<leader>dgc", function() require("dap").run_to_cursor() end, { desc = "Continue to the current cursor" })
map("n", "<leader>dgi", function() require("dap").step_into() end, { desc = "Step into function" })
map("n", "<leader>dgo", function() require("dap").step_out() end, { desc = "Step out of function" })
map("n", "<leader>dgj", function() require("dap").step_over() end, { desc = "Next step" })
map("n", "<leader>dgk", function() require("dap").step_back() end, { desc = "Step back" })
map("n", "<leader>dvo", function() require("dap").up() end, { desc = "Go up stacktrace" })
map("n", "<leader>dvi", function() require("dap").down() end, { desc = "Go down stacktrace" })
map("n", "<leader>du", function() require("dapui").toggle() end, { desc = "Toggle DAP-UI" })
-- Quarto convenience: jump straight to "current cell" without the config picker.
map("n", "<leader>de", function()
  local dap = require("dap")
  if vim.bo.filetype ~= "quarto" then
    dap.continue()
    return
  end
  local configs = dap.configurations.quarto or {}
  for _, cfg in ipairs(configs) do
    if cfg.name == "Quarto: current cell" then
      dap.run(vim.deepcopy(cfg))
      return
    end
  end
  dap.continue()
end, { desc = "Debug current Quarto cell (or continue)" })
