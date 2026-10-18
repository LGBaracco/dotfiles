-- Molten literate REPL for Quarto (.qmd). Loaded by lze (plugins.repl.quarto) on ft=quarto/python.
-- Python host: uv tool env `pynvim` (see plugins/repl/quarto.lua). Restart Neovim after installing/refreshing it.
-- Molten* commands are remote-plugin commands from the rplugin manifest (sourced at
-- startup). ,i regenerates the manifest itself when it is missing/stale (e.g. after a
-- nixpkgs bump changed molten's store path) and asks for a restart. Off Nix the
-- vim.pack hook (config.pack) and :PackSync regenerate it on install/update.
-- From a .py buffer, ,i opens project-root repl.qmd (or an in-memory template) and owns the kernel.
-- .ipynb buffers (jupytext.nvim, ft=quarto, see plugins/repl/quarto.lua) auto-attach a kernel on
-- open (UV project kernel + wiring, else the notebook's kernelspec, else a picker), import saved
-- outputs, and export outputs back into the notebook on :w. ,N converts a plain .qmd to .ipynb.
-- ,I prompts for a Jupyter server (laptop → `tunnel <node>` → `start-server` on a compute node)
-- and attaches its default kernel; ,k swaps the buffer's kernel (project / remote / kernelspec).
-- Files on sshfs mounts (mju/mws) never get a local uv kernel: it would rebuild the cluster .venv.

-- snacks.image (unicode placeholders): the plot is its own virt_lines extmark created
-- after Molten's text extmark, so it always sits below stdout. image.nvim was dropped
-- because its pixel-positioned image raced Molten's extmark re-creation (see AGENTS.md).
vim.g.molten_image_provider = "snacks.nvim"
-- virt under cell + float on ,o (plots included in both).
vim.g.molten_image_location = "both"
vim.g.molten_virt_text_output = true
vim.g.molten_virt_lines_off_by_1 = true
vim.g.molten_wrap_output = true
vim.g.molten_auto_open_output = false
-- One ,o opens the float and focuses it so yank/inspect works.
vim.g.molten_enter_output_behavior = "open_and_enter"
-- Table form required for use_border_highlights (string styles like "rounded"
-- only paint a static border; Molten injects Success/Fail hl into table entries).
vim.g.molten_output_win_border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
vim.g.molten_output_win_max_height = 20
-- Room for cell text above a plot before truncation (default 12 clips early).
vim.g.molten_virt_text_max_lines = 64
-- Float border colour tracks cell state (MoltenOutputBorderSuccess/Fail below).
vim.g.molten_use_border_highlights = true
-- "N more lines" footer when the float is capped at output_win_max_height.
vim.g.molten_output_show_more = true
-- Pad the buffer with virt lines while the float is open so it covers no code.
vim.g.molten_output_virt_lines = true
-- Poll the kernel faster than the 500 ms default for snappier output.
vim.g.molten_tick_rate = 200

-- Molten only links its groups when they don't exist yet (hl_utils), so define
-- them before init. oxocarbon's FloatBorder is fg == bg (invisible), hence the
-- explicit border colours. Re-applied on :colorscheme.
local function set_molten_highlights()
    local hl = vim.api.nvim_set_hl
    hl(0, "MoltenOutputBorder", { fg = "#525252", bg = "NONE" })
    hl(0, "MoltenOutputBorderSuccess", { fg = "#42be65", bg = "NONE" })
    hl(0, "MoltenOutputBorderFail", { fg = "#ee5396", bg = "NONE" })
    hl(0, "MoltenOutputWin", { link = "NormalFloat" })
    hl(0, "MoltenOutputWinNC", { link = "NormalFloat" })
    hl(0, "MoltenOutputFooter", { fg = "#78a9ff", bg = "NONE", italic = true })
    hl(0, "MoltenCell", { link = "CursorLine" })
    -- Comment is too dim for stdout; base04 without italics.
    hl(0, "MoltenVirtualText", { fg = "#dde1e6", bg = "NONE" })
end
set_molten_highlights()

local REPL_BASENAME = "repl.qmd"

local SKIP_DIRS = {
    [".git"] = true,
    [".venv"] = true,
    ["venv"] = true,
    [".tox"] = true,
    ["node_modules"] = true,
    ["__pycache__"] = true,
    [".mypy_cache"] = true,
    [".pytest_cache"] = true,
    [".ruff_cache"] = true,
    ["dist"] = true,
    ["build"] = true,
    ["tests"] = true,
    ["test"] = true,
    ["docs"] = true,
}

---Pending wire keyed by bufnr; consumed on MoltenKernelReady.
---Fields: kernel? (nil when Molten's picker chose), mode ("document"|"inject"|"none"),
---code? (inject only), import_outputs? (run MoltenImportOutput once the kernel is up)
local pending_wire = {}

local augroup = vim.api.nvim_create_augroup("molten_literate", { clear = true })

vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    callback = set_molten_highlights,
})

---Remote kernel labels keyed by server base URL ("http://host:port"), e.g. "atlas@localhost:8888".
local remote_labels = {}

---Statusline/notify name for a kernel id. Remote ids are the full server URL (token
---included), so they map to a token-free label.
local function kernel_label(id)
    local base = id:match("^(https?://[^/?#]+)")
    if base then
        return remote_labels[base] or ("remote " .. (base:gsub("^https?://", "")))
    end
    if id:match("%.json$") then
        return vim.fs.basename(id)
    end
    return id
end

-- Kernel state for the statusline (plugins.ui lualine reads vim.b.molten_kernel).
-- Cached from Molten's User events: calling MoltenStatusLineKernels on every
-- redraw would spawn the Python host in buffers that never used Molten.
vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "MoltenKernelReady",
    callback = function(ev)
        local id = ev.data and ev.data.kernel_id
        if id and id ~= "" then
            vim.b.molten_kernel = kernel_label(id)
        end
    end,
})
vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "MoltenDeinitPost",
    callback = function()
        vim.b.molten_kernel = nil
    end,
})

local find_project_root = require("config.python_project").find_project_root

local function notify(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = "Molten" })
end

local function project_name_from_toml(pyproject)
    if not pyproject then
        return nil
    end
    local ok, lines = pcall(vim.fn.readfile, pyproject)
    if not ok then
        return nil
    end
    local in_project = false
    for _, line in ipairs(lines) do
        if line:match("^%s*%[") then
            in_project = line:match("^%s*%[project%]%s*$") ~= nil
        elseif in_project then
            local name = line:match('^%s*name%s*=%s*"([^"]+)"') or line:match("^%s*name%s*=%s*'([^']+)'")
            if name then
                return name
            end
        end
    end
    return nil
end

local function to_module_name(name)
    return (name:gsub("-", "_"))
end

local function kernel_name_for(root, pkg_name)
    if pkg_name then
        return to_module_name(pkg_name)
    end
    return to_module_name(vim.fs.basename(root))
end

local function repl_path(root)
    return vim.fs.normalize(root .. "/" .. REPL_BASENAME)
end

---True for a jupytext-backed notebook buffer (buffer name keeps the .ipynb path).
local function is_notebook_buf(bufnr)
    return vim.api.nvim_buf_get_name(bufnr or 0):match("%.ipynb$") ~= nil
end

---metadata.kernelspec.name from an .ipynb on disk, or nil.
local function notebook_kernelspec(path)
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then
        return nil
    end
    local decoded, nb = pcall(vim.json.decode, table.concat(lines, "\n"))
    if not decoded or type(nb) ~= "table" then
        return nil
    end
    local spec = type(nb.metadata) == "table" and nb.metadata.kernelspec or nil
    return type(spec) == "table" and spec.name or nil
end

---True when at least one Molten kernel is attached to the current buffer.
---rplugin functions are defined lazily (FuncUndefined), so exists("*Molten…") stays 0 even
---while the host runs; the manifest's :MoltenInit is the reliable "Molten is loaded" signal.
local function molten_attached()
    if vim.fn.exists(":MoltenInit") ~= 2 then
        return false
    end
    local ok, kernels = pcall(vim.fn.MoltenStatusLineKernels, true)
    return ok and kernels ~= nil and kernels ~= ""
end

---Jupyter data dir as jupyter_core resolves it (Molten writes connection files under
---<data_dir>/runtime and assumes the directory exists).
local function jupyter_data_dir()
    local env = vim.env.JUPYTER_DATA_DIR
    if env and env ~= "" then
        return vim.fs.normalize(env)
    end
    local xdg = vim.env.XDG_DATA_HOME
    if not xdg or xdg == "" then
        xdg = vim.fn.expand("~/.local/share")
    end
    return vim.fs.normalize(xdg .. "/jupyter")
end

local function ensure_jupyter_runtime_dir()
    local dir = jupyter_data_dir() .. "/runtime"
    local existed = vim.fn.isdirectory(dir) == 1
    if not existed then
        vim.fn.mkdir(dir, "p")
    end
    return vim.fn.isdirectory(dir) == 1
end

---Warn when the project venv is built on the Nix/HM python: pip wheels with C++
---extensions (pyzmq, greenlet) fail there with missing libstdc++.so.6.
local function warn_if_nix_venv(root)
    local cfg = root .. "/.venv/pyvenv.cfg"
    if vim.fn.filereadable(cfg) == 0 then
        return
    end
    for _, l in ipairs(vim.fn.readfile(cfg)) do
        local home = l:match("^%s*home%s*=%s*(.+)$")
        if home and (home:find("/nix/store", 1, true) or home:find("/etc/profiles", 1, true)) then
            notify(
                "Project .venv uses the Nix python; ipykernel wheels will fail. Run `uv python pin 3.12 && uv sync` (uv-managed CPython).",
                vim.log.levels.WARN
            )
            return
        end
    end
end

local FUSE_SUPER_MAGIC = 0x65735546

---True when `path` lives on a FUSE mount (sshfs `mju`/`mws`). A local `uv run --project`
---there finds the cluster's .venv linked to a Python the laptop lacks, deletes and rebuilds it.
local function on_fuse_mount(path)
    local st = vim.uv.fs_statfs(path)
    return st ~= nil and st.type == FUSE_SUPER_MAGIC
end

---Kernel command: uv layers ipykernel over the project env at launch time, so the
---project venv stays untouched and `uv sync` cannot remove the kernel.
local function kernel_argv(root)
    return require("config.python_project").uv_run_argv(root, { "ipykernel" }, {
        "python",
        "-Xfrozen_modules=off",
        "-m",
        "ipykernel_launcher",
        "-f",
        "{connection_file}",
    })
end

---True for a kernel spec written by ensure_kernel_spec whose project dir no longer exists.
local function is_stale_project_spec(name)
    local file = jupyter_data_dir() .. "/kernels/" .. name .. "/kernel.json"
    local ok, spec = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
    end)
    if not ok or type(spec) ~= "table" or type(spec.metadata) ~= "table" then
        return false
    end
    if spec.metadata.managed_by ~= "nvim-molten-literate" or type(spec.argv) ~= "table" then
        return false
    end
    for i, arg in ipairs(spec.argv) do
        if arg == "--project" and spec.argv[i + 1] then
            return vim.fn.isdirectory(spec.argv[i + 1]) == 0
        end
    end
    return false
end

---Write ~/.local/share/jupyter/kernels/<name>/kernel.json (idempotent).
local function ensure_kernel_spec(root, name)
    local argv = kernel_argv(root)
    if not argv then
        notify("`uv` not found on PATH; cannot build the kernel spec.", vim.log.levels.ERROR)
        return false
    end
    local dir = jupyter_data_dir() .. "/kernels/" .. name
    local file = dir .. "/kernel.json"
    local spec = {
        argv = argv,
        display_name = name .. " (uv)",
        language = "python",
        interrupt_mode = "signal",
        metadata = { debugger = true, managed_by = "nvim-molten-literate" },
    }
    local current = nil
    if vim.fn.filereadable(file) == 1 then
        local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
        if ok then
            current = decoded
        end
    end
    local changed = not vim.deep_equal(current, spec)
    if changed then
        vim.fn.mkdir(dir, "p")
        vim.fn.writefile({ vim.json.encode(spec) }, file)
        notify(("Kernel spec %q written (uv run --with ipykernel)."):format(name))
    end
    return vim.fn.filereadable(file) == 1
end

local function collect_import_targets(root, pkg_name)
    local targets = {}
    local seen = {}

    local function add(mod)
        if mod and mod ~= "" and not seen[mod] then
            seen[mod] = true
            table.insert(targets, mod)
        end
    end

    if pkg_name then
        add(to_module_name(pkg_name))
    end

    local function scan(dir)
        local handle = vim.uv.fs_scandir(dir)
        if not handle then
            return
        end
        while true do
            local name, ty = vim.uv.fs_scandir_next(handle)
            if not name then
                break
            end
            if name:sub(1, 1) == "." or SKIP_DIRS[name] then
                goto continue
            end
            local path = dir .. "/" .. name
            if ty == "directory" then
                if vim.uv.fs_stat(path .. "/__init__.py") then
                    add(name)
                end
            elseif ty == "file" and name:match("%.py$") and name ~= "__init__.py" then
                add(name:sub(1, -4))
            end
            ::continue::
        end
    end

    scan(root)
    local src = root .. "/src"
    if vim.uv.fs_stat(src) then
        scan(src)
    end

    return targets
end

---Python lines for a visible setup cell (IPython magics as real magics).
local function bootstrap_cell_lines(root, pkg_name)
    local imports = collect_import_targets(root, pkg_name)
    local lines = {
        "import sys",
        "from pathlib import Path",
        ("_root = Path(%q)"):format(root),
        "for _p in (_root, _root / 'src'):",
        "    _s = str(_p)",
        "    if _p.is_dir() and _s not in sys.path:",
        "        sys.path.insert(0, _s)",
        "%load_ext autoreload",
        "%autoreload 2",
    }
    for _, mod in ipairs(imports) do
        table.insert(lines, "try:")
        table.insert(lines, ("    import %s"):format(mod))
        table.insert(lines, ("    from %s import *"):format(mod))
        table.insert(lines, "except Exception as _e:")
        table.insert(lines, ("    print('molten wire: skip import %s:', _e)"):format(mod))
    end
    table.insert(lines, ("print('molten wire: root=%s imports=%s')"):format(root, table.concat(imports, ",")))
    return lines, imports
end

---Invisible inject payload (magics via get_ipython — exec-safe).
local function build_inject_bootstrap(root, pkg_name)
    local cell = bootstrap_cell_lines(root, pkg_name)
    local lines = {}
    for _, line in ipairs(cell) do
        if line == "%load_ext autoreload" then
            table.insert(lines, "get_ipython().run_line_magic('load_ext', 'autoreload')")
        elseif line == "%autoreload 2" then
            table.insert(lines, "get_ipython().run_line_magic('autoreload', '2')")
        else
            table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n")
end

local function build_repl_template(root, pkg_name)
    local cell = bootstrap_cell_lines(root, pkg_name)
    local kernel = kernel_name_for(root, pkg_name)
    local out = {
        "---",
        "title: Literate REPL",
        ("jupyter: %s"):format(kernel),
        "---",
        "",
        "# Literate REPL",
        "",
        "```{python}",
        "#| label: setup",
    }
    vim.list_extend(out, cell)
    vim.list_extend(out, {
        "```",
        "",
        "```{python}",
        "# scratch",
        "",
        "```",
        "",
    })
    return out
end

---Ensure YAML `jupyter:` uses the Molten UV kernel. QuartoPreview reads the file on disk.
---@return boolean changed
local function ensure_jupyter_frontmatter(bufnr, kernel)
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local limit = math.min(line_count, 80)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, limit, false)
    if not lines[1] or not lines[1]:match("^---%s*$") then
        return false
    end
    local changed = false
    for i = 2, #lines do
        local line = lines[i]
        if line:match("^---%s*$") then
            break
        end
        local replaced = line:gsub("^jupyter:%s*.*$", "jupyter: " .. kernel)
        if replaced ~= line then
            lines[i] = replaced
            changed = true
        end
    end
    if not changed then
        return false
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, limit, false, lines)
    vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("silent update")
    end)
    return true
end

local function literate_preview()
    local buf = vim.api.nvim_get_current_buf()
    local path = vim.api.nvim_buf_get_name(buf)
    local root, pyproject = find_project_root(path ~= "" and vim.fs.dirname(path) or nil)
    if not pyproject then
        notify(("Not a UV project (no pyproject.toml above %s)."):format(root), vim.log.levels.ERROR)
        return
    end
    local pkg_name = project_name_from_toml(pyproject)
    local kernel = kernel_name_for(root, pkg_name)
    if not ensure_kernel_spec(root, kernel) then
        return
    end
    ensure_jupyter_frontmatter(buf, kernel)

    local ok, err = pcall(function()
        require("quarto").quartoPreview()
    end)
    if not ok then
        notify("QuartoPreview failed: " .. tostring(err), vim.log.levels.ERROR)
    end
end

local function evaluate_inject(kernel_id, code)
    -- JSON string literal == Python str literal (\n, \", \uXXXX). Lua's %q writes newlines
    -- as backslash-newline, which Python reads as line continuation (one-line SyntaxError).
    local payload = ("exec(%s)"):format(vim.json.encode(code))
    local args = { payload }
    if kernel_id and kernel_id ~= "" then
        args = { kernel_id, payload }
    end
    vim.api.nvim_cmd({ cmd = "MoltenEvaluateArgument", args = args }, {})
end

local function find_buf_by_name(path)
    path = vim.fs.normalize(path)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if name ~= "" and vim.fs.normalize(name) == path then
                return buf
            end
        end
    end
    return nil
end

---Jump to a window showing `bufnr`, or open a vertical split on the right for it.
local function open_repl_window(bufnr)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(win) == bufnr then
            vim.api.nvim_set_current_win(win)
            return
        end
    end
    vim.cmd("vertical rightbelow split")
    vim.api.nvim_set_current_buf(bufnr)
end

local map_quarto_buf -- forward decl

---Open root/repl.qmd in a right-hand vertical split (or jump to an existing window).
---If missing on disk, create an unsaved in-memory buffer named repl.qmd.
---@return integer bufnr
---@return boolean is_new_template
local function ensure_repl_buffer(root, pkg_name)
    local path = repl_path(root)

    if vim.uv.fs_stat(path) then
        local existing = find_buf_by_name(path)
        if existing then
            open_repl_window(existing)
            return existing, false
        end
        vim.cmd("vertical rightbelow split")
        vim.cmd.edit(vim.fn.fnameescape(path))
        return vim.api.nvim_get_current_buf(), false
    end

    local existing = find_buf_by_name(path)
    if existing then
        open_repl_window(existing)
        return existing, false
    end

    vim.cmd("vertical rightbelow split")
    vim.cmd.enew()
    local buf = vim.api.nvim_get_current_buf()
    -- Named path so :w writes repl.qmd; not written until the user saves.
    vim.api.nvim_buf_set_name(buf, path)
    vim.bo[buf].filetype = "quarto"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, build_repl_template(root, pkg_name))
    vim.bo[buf].modified = true

    pcall(function()
        require("quarto").activate()
    end)
    if map_quarto_buf then
        map_quarto_buf(buf)
    end
    pcall(function()
        require("which-key").add({
            { "<localleader>", group = "molten", buffer = buf },
        })
    end)

    notify(("Opened in-memory %s (save to persist)"):format(REPL_BASENAME))
    return buf, true
end

local function start_kernel_on_current(root, pkg_name, name, wire_mode, inject_code, import_outputs)
    local buf = vim.api.nvim_get_current_buf()
    pending_wire[buf] = {
        kernel = name,
        mode = wire_mode,
        code = inject_code,
        import_outputs = import_outputs,
    }
    notify(("Initializing kernel %q (root %s)…"):format(name, root))
    vim.cmd("MoltenInit " .. name)
end

---Resolved like UpdateRemotePlugins does (packdir entries are symlinks into the store).
local function molten_rplugin_path()
    local p = vim.fn.globpath(vim.o.rtp, "rplugin/python3/molten", 1, 1)[1]
    return p and vim.fn.resolve(p) or nil
end

---True when the rplugin manifest references molten's current RTP path.
local function manifest_is_current()
    local manifest = vim.g.loaded_remote_plugins
    local path = molten_rplugin_path()
    if not path or type(manifest) ~= "string" or vim.fn.filereadable(manifest) == 0 then
        return false
    end
    for _, l in ipairs(vim.fn.readfile(manifest)) do
        if l:find(path, 1, true) then
            return true
        end
    end
    return false
end

---Molten* commands come from the rplugin manifest. lze has already packadd'd
---molten-nvim by the time this runs, so UpdateRemotePlugins can see it.
local function ensure_remote_plugin()
    local exists = vim.fn.exists(":MoltenInit") == 2
    local current = manifest_is_current()
    if exists and current then
        return true
    end
    local ok, err = pcall(vim.cmd, "UpdateRemotePlugins")
    if ok then
        notify("Molten rplugin manifest regenerated. Restart Neovim, then run ,i again.", vim.log.levels.WARN)
    else
        notify(
            "UpdateRemotePlugins failed: " .. tostring(err) .. "\nCheck :checkhealth provider.python",
            vim.log.levels.ERROR
        )
    end
    return false
end

--- Remote kernels ---
-- `MoltenInit http(s)://…` goes through Molten's JupyterAPIManager: it keeps only
-- scheme://host:port and ?token=, POSTs /api/kernels without a body (the server's default
-- kernel starts: `start-server` sets --MappingKernelManager.default_kernel_name), talks plain
-- ws:// without a base_url and has no stdin (input() hangs). The full URL is the kernel id;
-- MoltenDeinit DELETEs the remote kernel.

local REMOTE_DEFAULT_URL = "http://localhost:8888/?token="
local REMOTE_STATE_FILE = vim.fn.stdpath("state") .. "/molten_remote_url"

-- Project paths are the laptop's, so no sys.path/import wiring: autoreload + where it runs.
local REMOTE_BOOTSTRAP = table.concat({
    "get_ipython().run_line_magic('load_ext', 'autoreload')",
    "get_ipython().run_line_magic('autoreload', '2')",
    "import os as _os, socket as _socket",
    "print(f'molten wire: remote host={_socket.gethostname()} cwd={_os.getcwd()}')",
}, "\n")

---Last server URL that passed the preflight (survives restarts within one Slurm job).
local function last_remote_url()
    local ok, lines = pcall(vim.fn.readfile, REMOTE_STATE_FILE)
    return ok and lines[1] ~= nil and lines[1] ~= "" and lines[1] or nil
end

local function save_remote_url(url)
    vim.fn.mkdir(vim.fs.dirname(REMOTE_STATE_FILE), "p")
    local mode = tonumber("600", 8) -- the URL carries the token
    local fd = vim.uv.fs_open(REMOTE_STATE_FILE, "w", mode)
    if fd then
        vim.uv.fs_write(fd, url .. "\n")
        vim.uv.fs_close(fd)
        vim.uv.fs_chmod(REMOTE_STATE_FILE, mode)
    end
end

---Accepts a server URL with any path (start-server's http://127.0.0.1:8888/tree?token=…),
---host:port[/?token=…], a bare token (→ localhost:8888, the `tunnel` port) or a kernel
---connection .json.
---@return string|nil
local function normalize_remote(input)
    input = vim.trim(input or "")
    if input == "" then
        return nil
    end
    if input:match("%.json$") then
        return vim.fs.normalize(input)
    end
    if input:match("^https?://") then
        return input
    end
    if input:find("[:/]") then
        return "http://" .. input
    end
    return REMOTE_DEFAULT_URL .. input
end

---@return string base "http://host:port"
---@return string|nil token
local function remote_parts(url)
    local base = url:match("^(https?://[^/?#]+)")
    local token = url:match("[?&]token=([^&#]*)")
    return base, token ~= "" and token or nil
end

---Query /api/kernelspecs before MoltenInit, which is sync and has no timeout (an unreachable
---host would freeze nvim). cb(err, default_kernel) runs on the main loop.
local function remote_preflight(url, cb)
    if vim.fn.executable("curl") == 0 then
        cb(nil, nil)
        return
    end
    local base, token = remote_parts(url)
    local hostport = (base:gsub("^https?://", ""))
    local cmd = { "curl", "-sS", "-m", "5", "-w", "\n%{http_code}", base .. "/api/kernelspecs" }
    local stdin = nil
    if token then
        -- Header read from stdin keeps the token out of `ps`.
        vim.list_extend(cmd, { "-H", "@-" })
        stdin = "Authorization: token " .. token .. "\n"
    end
    vim.system(cmd, { text = true, stdin = stdin }, vim.schedule_wrap(function(res)
        if res.code == 7 then
            return cb(("Nothing listening on %s. Is `tunnel <node>` up and `start-server` running?"):format(hostport))
        elseif res.code == 28 then
            return cb(("%s timed out."):format(hostport))
        elseif res.code ~= 0 then
            return cb(("curl failed (%d): %s"):format(res.code, vim.trim(res.stderr or "")))
        end
        local body, status = (res.stdout or ""):match("^(.*)\n(%d+)$")
        status = tonumber(status)
        if status == 401 or status == 403 then
            return cb(("%s rejected the token."):format(hostport))
        elseif status ~= 200 then
            return cb(("%s answered HTTP %s; not a Jupyter server?"):format(hostport, status or "?"))
        end
        local ok, specs = pcall(vim.json.decode, body)
        cb(nil, ok and type(specs) == "table" and type(specs.default) == "string" and specs.default or nil)
    end))
end

---MoltenDeinit (every kernel on the current buffer, outputs cleared). False when none.
local function deinit_if_attached()
    if not molten_attached() then
        return false
    end
    vim.cmd("MoltenDeinit")
    return true
end

---Prompt for a Jupyter server, check it, then replace the buffer's kernel with the server's
---default kernel. The current kernel survives typos, a dead tunnel and a stale token.
local function remote_connect(bufnr)
    vim.ui.input({
        prompt = "Jupyter server (URL, host:port, token or kernel .json): ",
        default = last_remote_url() or REMOTE_DEFAULT_URL,
    }, function(input)
        local target = normalize_remote(input)
        if not target then
            return
        end

        local function attach(label)
            if vim.api.nvim_get_current_buf() ~= bufnr then
                notify("Buffer changed before the kernel started; try again.", vim.log.levels.WARN)
                return
            end
            local had = deinit_if_attached()
            pending_wire[bufnr] = {
                kernel = label,
                mode = "inject",
                code = REMOTE_BOOTSTRAP,
                import_outputs = is_notebook_buf(bufnr) and not had,
            }
            notify(("Connecting to %s…"):format(label))
            -- MoltenInit is -complete=file: without magic.file=false `?`, `#`, `%` would expand.
            vim.api.nvim_cmd({ cmd = "MoltenInit", args = { target }, magic = { file = false, bar = false } }, {})
        end

        if not target:match("^https?://") then
            attach(vim.fs.basename(target))
            return
        end
        remote_preflight(target, function(err, default_kernel)
            if err then
                notify(err, vim.log.levels.ERROR)
                return
            end
            save_remote_url(target)
            local base = remote_parts(target)
            remote_labels[base] = ("%s@%s"):format(default_kernel or "remote", (base:gsub("^https?://", "")))
            attach(remote_labels[base])
        end)
    end)
end

---,I: like ,i, but the kernel comes from a (prompted) Jupyter server. From .py, opens repl.qmd.
local function literate_remote_init()
    if not ensure_remote_plugin() then
        return
    end
    if vim.bo.filetype ~= "quarto" then
        local root, pyproject = find_project_root()
        ensure_repl_buffer(root, project_name_from_toml(pyproject))
    end
    remote_connect(vim.api.nvim_get_current_buf())
end

---,k: replace the buffer's kernel, wired like the init paths: project kernel (uv + injected
---setup, as ,i), a remote server (as ,I) or any installed kernelspec (no wiring). With no
---kernel attached it is just an init with a picker. Notebook outputs are imported only on a
---first attach; a switch starts clean.
local function switch_kernel()
    if not ensure_remote_plugin() then
        return
    end
    local buf = vim.api.nvim_get_current_buf()
    local path = vim.api.nvim_buf_get_name(buf)
    local root, pyproject = find_project_root(path ~= "" and vim.fs.dirname(path) or nil)
    local current = vim.b[buf].molten_kernel
    local remote_current = current ~= nil and (current:find("@", 1, true) ~= nil or current:match("^remote ") ~= nil)

    local items = {}
    local project = nil
    if pyproject and not on_fuse_mount(root) then
        local pkg_name = project_name_from_toml(pyproject)
        project = kernel_name_for(root, pkg_name)
        table.insert(items, { kind = "project", name = project, pkg_name = pkg_name, label = project .. " (uv project)" })
    end
    table.insert(items, {
        kind = "remote",
        label = "Remote Jupyter server…" .. (remote_current and (" (current: %s)"):format(current) or ""),
    })
    local ok, specs = pcall(vim.fn.MoltenAvailableKernels)
    for _, spec in ipairs(ok and specs or {}) do
        if spec ~= project and not is_stale_project_spec(spec) then
            table.insert(items, { kind = "spec", name = spec, label = spec })
        end
    end
    for _, item in ipairs(items) do
        if item.name and item.name == current then
            item.label = item.label .. " (current)"
        end
    end

    vim.ui.select(items, {
        prompt = "Molten kernel",
        format_item = function(item)
            return item.label
        end,
    }, function(choice)
        if not choice then
            return
        end
        if vim.api.nvim_get_current_buf() ~= buf then
            notify("Buffer changed before the kernel switch; try again.", vim.log.levels.WARN)
            return
        end
        if choice.kind == "remote" then
            remote_connect(buf)
            return
        end
        if choice.name == current then
            notify(("%s is already attached (,R restarts it)."):format(current))
            return
        end
        if not ensure_jupyter_runtime_dir() then
            notify("Could not create the Jupyter runtime dir under " .. jupyter_data_dir(), vim.log.levels.ERROR)
            return
        end
        if choice.kind == "project" then
            warn_if_nix_venv(root)
            if not ensure_kernel_spec(root, choice.name) then
                return
            end
        end

        local had = deinit_if_attached()
        local import_outputs = is_notebook_buf(buf) and not had
        if choice.kind == "project" then
            local code = build_inject_bootstrap(root, choice.pkg_name)
            start_kernel_on_current(root, choice.pkg_name, choice.name, "inject", code, import_outputs)
        else
            pending_wire[buf] = { kernel = choice.name, mode = "none", import_outputs = import_outputs }
            notify(("Initializing kernel %q…"):format(choice.name))
            vim.cmd("MoltenInit " .. choice.name)
        end
    end)
end

local function literate_init()
    if not ensure_remote_plugin() then
        return
    end

    local root, pyproject = find_project_root()
    if not pyproject then
        notify(
            ("Not a UV project (no pyproject.toml above %s). Run `uv init` there first."):format(root),
            vim.log.levels.ERROR
        )
        return
    end
    if on_fuse_mount(root) then
        notify(
            ("%s is on an sshfs/FUSE mount: a local uv kernel would rebuild its .venv. Use ,I (cluster Jupyter server) or ,k (kernelspec)."):format(root),
            vim.log.levels.ERROR
        )
        return
    end
    local pkg_name = project_name_from_toml(pyproject)
    warn_if_nix_venv(root)

    if not ensure_jupyter_runtime_dir() then
        notify("Could not create the Jupyter runtime dir under " .. jupyter_data_dir(), vim.log.levels.ERROR)
        return
    end

    local name = kernel_name_for(root, pkg_name)
    if not ensure_kernel_spec(root, name) then
        return
    end

    local ft = vim.bo.filetype
    local is_new = false
    -- From .py (or anything that isn't already the REPL), jump to repl.qmd.
    if ft ~= "quarto" then
        local _, created = ensure_repl_buffer(root, pkg_name)
        is_new = created
    end

    if is_new then
        -- Setup lives in the document; run cells after the kernel is ready.
        start_kernel_on_current(root, pkg_name, name, "document")
    else
        -- Existing qmd (or .ipynb): don't auto-run the whole notebook; inject wiring once.
        local code = build_inject_bootstrap(root, pkg_name)
        start_kernel_on_current(root, pkg_name, name, "inject", code, is_notebook_buf(0))
    end
end

---Attach a kernel to a jupytext-backed .ipynb buffer and import its saved outputs.
---UV project: project kernel + injected wiring (same as ,i). Otherwise the notebook's
---kernelspec when installed, else Molten's picker. Runs once per buffer.
local function notebook_auto_init(bufnr)
    if vim.b[bufnr].molten_notebook_wired then
        return
    end
    vim.b[bufnr].molten_notebook_wired = true

    local path = vim.api.nvim_buf_get_name(bufnr)
    if on_fuse_mount(vim.fs.dirname(path)) then
        notify("Notebook on an sshfs/FUSE mount: no local kernel started. ,I attaches a Jupyter server, ,k picks a kernel.")
        return
    end
    if not ensure_remote_plugin() then
        return
    end
    if not ensure_jupyter_runtime_dir() then
        notify("Could not create the Jupyter runtime dir under " .. jupyter_data_dir(), vim.log.levels.ERROR)
        return
    end

    local root, pyproject = find_project_root(vim.fs.dirname(path))
    if pyproject then
        local pkg_name = project_name_from_toml(pyproject)
        warn_if_nix_venv(root)
        local name = kernel_name_for(root, pkg_name)
        if not ensure_kernel_spec(root, name) then
            return
        end
        local code = build_inject_bootstrap(root, pkg_name)
        start_kernel_on_current(root, pkg_name, name, "inject", code, true)
        return
    end

    local spec = notebook_kernelspec(path)
    local ok, available = pcall(vim.fn.MoltenAvailableKernels)
    if spec and ok and vim.tbl_contains(available, spec) then
        pending_wire[bufnr] = { kernel = spec, mode = "none", import_outputs = true }
        notify(("Initializing notebook kernel %q…"):format(spec))
        vim.cmd("MoltenInit " .. spec)
    else
        pending_wire[bufnr] = { mode = "none", import_outputs = true }
        notify(
            ("Notebook kernel %q is not installed and this is not a UV project; pick a kernel."):format(spec or "?"),
            vim.log.levels.WARN
        )
        vim.cmd("MoltenInit")
    end
end

---Run notebook_auto_init once the buffer is the current one (MoltenInit and
---MoltenKernelReady both act on the current buffer).
local function schedule_notebook_auto_init(bufnr)
    vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(bufnr) or vim.b[bufnr].molten_notebook_wired then
            return
        end
        if vim.api.nvim_get_current_buf() == bufnr then
            notebook_auto_init(bufnr)
            return
        end
        vim.api.nvim_create_autocmd("BufEnter", {
            group = augroup,
            buffer = bufnr,
            once = true,
            callback = function()
                notebook_auto_init(bufnr)
            end,
        })
    end)
end

vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "MoltenKernelReady",
    callback = function(ev)
        local buf = vim.api.nvim_get_current_buf()
        local wire = pending_wire[buf]
        if not wire then
            return
        end
        pending_wire[buf] = nil
        local kernel_id = ev.data and ev.data.kernel_id or wire.kernel
        vim.schedule(function()
            if wire.mode == "document" then
                local ok, runner = pcall(require, "quarto.runner")
                if not ok then
                    notify("quarto.runner unavailable after init", vim.log.levels.ERROR)
                    return
                end
                -- multi_lang=true so never_run (yaml frontmatter / title) is
                -- respected; without it, cursor-in-yaml runs title: as code.
                local ran, err = pcall(runner.run_all, true)
                if not ran then
                    notify("Running REPL cells failed: " .. tostring(err), vim.log.levels.ERROR)
                    return
                end
            elseif wire.mode == "inject" then
                local ok, err = pcall(evaluate_inject, kernel_id, wire.code)
                if not ok then
                    notify("Bootstrap failed: " .. tostring(err), vim.log.levels.ERROR)
                    return
                end
            end
            if wire.import_outputs then
                local ok, err = pcall(vim.cmd, "MoltenImportOutput")
                if not ok then
                    notify("Importing notebook outputs failed: " .. tostring(err), vim.log.levels.WARN)
                end
            end
            notify(("Literate REPL ready (%s)"):format(wire.kernel or kernel_id or "kernel"))
        end)
    end,
})

-- jupytext.nvim re-emits BufWritePost after it has rewritten the .ipynb; push live
-- outputs into that same file so they survive the round trip.
vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    pattern = "*.ipynb",
    callback = function()
        if not molten_attached() then
            return
        end
        local ok, err = pcall(vim.cmd, "MoltenExportOutput!")
        if not ok then
            notify("Exporting outputs to the notebook failed: " .. tostring(err), vim.log.levels.WARN)
        end
    end,
})

---One-shot: convert the current .qmd into a sibling .ipynb (jupytext; --update keeps
---outputs of unchanged cells when the target exists), then export live Molten outputs.
local function notebook_export()
    local buf = vim.api.nvim_get_current_buf()
    local path = vim.api.nvim_buf_get_name(buf)
    if path == "" then
        notify("Buffer has no file name; save it as .qmd first.", vim.log.levels.ERROR)
        return
    end
    if is_notebook_buf(buf) then
        notify("Already a notebook buffer: :w writes the .ipynb.", vim.log.levels.WARN)
        return
    end
    if not path:match("%.qmd$") then
        notify("Not a .qmd buffer.", vim.log.levels.ERROR)
        return
    end
    if vim.fn.executable("jupytext") == 0 then
        notify(
            "`jupytext` CLI not found on PATH (Nix: module.nix runtimePkgs; elsewhere: `uv tool install jupytext`).",
            vim.log.levels.ERROR
        )
        return
    end

    -- jupytext reads from disk; this also persists an in-memory repl.qmd.
    vim.cmd("silent update")

    local target = vim.fn.fnamemodify(path, ":r") .. ".ipynb"
    local cmd = { "jupytext", "--to", "ipynb", "--output", target, path }
    if vim.uv.fs_stat(target) then
        table.insert(cmd, 2, "--update")
    end
    local res = vim.system(cmd, { text = true }):wait()
    if res.code ~= 0 then
        notify("jupytext failed:\n" .. (res.stderr or res.stdout or ""), vim.log.levels.ERROR)
        return
    end

    local with_outputs = false
    if molten_attached() then
        local ok, err = pcall(vim.api.nvim_cmd, { cmd = "MoltenExportOutput", bang = true, args = { target } }, {})
        if ok then
            with_outputs = true
        else
            notify("Exporting outputs failed: " .. tostring(err), vim.log.levels.WARN)
        end
    end
    notify(("Wrote %s%s"):format(vim.fn.fnamemodify(target, ":~:."), with_outputs and " (with outputs)" or ""))
end

local function with_runner(fn_name)
    return function()
        local ok, runner = pcall(require, "quarto.runner")
        if not ok then
            notify("quarto.runner unavailable; is quarto-nvim loaded?", vim.log.levels.ERROR)
            return
        end
        -- quarto.runner only applies codeRunner.never_run when lang is unset.
        -- run_all/run_above without multi_lang use the cursor language, so a
        -- cursor on YAML `title:` sends frontmatter to the kernel (SyntaxError).
        if fn_name == "run_all" or fn_name == "run_above" then
            runner[fn_name](true)
            return
        end
        -- Same trap for run_cell / run_line while the cursor sits in frontmatter.
        local never = (QuartoConfig and QuartoConfig.codeRunner and QuartoConfig.codeRunner.never_run) or { "yaml" }
        local otter_ok, otter = pcall(require, "otter.keeper")
        if otter_ok then
            local lang = otter.get_current_language_context()
            if lang and vim.tbl_contains(never, lang) then
                notify(("Not running %s chunk (never_run)"):format(lang), vim.log.levels.WARN)
                return
            end
        end
        runner[fn_name]()
    end
end

map_quarto_buf = function(bufnr)
    local opts = { buffer = bufnr, silent = true }
    local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", opts, { desc = desc }))
    end

    map("n", "<localleader>i", literate_init, "Molten literate init")
    map("n", "<localleader>I", literate_remote_init, "Molten remote init (Jupyter server prompt)")
    map("n", "<localleader>k", switch_kernel, "Molten switch kernel")
    map("n", "<localleader>e", with_runner("run_cell"), "Molten run cell")
    map("n", "<CR>", with_runner("run_cell"), "Molten run cell")
    map("n", "<localleader>l", with_runner("run_line"), "Molten run line")
    map("n", "<localleader>;", ":MoltenEvaluateOperator<CR>", "Molten evaluate operator")
    map("v", "<localleader>;", ":<C-u>MoltenEvaluateVisual<CR>gv", "Molten evaluate visual")
    map("n", "<localleader>o", ":noautocmd MoltenEnterOutput<CR>", "Molten enter output")
    map("n", "<localleader>r", ":MoltenReevaluateCell<CR>", "Molten re-evaluate cell")
    map("n", "<localleader>x", ":MoltenInterrupt<CR>", "Molten interrupt")
    map("n", "<localleader>q", ":MoltenDeinit<CR>", "Molten quit")
    map("n", "<localleader>a", with_runner("run_above"), "Molten run above")
    map("n", "<localleader>A", with_runner("run_all"), "Molten run all")
    map("n", "<localleader>d", ":MoltenDelete<CR>", "Molten delete cell")
    map("n", "<localleader>D", ":MoltenDelete!<CR>", "Molten delete all cells")
    map("n", "<localleader>p", literate_preview, "Quarto preview")
    map("n", "<localleader>N", notebook_export, "Export .qmd to .ipynb")

    -- Outputs
    map("n", "<localleader>y", ":MoltenYankOutput<CR>", "Molten yank output")
    map("n", "<localleader>Y", ":MoltenYankOutput!<CR>", "Molten yank output to clipboard")
    map("n", "<localleader>P", ":MoltenImagePopup<CR>", "Molten image popup (system viewer)")
    map("n", "<localleader>b", ":MoltenOpenInBrowser<CR>", "Molten open HTML output in browser")
    map("n", "<localleader>v", ":MoltenToggleVirtual<CR>", "Molten toggle virtual output")

    -- Kernel
    map("n", "<localleader>R", ":MoltenRestart<CR>", "Molten restart kernel")
    -- After Restart!, force-close any orphaned snacks placements (Molten only
    -- stores one img_identifier when image_location=both; see load_snacks_nvim).
    map("n", "<localleader>Z", function()
        vim.cmd("MoltenRestart!")
        pcall(function()
            require("load_snacks_nvim").snacks_api.clear_all()
        end)
    end, "Molten restart kernel + clear outputs")
    map("n", "<localleader>E", ":MoltenReevaluateAll<CR>", "Molten re-evaluate all cells")

    -- Cell navigation (Molten cells = evaluated spans; counts supported)
    map("n", "]c", function()
        vim.cmd("MoltenNext " .. vim.v.count1)
    end, "Molten next cell")
    map("n", "[c", function()
        vim.cmd("MoltenPrev " .. vim.v.count1)
    end, "Molten previous cell")
    map("n", "<localleader>g", function()
        vim.cmd("MoltenGoto " .. vim.v.count1)
    end, "Molten goto nth cell (count)")

    -- Treesitter code-block text objects (@code_cell, after/queries/markdown).
    -- Work on any fenced block, evaluated or not.
    local has_tso = pcall(require, "nvim-treesitter-textobjects")
    if has_tso then
        local function select_cell(capture)
            return function()
                require("nvim-treesitter-textobjects.select").select_textobject(capture, "textobjects")
            end
        end
        local function move_cell(fn)
            return function()
                require("nvim-treesitter-textobjects.move")[fn]("@code_cell.inner", "textobjects")
            end
        end
        vim.keymap.set({ "x", "o" }, "ib", select_cell("@code_cell.inner"), vim.tbl_extend("force", opts, { desc = "inner code cell" }))
        vim.keymap.set({ "x", "o" }, "ab", select_cell("@code_cell.outer"), vim.tbl_extend("force", opts, { desc = "a code cell" }))
        map("n", "]b", move_cell("goto_next_start"), "Next code block")
        map("n", "[b", move_cell("goto_previous_start"), "Previous code block")
    end
end

-- Minimal valid notebook so jupytext.nvim can convert it on :edit. Kernel name is
-- advisory: UV projects auto-attach their own kernel (notebook_auto_init).
local NEW_NOTEBOOK_TEMPLATE = [[{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# %s"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": []
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "name": "python"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 5
}
]]

local function new_notebook(name)
    if not name or name == "" then
        notify("Usage: :NewNotebook <path/name>[.ipynb]", vim.log.levels.ERROR)
        return
    end
    local path = vim.fn.fnamemodify(name, ":p")
    if not path:match("%.ipynb$") then
        path = path .. ".ipynb"
    end
    if vim.uv.fs_stat(path) then
        notify(("%s already exists; opening it."):format(vim.fn.fnamemodify(path, ":~:.")), vim.log.levels.WARN)
    else
        vim.fn.mkdir(vim.fs.dirname(path), "p")
        local title = vim.fn.fnamemodify(path, ":t:r")
        local ok = pcall(vim.fn.writefile, vim.split(NEW_NOTEBOOK_TEMPLATE:format(title), "\n"), path)
        if not ok then
            notify("Could not write " .. path, vim.log.levels.ERROR)
            return
        end
    end
    vim.cmd.edit(vim.fn.fnameescape(path))
end

local function map_python_buf(bufnr)
    vim.keymap.set("n", "<localleader>i", literate_init, {
        buffer = bufnr,
        silent = true,
        desc = "Molten literate init (open repl.qmd)",
    })
    vim.keymap.set("n", "<localleader>I", literate_remote_init, {
        buffer = bufnr,
        silent = true,
        desc = "Molten remote init (open repl.qmd, Jupyter server prompt)",
    })
end

vim.api.nvim_create_user_command("MoltenLiterateInit", literate_init, {
    desc = "Init Molten on project repl.qmd (create in-memory if missing)",
})

vim.api.nvim_create_user_command("MoltenRemoteInit", literate_remote_init, {
    desc = "Attach the default kernel of a Jupyter server (prompted URL / token)",
})

vim.api.nvim_create_user_command("MoltenSwitchKernel", switch_kernel, {
    desc = "Replace the buffer's kernel: project (uv), remote server or kernelspec",
})

vim.api.nvim_create_user_command("MoltenNotebookExport", notebook_export, {
    desc = "Convert the current .qmd to a sibling .ipynb (with Molten outputs when attached)",
})

vim.api.nvim_create_user_command("NewNotebook", function(o)
    new_notebook(o.args)
end, {
    nargs = 1,
    complete = "file",
    desc = "Create a blank .ipynb and open it (jupytext -> quarto buffer)",
})

---Quarto buffer setup: keymaps, which-key group, notebook auto-init for .ipynb buffers.
local function setup_quarto_buf(bufnr)
    map_quarto_buf(bufnr)
    pcall(function()
        require("which-key").add({
            { "<localleader>", group = "molten", buffer = bufnr },
        })
    end)
    if is_notebook_buf(bufnr) then
        schedule_notebook_auto_init(bufnr)
    end
end

vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = "quarto",
    callback = function(ev)
        setup_quarto_buf(ev.buf)
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = "python",
    callback = function(ev)
        map_python_buf(ev.buf)
        pcall(function()
            require("which-key").add({
                { "<localleader>i", desc = "Molten literate init", buffer = ev.buf },
                { "<localleader>I", desc = "Molten remote init", buffer = ev.buf },
            })
        end)
    end,
})

for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
        local ft = vim.bo[bufnr].filetype
        if ft == "quarto" then
            -- Covers the buffer whose FileType event loaded this module.
            setup_quarto_buf(bufnr)
        elseif ft == "python" then
            map_python_buf(bufnr)
        end
    end
end
