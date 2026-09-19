vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- uv tools (ruff, ty, debugpy, ipython, …) install shims here; keep them ahead of
-- the nix wrapper PATH suffix so Neovide / non-login launches still resolve them.
do
  local local_bin = vim.fn.expand("~/.local/bin")
  if not (":" .. (vim.env.PATH or "") .. ":"):find(":" .. local_bin .. ":", 1, true) then
    vim.env.PATH = local_bin .. ":" .. (vim.env.PATH or "")
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

-- Neovim enables synchronized output under tmux; tmux's handling of it causes cursor flicker/jumps while scrolling
-- (tmux#5470, tmux#5419). Bare
if vim.env.TMUX and vim.env.TMUX ~= "" then
    opt.termsync = false
end

vim.g.formatsave = true
