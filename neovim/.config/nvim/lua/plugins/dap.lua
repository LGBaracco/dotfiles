-- nvim-dap + dap-ui. Loaded on first require("dap") / require("dapui") from the maps below.
local map = vim.keymap.set

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
