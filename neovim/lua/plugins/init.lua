-- Loads and configures every plugin. Plugins are already on the
-- runtimepath (provided by the nix wrapper), so each module just needs to
-- `require(...)` and call the relevant `setup()`.
require("plugins.ui")
require("plugins.editor")
require("plugins.git")
require("plugins.lsp")
require("plugins.dap")
require("plugins.ai")
require("plugins.iron")
