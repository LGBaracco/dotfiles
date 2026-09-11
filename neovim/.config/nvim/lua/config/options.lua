vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Molten remote-plugin host (uv preferred; Nix only as fallback):
-- 1) uv tool env from install-nvim-molten-host (uv-managed CPython — not HM python)
-- 2) Nix-wrapped nvim-python3-host (neovim module runtimePkgs), if present
do
  local host = ""
  local uv_tools = vim.env.UV_TOOL_DIR or vim.fn.expand("~/.local/share/uv/tools")
  local uv_host = uv_tools .. "/pynvim/bin/python"
  if vim.fn.executable(uv_host) == 1 then
    host = uv_host
  else
    host = vim.fn.exepath("nvim-python3-host")
  end
  if host ~= "" then
    vim.g.python3_host_prog = host
  end
end

local opt = vim.opt

opt.expandtab = true
opt.smartindent = true
opt.shiftwidth = 4
opt.softtabstop = 4
opt.tabstop = 4

opt.scrolloff = 6
opt.sidescrolloff = 3
opt.timeoutlen = 400

opt.number = true
opt.relativenumber = true

opt.cursorline = true
opt.cursorlineopt = "line"

opt.spell = false

-- Read by conform's format-on-save guard (see plugins/lsp.lua).
vim.g.formatsave = true
