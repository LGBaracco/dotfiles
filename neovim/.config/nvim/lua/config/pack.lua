-- Plugin bootstrap, required first by init.lua. Both paths take the plugin set
-- from pack.json:
--   Nix: the nix-wrapper-modules wrapper (module.nix) already put every plugin on
--        'packpath' and sets vim.g.nix_info_plugin_name. Nothing is done here
--        beyond reporting what it installed.
--   elsewhere (Ubuntu, HPC): vim.pack installs the profile's plugins at the
--        revisions in nvim-pack-lock.json; config.tools adds mason, treesitter
--        parsers and :PackSync / :PackUpdate.
-- Profile: $DOTFILES_PROFILE=hpc drops `desktopOnly` plugins and tools (ignored
-- on Nix). Guard config for absent plugins with config.has.
local M = {}

M.is_nix = vim.g.nix_info_plugin_name ~= nil
M.profile = "desktop"
---@type table<string, true> plugin (pack dir) names active this session
M.active = {}

if M.is_nix then
    local ok, info = pcall(require, vim.g.nix_info_plugin_name)
    local plugins = ok and type(info) == "table" and info.plugins or {}
    for _, kind in ipairs({ "start", "lazy" }) do
        for name in pairs(plugins[kind] or {}) do
            M.active[name] = true
        end
    end
    return M
end

M.profile = vim.env.DOTFILES_PROFILE == "hpc" and "hpc" or "desktop"
M.root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))))
M.lockfile = vim.fs.joinpath(vim.fn.stdpath("config"), "nvim-pack-lock.json")
M.syncing = false -- set by :PackSync, which runs the slow hooks itself

---@param path string
---@return string?
function M.read(path)
    local fd = io.open(path, "rb")
    if not fd then
        return nil
    end
    local data = fd:read("*a")
    fd:close()
    return data
end

M.manifest = vim.json.decode(
    (assert(M.read(M.root .. "/pack.json"), "pack.json not found")),
    { luanil = { object = true, array = true } }
)

---@param entry { desktopOnly?: boolean }
---@return boolean
function M.in_profile(entry)
    return M.profile == "desktop" or not entry.desktopOnly
end

---@return vim.pack.Spec[]
function M.specs()
    local specs = {}
    for _, p in ipairs(M.manifest.plugins) do
        if M.in_profile(p) then
            local version = p.version
            if type(version) == "table" then
                version = vim.version.range(version.range)
            end
            specs[#specs + 1] = { src = p.src, name = p.name, version = version, data = { lazy = p.lazy == true } }
        end
    end
    return specs
end

-- Only the python3 host is used (Molten, plugins/repl/quarto.lua); the Nix
-- wrapper provides the others, here they would only cost startup checks.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

--- Build hooks (PackChanged) ---
-- Registered before vim.pack.add so they also fire for installs from the lockfile.

---@type vim.SystemObj[] background builds :PackSync waits for
M.jobs = {}

---LuaSnip's optional jsregexp (regex transformations in snippets), built from the
---deps/ submodules vim.pack checks out. Best effort: needs make and a C compiler.
---@param path string luasnip plugin dir
---@param wait? boolean
---@return boolean? ok when waited
function M.build_jsregexp(path, wait)
    if vim.fn.executable("make") == 0 then
        return false
    end
    local ok, job = pcall(vim.system, { "make", "install_jsregexp" }, { cwd = path, text = true })
    if not ok then
        return false
    end
    if wait then
        return job:wait().code == 0
    end
    M.jobs[#M.jobs + 1] = job
end

---Regenerate the rplugin manifest (Molten* commands). Needs molten on 'rtp' and
---the python3 host, so it runs after startup.
function M.update_rplugins()
    local function run()
        pcall(vim.cmd.packadd, "molten-nvim")
        pcall(vim.cmd, "silent UpdateRemotePlugins")
    end
    if vim.v.vim_did_enter == 1 then
        vim.schedule(run)
    else
        vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = run })
    end
end

local hooks = {
    luasnip = function(data)
        M.build_jsregexp(data.path)
    end,
    ["nvim-treesitter"] = function(data)
        if data.kind == "update" and not M.syncing then
            if not data.active then
                vim.cmd.packadd("nvim-treesitter")
            end
            vim.cmd("TSUpdate")
        end
    end,
    ["molten-nvim"] = function()
        if not M.syncing then
            M.update_rplugins()
        end
    end,
}

vim.api.nvim_create_autocmd("PackChanged", {
    group = vim.api.nvim_create_augroup("config.pack", {}),
    desc = "vim.pack build hooks (pack.lua)",
    callback = function(ev)
        local hook = hooks[ev.data.spec.name]
        if hook and ev.data.kind ~= "delete" then
            hook(ev.data)
        end
    end,
})

--- Install / load ---
-- Eager plugins get `packadd!` (plugin/ sourced at the load-plugins step, like
-- Nix start/); lazy ones stay in opt/ until lze packadd's them.

local lock_before = M.read(M.lockfile)
local ok, err = pcall(vim.pack.add, M.specs(), {
    confirm = false,
    load = function(plug)
        if not plug.spec.data.lazy then
            vim.cmd.packadd({ vim.fn.escape(plug.spec.name, " "), bang = true, magic = { file = false } })
        end
    end,
})
if not ok then
    -- vim.pack drops failed installs from the lockfile; keep the committed one
    -- (e.g. an offline compute node) and let :PackSync retry with network.
    if lock_before and M.read(M.lockfile) ~= lock_before then
        local fd = io.open(M.lockfile, "wb")
        if fd then
            fd:write(lock_before)
            fd:close()
        end
    end
    vim.schedule(function()
        vim.notify(tostring(err) .. "\nRun :PackSync (needs network).", vim.log.levels.ERROR, { title = "vim.pack" })
    end)
end

for _, p in ipairs(vim.pack.get(nil, { info = false })) do
    if p.active then
        M.active[p.spec.name] = true
    end
end

require("config.tools").setup(M)

return M
