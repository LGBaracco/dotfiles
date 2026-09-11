-- Early so lze can lazy-load quarto-nvim / molten / render-markdown on ft=quarto.
vim.filetype.add({
  extension = {
    qmd = "quarto",
  },
})

-- Quarto has no dedicated treesitter grammar; reuse markdown for render-markdown etc.
vim.treesitter.language.register("markdown", "quarto")
