-- Neovide GUI (font matches Ghostty: JetBrainsMono @ 12pt).
if not vim.g.neovide then
	return
end

vim.o.guifont = "JetBrainsMono Nerd Font:h12"
vim.g.neovide_scroll_animation_length = 0.05
vim.g.neovide_cursor_animation_length = 0.05
vim.g.neovide_cursor_trail_size = 0.2
