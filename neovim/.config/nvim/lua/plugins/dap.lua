-- nvim-dap + dap-ui. Loaded on first require("dap") / require("dapui") from the maps below.
local map = vim.keymap.set

local function setup_python(dap)
  local find_project_root = require("config.python_project").find_project_root

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

    local root, pyproject = find_project_root()
    local uv = vim.fn.exepath("uv")
    if pyproject and uv ~= "" then
      cb({
        type = "executable",
        command = uv,
        args = {
          "run",
          "--project",
          root,
          "--with",
          "debugpy",
          "python",
          "-m",
          "debugpy.adapter",
        },
        options = { source_filetype = "python" },
      })
      return
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
      "No Python DAP adapter: need uv+pyproject or debugpy-adapter on PATH",
      vim.log.levels.ERROR,
      { title = "DAP" }
    )
  end

  local function project_cwd()
    return find_project_root()
  end

  local configs = {
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

  dap.configurations.python = configs
  dap.configurations.quarto = configs
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
