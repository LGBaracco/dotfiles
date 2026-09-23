;; extends

; Notebook code cells for nvim-treesitter-textobjects (quarto reuses the markdown
; grammar, so this also applies to .qmd / jupytext .ipynb buffers).
; inner = code between the fences, outer = whole fenced block.
(fenced_code_block
  (code_fence_content) @code_cell.inner) @code_cell.outer
