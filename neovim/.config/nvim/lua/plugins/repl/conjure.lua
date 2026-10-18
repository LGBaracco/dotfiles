-- Conjure (parked / disabled).
-- Formerly loaded via nixpkgs vimPlugins.conjure + an lze spec.
-- Kept here so everything Conjure-related lives in one place; do not require this file.
-- To revive: add the pack.json entry below and require this file from plugins/init.lua.

--[[
-- pack.json `plugins` (deferred):
--   { "name": "conjure", "src": "https://github.com/Olical/conjure", "nix": "conjure", "lazy": true }

-- lze spec:
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
