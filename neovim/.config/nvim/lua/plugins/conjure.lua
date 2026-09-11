-- Conjure (parked / disabled).
-- Formerly loaded via nixpkgs vimPlugins.conjure + lze in plugins/lazy.lua.
-- Kept here so everything Conjure-related lives in one place; do not require this file.

--[[
-- Nix (module.nix specs.deferred):
--   conjure

-- lze spec (plugins/lazy.lua):
{
  "conjure",
  ft = { "clojure", "fennel", "janet", "hy", "julia", "racket", "scheme", "lua", "lisp", "python", "sql", "r" },
  after = function()
    -- Conjure's log prefix is <localleader>l; keep the which-key label
    -- scoped so it doesn't fight VimTeX's group on TeX buffers.
    require("which-key").add({
      {
        "<localleader>l",
        group = "conjure log",
        ft = {
          "clojure",
          "fennel",
          "janet",
          "hy",
          "julia",
          "racket",
          "scheme",
          "lua",
          "lisp",
          "python",
          "sql",
          "r",
        },
      },
    })
  end,
}
]]
