-- nvim-hpc bootstrap, run via --cmd before init.lua (see hpc/nvim). Replaces what
-- the Nix wrapper's generated rc does: plugin pack on 'packpath', propagated Lua
-- rocks (jsregexp for luasnip, …) on package.path/cpath, no foreign providers.
local app = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))

package.path = table.concat({ app .. "/lua/share/?.lua", app .. "/lua/share/?/init.lua", package.path }, ";")
package.cpath = app .. "/lua/lib/?.so;" .. package.cpath

vim.opt.packpath:prepend(app .. "/site")

-- Only the python3 host exists on the cluster (uv tool `pynvim`, plugins/repl/quarto.lua)
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
