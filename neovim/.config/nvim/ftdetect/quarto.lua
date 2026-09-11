-- Early so lze can lazy-load quarto-nvim / molten on ft=quarto.
vim.filetype.add({
  extension = {
    qmd = "quarto",
  },
})
