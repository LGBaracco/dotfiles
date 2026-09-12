-- Molten literate REPL for Quarto (.qmd). Loaded by lze (plugins.repl.quarto) on ft=quarto/python.
-- Python host: uv tool env `pynvim` (see plugins/repl/quarto.lua). Restart Neovim after installing/refreshing it.
-- Molten* commands are remote-plugin commands from the rplugin manifest (sourced at
-- startup). ,i regenerates the manifest itself when it is missing/stale (e.g. after a
-- nixpkgs bump changed molten's store path) and asks for a restart.
-- From a .py buffer, ,i opens project-root repl.qmd (or an in-memory template) and owns the kernel.

vim.g.molten_image_provider = "image.nvim"
vim.g.molten_virt_text_output = true
vim.g.molten_virt_lines_off_by_1 = true
vim.g.molten_wrap_output = true
vim.g.molten_auto_open_output = false
vim.g.molten_output_win_max_height = 20

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
---Fields: kernel, mode ("document"|"inject"), code? (inject only)
local pending_wire = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Molten" })
end

local function find_project_root(start)
  start = start or vim.fn.expand("%:p:h")
  if start == "" then
    start = vim.fn.getcwd()
  end
  local path = vim.fs.normalize(start)
  local pyproject = vim.fs.find("pyproject.toml", { upward = true, path = path })[1]
  if pyproject then
    return vim.fs.dirname(pyproject), pyproject
  end
  local git = vim.fs.find(".git", { upward = true, path = path, type = "directory" })[1]
  if git then
    return vim.fs.dirname(git), nil
  end
  return vim.fn.getcwd(), nil
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

---Kernel command: uv layers ipykernel over the project env at launch time, so the
---project venv stays untouched and `uv sync` cannot remove the kernel.
local function kernel_argv(root)
  local uv = vim.fn.exepath("uv")
  if uv == "" then
    return nil
  end
  return {
    uv,
    "run",
    "--project",
    root,
    "--with",
    "ipykernel",
    "python",
    "-Xfrozen_modules=off",
    "-m",
    "ipykernel_launcher",
    "-f",
    "{connection_file}",
  }
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
    table.insert(lines, ("except Exception as _e:"))
    table.insert(lines, ("    print('molten wire: skip import %s:', _e)"):format(mod))
  end
  table.insert(
    lines,
    ("print('molten wire: root=%s imports=%s')"):format(root, table.concat(imports, ","))
  )
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
    "Editable project REPL. The setup cell wires `sys.path`, autoreload, and imports.",
    "Re-run it after changing the package layout; use scratch cells below as the REPL.",
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
  local payload = ("exec(%q)"):format(code)
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

local function start_kernel_on_current(root, pkg_name, name, wire_mode, inject_code)
  local buf = vim.api.nvim_get_current_buf()
  pending_wire[buf] = {
    kernel = name,
    mode = wire_mode,
    code = inject_code,
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

local function literate_init()
  if not ensure_remote_plugin() then
    return
  end

  local root, pyproject = find_project_root()
  if not pyproject then
    notify(("Not a UV project (no pyproject.toml above %s). Run `uv init` there first."):format(root), vim.log.levels.ERROR)
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
    -- Existing qmd: don't auto-run the whole notebook; inject wiring once.
    local code = build_inject_bootstrap(root, pkg_name)
    start_kernel_on_current(root, pkg_name, name, "inject", code)
  end
end

vim.api.nvim_create_autocmd("User", {
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
        local ran, err = pcall(runner.run_all)
        if not ran then
          notify("Running REPL cells failed: " .. tostring(err), vim.log.levels.ERROR)
          return
        end
      else
        local ok, err = pcall(evaluate_inject, kernel_id, wire.code)
        if not ok then
          notify("Bootstrap failed: " .. tostring(err), vim.log.levels.ERROR)
          return
        end
      end
      notify(("Literate REPL ready (%s)"):format(wire.kernel))
    end)
  end,
})

local function with_runner(fn_name)
  return function()
    local ok, runner = pcall(require, "quarto.runner")
    if not ok then
      notify("quarto.runner unavailable; is quarto-nvim loaded?", vim.log.levels.ERROR)
      return
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
  map("n", "<localleader>e", with_runner("run_cell"), "Molten run cell")
  map("n", "<CR>", with_runner("run_cell"), "Molten run cell")
  map("n", "<localleader>l", with_runner("run_line"), "Molten run line")
  map("n", "<localleader>;", ":MoltenEvaluateOperator<CR>", "Molten evaluate operator")
  map("v", "<localleader>;", ":<C-u>MoltenEvaluateVisual<CR>gv", "Molten evaluate visual")
  map("n", "<localleader>o", ":noautocmd MoltenEnterOutput<CR>", "Molten enter output")
  map("n", "<localleader>O", ":MoltenHideOutput<CR>", "Molten hide output")
  map("n", "<localleader>r", ":MoltenReevaluateCell<CR>", "Molten re-evaluate cell")
  map("n", "<localleader>x", ":MoltenInterrupt<CR>", "Molten interrupt")
  map("n", "<localleader>q", ":MoltenDeinit<CR>", "Molten quit")
  map("n", "<localleader>a", with_runner("run_above"), "Molten run above")
  map("n", "<localleader>A", with_runner("run_all"), "Molten run all")
  map("n", "<localleader>d", ":MoltenDelete<CR>", "Molten delete cell")
  map("n", "<localleader>p", literate_preview, "Quarto preview")
end

local function map_python_buf(bufnr)
  vim.keymap.set("n", "<localleader>i", literate_init, {
    buffer = bufnr,
    silent = true,
    desc = "Molten literate init (open repl.qmd)",
  })
end

vim.api.nvim_create_user_command("MoltenLiterateInit", literate_init, {
  desc = "Init Molten on project repl.qmd (create in-memory if missing)",
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "quarto",
  callback = function(ev)
    map_quarto_buf(ev.buf)
    pcall(function()
      require("which-key").add({
        { "<localleader>", group = "molten", buffer = ev.buf },
      })
    end)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function(ev)
    map_python_buf(ev.buf)
    pcall(function()
      require("which-key").add({
        { "<localleader>i", desc = "Molten literate init", buffer = ev.buf },
      })
    end)
  end,
})

for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(bufnr) then
    local ft = vim.bo[bufnr].filetype
    if ft == "quarto" then
      map_quarto_buf(bufnr)
    elseif ft == "python" then
      map_python_buf(bufnr)
    end
  end
end
