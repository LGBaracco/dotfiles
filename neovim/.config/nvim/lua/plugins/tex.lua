-- VimTeX: compile + Zathura SyncTeX. texlab (lsp.lua) owns completions only.
-- Defaults: \ll compile, \lv view/forward-search, \le errors, \lt TOC, \lc clean.

vim.g.vimtex_view_method = "zathura"
vim.g.vimtex_compiler_method = "latexmk"
vim.g.vimtex_syntax_conceal_disable = 1

vim.g.vimtex_compiler_latexmk = {
  aux_dir = ".build",
  out_dir = ".build",
  continuous = 1,
  options = {
    "-verbose",
    "-file-line-error",
    "-synctex=1",
    "-interaction=nonstopmode",
    "-pdf", -- pdfLaTeX
  },
}

-- Overleaf-like: start continuous latexmk when opening a TeX buffer.
vim.api.nvim_create_autocmd("User", {
  pattern = "VimtexEventInitPost",
  callback = function()
    vim.cmd("VimtexCompile")
  end,
})

require("which-key").add({
  { "<localleader>l", group = "vimtex", ft = { "tex", "plaintex", "bib" } },
})
