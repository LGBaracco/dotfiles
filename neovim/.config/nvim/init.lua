-- Entry point. Plugins themselves are provided on the runtimepath by the
-- nix-wrapper-modules wrapper (see flake.nix / module.nix); this file only
-- wires up Lua config and calls each plugin's `setup()`.

require("config.options")
require("config.autocmds")
require("plugins")
require("config.keymaps")

-- Doom theme does not call disable_move_key. Bind buffer-local Nops on the
-- actual dashboard buffer (FileType provides ev.buf; DashboardLoaded can race).
vim.api.nvim_create_autocmd("FileType", {
  pattern = "dashboard",
  callback = function(ev)
    local b = ev.buf
    -- Keep j/k for doom menu navigation (CursorMoved snaps between items).
    local block = {
      "w", "b", "h", "l",
      "<Left>", "<Right>",
      "0", "^", "$", "G", "gg",
      "v", "V", "<C-v>",
      "s", "S",
    }
    for _, lhs in ipairs(block) do
      vim.keymap.set("n", lhs, "<Nop>", { buffer = b, nowait = true, silent = true })
      vim.keymap.set("x", lhs, "<Nop>", { buffer = b, nowait = true, silent = true })
    end
  end,
})
