-- Quarto + otter for .qmd literate buffers. Code running uses molten (opt-in via ,i).
-- *.qmd → quarto filetype is registered early in ftdetect/quarto.lua.

require("quarto").setup({
  debug = false,
  closePreviewOnExit = true,
  lspFeatures = {
    enabled = true,
    languages = { "python" }, -- julia / multi-lang later
    chunks = "all",
    diagnostics = {
      enabled = true,
      triggers = { "BufWritePost" },
    },
    completion = {
      enabled = true,
    },
  },
  codeRunner = {
    enabled = true,
    default_method = "molten",
    never_run = { "yaml" },
  },
})

-- Activate otter/LSP features for the current quarto buffer.
require("quarto").activate()
