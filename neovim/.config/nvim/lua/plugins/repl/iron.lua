-- iron.nvim REPL. Loaded on first require("iron.core") from the maps below.
-- <leader>r namespace split:
--   run-nvim:  rr  (plugins.repl.run)
--   iron:      rc / rf / rl / rm / rx / rq / r<cr> / r<space>
local map = vim.keymap.set

local function python_repl_command()
  if vim.fn.executable("ipython") == 1 then
    return { "ipython", "--no-autoindent" }
  end
  return { vim.fn.executable("python3") == 1 and "python3" or "python" }
end

require("lze").load({
  {
    "iron.nvim",
    on_require = "iron.core",
    after = function()
      require("iron.core").setup({
        config = {
          repl_definition = {
            python = {
              command = python_repl_command(),
              format = require("iron.fts.common").bracketed_paste_python,
              block_dividers = { "# %%", "#%%" },
            },
            julia = {
              command = { "julia" },
            },
          },
          repl_open_cmd = require("iron.view").split.botright(15),
        },
        -- Maps are set below (same functions iron's `keymaps` option would bind).
      })
    end,
  },
})

local function iron()
  return require("iron.core")
end

map("n", "<leader>rc", function() iron().run_motion("send_motion") end, { desc = "Iron send motion" })
map("v", "<leader>rc", function() iron().visual_send() end, { desc = "Iron send visual" })
map("n", "<leader>rf", function() iron().send_file() end, { desc = "Iron send file" })
map("n", "<leader>rl", function() iron().send_line() end, { desc = "Iron send line" })
map("n", "<leader>rm", function() iron().send_mark() end, { desc = "Iron send mark" })
map("n", "<leader>rx", function() iron().send(nil, string.char(12)) end, { desc = "Iron clear" })
map("n", "<leader>rq", function() iron().close_repl() end, { desc = "Iron exit" })
map("n", "<leader>r<cr>", function() iron().send(nil, string.char(13)) end, { desc = "Iron CR" })
map("n", "<leader>r<space>", function() iron().send(nil, string.char(03)) end, { desc = "Iron interrupt" })
