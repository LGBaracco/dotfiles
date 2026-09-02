-- Ported verbatim from plugins.nix's `extraPlugins.iron-nvim`.
require("iron.core").setup({
  config = {
    repl_definition = {
      python = {
        command = { "uv", "run", "ipython", "--no-autoindent" },
        format = require("iron.fts.common").bracketed_paste_python,
        block_dividers = { "# %%", "#%%" },
      },
      julia = {
        command = { "julia" },
      },
    },
    repl_open_cmd = require("iron.view").bottom(15),
  },
  keymaps = {
    send_motion = "<leader>rc",
    visual_send = "<leader>rc",
    send_file = "<leader>rf",
    send_line = "<leader>rl",
    send_mark = "<leader>rm",
    cr = "<leader>r<cr>",
    interrupt = "<leader>r<space>",
    exit = "<leader>rq",
    clear = "<leader>rl",
  },
})
