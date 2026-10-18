-- Whether a plugin is part of this session. Name = pack dir name, e.g. "noice.nvim".
-- Guard config for plugins the HPC profile leaves out (pack.json `desktopOnly`).
--   Nix: installed in start/ or opt/ under any packpath entry (module.nix).
--   elsewhere: added by config.pack for this profile. Not a disk check: the shared
--   lockfile makes vim.pack keep every locked plugin on disk, even on HPC.
local pack = require("config.pack")

return function(name)
  if not pack.is_nix then
    return pack.active[name] == true
  end
  return #vim.fn.globpath(vim.o.packpath, "pack/*/*/" .. name, false, true) > 0
end
