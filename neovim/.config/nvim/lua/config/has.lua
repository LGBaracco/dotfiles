-- Whether a plugin is installed (start/ or opt/ under any packpath entry).
-- The plugin set comes from Nix (module.nix / module-hpc.nix); guard config for
-- plugins the HPC profile leaves out. Name = pack dir name, e.g. "noice.nvim".
return function(name)
  return #vim.fn.globpath(vim.o.packpath, "pack/*/*/" .. name, false, true) > 0
end
