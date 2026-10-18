-- Off-Nix tooling, set up by config.pack (never loaded on Nix, where the wrapper
-- provides all of this):
--   mason.nvim installs pack.json `tools` that have a `mason` package; its bin dir
--   is appended to PATH like the wrapper's runtimePkgs suffix, so host tools win.
--   :PackSync   install/align everything (network): plugins to nvim-pack-lock.json,
--               build hooks, mason tools, treesitter parsers, blink.cmp's fuzzy
--               binary, rplugin manifest; lists missing host-provided tools.
--               Headless: `nvim --headless +PackSync +qa` (exit code 1 on failure).
--   :PackUpdate interactive vim.pack.update(); commit nvim-pack-lock.json after.
-- Startup never installs tools or parsers; a UI session gets a one-line notice when
-- pack.json / the lockfile changed since the last successful :PackSync.
local M = {}

local pack ---@module "config.pack"

local stamp_path = vim.fs.joinpath(vim.fn.stdpath("state"), "pack-sync")

---Fingerprint of what :PackSync installs for this profile.
---@return string
local function stamp_key()
    return vim.fn.sha256(
        table.concat({ pack.profile, pack.read(pack.root .. "/pack.json") or "", pack.read(pack.lockfile) or "" }, "\n")
    )
end

---@return table[] pack.json tools in this profile
function M.tools()
    return vim.tbl_filter(pack.in_profile, pack.manifest.tools)
end

---@param name string
---@return string
local function plugin_dir(name)
    return vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "core", "opt", name)
end

---@param bin string
---@return boolean
local function has_bin(bin)
    return vim.fn.executable(bin) == 1
end

--- :PackSync -----------------------------------------------------------------

---@class PackSyncReport
local report = { errors = 0 }

---@param msg string
---@param level? "info"|"warn"|"error"
local function say(msg, level)
    level = level or "info"
    if level == "error" then
        report.errors = report.errors + 1
    end
    local hl = ({ info = "Normal", warn = "WarningMsg", error = "ErrorMsg" })[level]
    vim.api.nvim_echo({ { "PackSync: " .. msg, hl } }, true, { err = level == "error" })
end

local function sync_plugins()
    local known = {}
    for _, p in ipairs(pack.manifest.plugins) do
        known[p.name] = p
    end

    -- Plugins dropped from pack.json: off disk and out of the shared lockfile.
    local orphans = {}
    for _, p in ipairs(vim.pack.get(nil, { info = false })) do
        if not known[p.spec.name] then
            orphans[#orphans + 1] = p.spec.name
        end
    end
    if #orphans > 0 then
        vim.pack.del(orphans)
        say("removed (not in pack.json): " .. table.concat(orphans, ", "))
    end

    -- Profile plugins and locked plugins that are not on disk (failed or offline
    -- startup installs). Installed now, loaded after a restart.
    local locked = vim.json.decode(pack.read(pack.lockfile) or '{"plugins":{}}').plugins or {}
    local wanted = {}
    for _, spec in ipairs(pack.specs()) do
        wanted[spec.name] = spec
    end
    local missing = {}
    for name, p in pairs(known) do
        if (wanted[name] or locked[name]) and not vim.uv.fs_stat(plugin_dir(name)) then
            local version = p.version
            if type(version) == "table" then
                version = vim.version.range(version.range)
            end
            missing[#missing + 1] = { src = p.src, name = name, version = version, data = { lazy = true } }
        end
    end
    if #missing > 0 then
        local ok, err = pcall(vim.pack.add, missing, { confirm = false, load = function() end })
        if ok then
            say("installed missing plugins (restart Neovim to load them)", "warn")
        else
            say(tostring(err), "error")
        end
    end

    -- Align every plugin on disk to the lockfile (fetches; no-op when aligned).
    vim.pack.update(nil, { target = "lockfile", force = true })

    -- vim.pack logs update failures instead of raising: compare HEADs.
    locked = vim.json.decode(pack.read(pack.lockfile) or '{"plugins":{}}').plugins or {}
    local jobs, bad = {}, {}
    for name, l in pairs(locked) do
        if vim.uv.fs_stat(plugin_dir(name)) then
            jobs[name] = {
                rev = l.rev,
                job = vim.system({ "git", "rev-parse", "HEAD" }, { cwd = plugin_dir(name), text = true }),
            }
        else
            bad[#bad + 1] = name
        end
    end
    for name, j in pairs(jobs) do
        local out = j.job:wait()
        if out.code ~= 0 or vim.trim(out.stdout or "") ~= j.rev then
            bad[#bad + 1] = name
        end
    end
    if #bad > 0 then
        table.sort(bad)
        say(
            "not at the lockfile revision (see :e "
                .. vim.fn.stdpath("log")
                .. "/nvim-pack.log): "
                .. table.concat(bad, ", "),
            "error"
        )
    end
end

local function sync_builds()
    for _, job in ipairs(pack.jobs) do
        job:wait(600000)
    end
    pack.jobs = {}
    if pack.active.luasnip and not vim.uv.fs_stat(plugin_dir("luasnip") .. "/deps/luasnip-jsregexp.so") then
        if pack.build_jsregexp(plugin_dir("luasnip"), true) then
            say("built luasnip jsregexp")
        else
            say("luasnip: `make install_jsregexp` failed (optional: regex snippet transforms; needs make + cc)", "warn")
        end
    end
end

local function sync_tools()
    local ok, registry = pcall(require, "mason-registry")
    if not ok then
        say("mason.nvim not loaded; tools skipped", "error")
        return
    end
    local refreshed
    registry.refresh(function(success)
        refreshed = success
    end)
    vim.wait(300000, function()
        return refreshed ~= nil
    end, 50)
    if not refreshed then
        say("mason registry refresh failed", "error")
        return
    end

    -- Install callbacks run in a fast event context (no nvim_echo): collect, report after.
    local pending, installed, skipped, failed = 0, {}, {}, {}
    for _, t in ipairs(M.tools()) do
        if t.mason and t.requires and not has_bin(t.requires) then
            skipped[#skipped + 1] = ("%s (needs %s)"):format(t.mason, t.requires)
        elseif t.mason and not registry.is_installed(t.mason) then
            local got, pkg = pcall(registry.get_package, t.mason)
            if not got then
                say("mason has no package " .. t.mason, "error")
            elseif not pkg:is_installing() then
                pending = pending + 1
                pkg:install({}, function(success, result)
                    pending = pending - 1
                    if success then
                        installed[#installed + 1] = t.mason
                    else
                        failed[#failed + 1] = ("mason: %s failed: %s"):format(t.mason, vim.inspect(result))
                    end
                end)
            end
        end
    end
    vim.wait(1800000, function()
        return pending == 0
    end, 100)
    for _, msg in ipairs(failed) do
        say(msg, "error")
    end
    if pending > 0 then
        say("mason: installs timed out", "error")
    end
    if #installed > 0 then
        table.sort(installed)
        say("mason installed: " .. table.concat(installed, ", "))
    end
    if #skipped > 0 then
        say("mason skipped, toolchain missing: " .. table.concat(skipped, ", "), "warn")
    end
end

-- Stand-in for `tree-sitter build -o parser.so`, the only CLI call nvim-treesitter
-- makes for parsers that ship src/parser.c. Used when the CLI cannot run: release
-- binaries (also mason's) need glibc >= 2.39, JURECA has 2.34.
local ts_build_shim = [[#!/bin/sh
[ "$1" = build ] || { echo "tree-sitter stand-in (config.tools): only 'build' works" >&2; exit 1; }
out=parser.so; [ "$2" = -o ] && out=$3
if [ -f src/scanner.cc ]; then
  exec ${CXX:-c++} -shared -fPIC -O2 -Isrc -x c -std=gnu11 src/parser.c -x c++ src/scanner.cc -o "$out"
fi
set -- src/parser.c; [ -f src/scanner.c ] && set -- "$@" src/scanner.c
exec ${CC:-cc} -shared -fPIC -O2 -std=gnu11 -Isrc "$@" -o "$out"
]]

local function sync_parsers()
    if not pack.active["nvim-treesitter"] then
        return
    end
    -- nvim-treesitter main: parsers are downloaded and compiled locally.
    for _, bin in ipairs({ "cc", "tar", "curl" }) do
        if not has_bin(bin) then
            say(("treesitter parsers skipped: `%s` not on PATH"):format(bin), "error")
            return
        end
    end
    local langs = pack.manifest.treesitter[pack.profile]
    local path = vim.env.PATH
    local cli_ok, cli = pcall(function()
        return vim.system({ "tree-sitter", "--version" }):wait(10000).code == 0
    end)
    if not (cli_ok and cli) then
        local dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "pack-sync-bin")
        vim.fn.mkdir(dir, "p")
        vim.fn.writefile(vim.split(ts_build_shim, "\n"), dir .. "/tree-sitter")
        vim.fn.setfperm(dir .. "/tree-sitter", "rwxr-xr-x")
        vim.env.PATH = dir .. ":" .. path
        local parsers = require("nvim-treesitter.parsers")
        local needs_cli = vim.tbl_filter(function(lang)
            return vim.tbl_get(parsers, lang, "install_info", "generate") == true
        end, langs)
        langs = vim.tbl_filter(function(lang)
            return not vim.list_contains(needs_cli, lang)
        end, langs)
        say(
            "tree-sitter CLI does not run here: compiling parsers with cc"
                .. (
                    #needs_cli > 0
                        and ("; skipped (need `tree-sitter generate`): " .. table.concat(needs_cli, ", "))
                    or ""
                ),
            "warn"
        )
    end
    local ts = require("nvim-treesitter")
    local ok, res = pcall(function()
        return ts.install(langs, { summary = true }):wait(1800000)
    end)
    if not ok or res == false then
        say("treesitter: parser install failed " .. (ok and "(see above)" or tostring(res)), "error")
    end
    ok, res = pcall(function()
        return ts.update(nil, { summary = true }):wait(1800000)
    end)
    if not ok or res == false then
        say("treesitter: parser update failed " .. (ok and "(see above)" or tostring(res)), "error")
    end
    vim.env.PATH = path
end

---blink.cmp downloads its prebuilt fuzzy matcher from setup() (plugins.lsp); wait
---for that first, retry once, and fail if it fell back to the Lua matcher.
local function sync_blink()
    if not pack.active["blink.cmp"] then
        return
    end
    if package.loaded["blink.cmp.fuzzy.download"] then
        vim.wait(180000, function()
            return package.loaded["blink.cmp.completion"] ~= nil
        end, 50)
    end
    if require("blink.cmp.fuzzy").implementation_type == "rust" then
        return
    end
    local impl
    require("blink.cmp.fuzzy.download").ensure_downloaded(function(err, implementation)
        impl = err and "error" or implementation
    end)
    vim.wait(300000, function()
        return impl ~= nil
    end, 50)
    if impl == "rust" then
        require("blink.cmp.fuzzy").set_implementation("rust")
        say("downloaded blink.cmp fuzzy binary")
    else
        say("blink.cmp: no prebuilt fuzzy binary (Lua matcher fallback)", "error")
    end
end

local function sync_rplugins()
    if not pack.active["molten-nvim"] then
        return
    end
    if vim.fn.has("python3") == 0 then
        say("python3 host (uv tool `pynvim`, see plugins/repl/quarto.lua) missing: Molten unavailable", "warn")
        return
    end
    vim.cmd.packadd("molten-nvim")
    local ok, err = pcall(vim.cmd, "UpdateRemotePlugins")
    if not ok then
        say("UpdateRemotePlugins: " .. tostring(err), "error")
    end
end

-- Host fallbacks that the consumer accepts: snacks.image uses ImageMagick 6
-- `convert` when `magick` (IM7) is absent (Ubuntu 24.04, Rocky 9 ship IM6).
local host_alternatives = { magick = "convert" }

local function check_host_bins()
    local missing = {}
    for _, t in ipairs(M.tools()) do
        -- mason tools without their toolchain were already reported as skipped
        local alt = host_alternatives[t.bin]
        if not t.mason and not has_bin(t.bin) and not (alt and has_bin(alt)) then
            missing[#missing + 1] = t.bin
        end
    end
    if #missing > 0 then
        say("host-provided, not on PATH: " .. table.concat(missing, ", "), "warn")
    end
end

function M.sync()
    report.errors = 0
    pack.syncing = true
    say(("profile %s"):format(pack.profile))
    local ok, err = xpcall(function()
        sync_plugins()
        sync_builds()
        sync_tools()
        sync_parsers()
        sync_blink()
        sync_rplugins()
        check_host_bins()
    end, debug.traceback)
    pack.syncing = false
    if not ok then
        say(tostring(err), "error")
    end

    if report.errors == 0 then
        vim.fn.mkdir(vim.fs.dirname(stamp_path), "p")
        vim.fn.writefile({ stamp_key() }, stamp_path)
        say("done")
    else
        say(("%d error(s)"):format(report.errors), "error")
        if #vim.api.nvim_list_uis() == 0 then
            vim.cmd("cquit 1")
        end
    end
end

--- Setup ---------------------------------------------------------------------

---@param p table config.pack
function M.setup(p)
    pack = p

    local ok, mason = pcall(require, "mason")
    if ok then
        mason.setup({ PATH = "append" })
    end

    vim.api.nvim_create_user_command("PackSync", M.sync, {
        desc = "Install plugins at the lockfile revisions, mason tools, treesitter parsers",
    })
    vim.api.nvim_create_user_command("PackUpdate", function(o)
        vim.pack.update(#o.fargs > 0 and o.fargs or nil)
    end, {
        nargs = "*",
        complete = function()
            return vim.tbl_map(function(x)
                return x.spec.name
            end, vim.pack.get(nil, { info = false }))
        end,
        desc = "Update plugins (vim.pack); commit nvim-pack-lock.json afterwards",
    })

    vim.api.nvim_create_autocmd("UIEnter", {
        once = true,
        desc = "Suggest :PackSync when pack.json or the lockfile changed",
        callback = function()
            vim.schedule(function()
                if vim.trim(pack.read(stamp_path) or "") ~= stamp_key() then
                    vim.notify("Plugins/tools/parsers not synced with pack.json: run :PackSync", vim.log.levels.WARN)
                end
            end)
        end,
    })
end

return M
