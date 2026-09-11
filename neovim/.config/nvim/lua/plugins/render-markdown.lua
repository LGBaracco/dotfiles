-- In-buffer markdown / Quarto chrome. Molten plots use image.nvim's API separately.
require("render-markdown").setup({
  file_types = { "markdown", "quarto" },
  code = {
    enabled = true,
    width = "block",
    border = "thin",
    conceal_delimiters = true,
  },
})
