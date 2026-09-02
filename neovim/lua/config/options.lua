vim.g.mapleader = " "
vim.g.maplocalleader = ","

local opt = vim.opt

opt.expandtab = true
opt.smartindent = true
opt.shiftwidth = 4
opt.softtabstop = 4
opt.tabstop = 4

opt.scrolloff = 6
opt.sidescrolloff = 3
opt.timeoutlen = 400

opt.cursorline = true
opt.cursorlineopt = "line"

-- shada.enable in nvf just kept the default 'shada' setting, so nothing to
-- override here.

opt.spell = false

-- Read by conform's format-on-save guard (see plugins/lsp.lua).
vim.g.formatsave = true
