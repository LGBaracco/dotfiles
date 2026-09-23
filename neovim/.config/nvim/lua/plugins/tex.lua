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

-- Buffer-local so the group can't surface in other filetypes that map
-- <localleader>l themselves (e.g. Molten's ,l in quarto buffers).
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "tex", "plaintex", "bib" },
  callback = function(ev)
    require("which-key").add({
      { "<localleader>l", group = "vimtex", buffer = ev.buf },
    })
  end,
})
