vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Molten remote-plugin host: uv tool env `pynvim` (uv-managed CPython).
-- Install/refresh: uv tool install --python 3.12 --with jupyter_client --with pillow
--   --with cairosvg --with nbformat --with plotly --with kaleido --with pnglatex
--   --with pyperclip --with requests --with websocket-client pynvim
do
  local uv_tools = vim.env.UV_TOOL_DIR or vim.fn.expand("~/.local/share/uv/tools")
  local uv_host = uv_tools .. "/pynvim/bin/python"
  if vim.fn.executable(uv_host) == 1 then
    vim.g.python3_host_prog = uv_host
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
