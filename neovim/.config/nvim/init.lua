-- Entry point. config.pack runs first: under Nix the nix-wrapper-modules wrapper
-- (flake.nix / module.nix) already provides plugins and tools; elsewhere it
-- installs them with vim.pack (+ mason, see config.tools). Both read pack.json.
-- The rest only wires up Lua config and calls each plugin's `setup()`.

-- Cache Lua module lookups and bytecode: without it every `require` probes each
-- 'rtp' entry, which is thousands of failed stats on slow filesystems (HPC GPFS).
vim.loader.enable()

require("config.pack")
require("config.options")
require("config.neovide")
require("config.autocmds")
require("plugins")
require("config.keymaps")
