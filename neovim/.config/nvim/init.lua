-- Entry point. Plugins themselves are provided on the runtimepath by the
-- nix-wrapper-modules wrapper (see flake.nix / module.nix); this file only
-- wires up Lua config and calls each plugin's `setup()`.

require("config.options")
require("config.neovide")
require("config.autocmds")
require("plugins")
require("config.keymaps")
