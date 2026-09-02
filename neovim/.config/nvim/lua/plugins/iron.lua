local function python_repl_command()
  if vim.fn.executable("ipython") == 1 then
    return { "ipython", "--no-autoindent" }
  end
  return { vim.fn.executable("python3") == 1 and "python3" or "python" }
end

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
  -- <leader>r namespace split:
  --   run-nvim:  rr  (plugins.lazy)
  --   iron:      rc / rf / rl / rm / rx / rq / r<cr> / r<space>
  -- lze loads this plugin on first iron key (keys without rhs re-feed after setup).
  keymaps = {
    send_motion = "<leader>rc",
    visual_send = "<leader>rc",
    send_file = "<leader>rf",
    send_line = "<leader>rl",
    send_mark = "<leader>rm",
    cr = "<leader>r<cr>",
    interrupt = "<leader>r<space>",
    exit = "<leader>rq",
    clear = "<leader>rx", -- was rl (collided with send_line)
  },
})
