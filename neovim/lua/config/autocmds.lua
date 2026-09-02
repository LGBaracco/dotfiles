-- Two-space indentation for config/markup filetypes.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "nix", "json", "yaml", "toml", "xml" },
  desc = "Use 2-space indentation for config/markup filetypes",
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
  end,
})
