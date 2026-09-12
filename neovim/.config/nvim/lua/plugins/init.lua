-- One file per topic. Each file sets up its eager plugins directly and
-- registers its deferred ones with `require("lze").load({...})` (lze accepts
-- any number of load() calls; dep_of/on_plugin resolve by name across files).
-- Keymaps for deferred plugins live next to their spec, never in lze `keys`.
require("plugins.ui")
require("plugins.dashboard")
require("plugins.editor")
require("plugins.projects")
require("plugins.files")
require("plugins.lsp")
require("plugins.git")
require("plugins.dap")
require("plugins.tex")
require("plugins.repl.quarto")
require("plugins.repl.iron")
require("plugins.repl.run")
