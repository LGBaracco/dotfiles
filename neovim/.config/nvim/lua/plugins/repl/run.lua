-- run.nvim: pick and run project actions (telescope UI). <leader>rr.
require("lze").load({
  {
    "run.nvim",
    cmd = { "Run" },
    after = function()
      require("run").setup({})

      -- Prepend "Run current file" for common filetypes (plugin only ships cargo/godot).
      local actions_mod = require("run.actions")
      local orig_get = actions_mod.get_actions
      actions_mod.get_actions = function()
        local list = orig_get()
        local out = vim.list_extend({}, list)
        local file = vim.fn.expand("%:p")
        if file == "" then
          return out
        end
        local ft = vim.bo.filetype
        local shellescape = vim.fn.shellescape
        local cmd_by_ft = {
          python = "python3 " .. shellescape(file),
          lua = "lua " .. shellescape(file),
          sh = "bash " .. shellescape(file),
          bash = "bash " .. shellescape(file),
          javascript = "node " .. shellescape(file),
          typescript = "node " .. shellescape(file),
        }
        local cmd = cmd_by_ft[ft]
        if cmd then
          table.insert(out, 1, {
            name = "Run current file",
            cmd = cmd,
          })
        end
        return out
      end
    end,
  },
})

vim.keymap.set("n", "<leader>rr", "<cmd>Run<cr>", { desc = "Run actions [run-nvim]" })
