-- Python environments of container kernels, for ty in Quarto buffers.
-- otter hands the cells to ty, which resolves imports from the *local* filesystem.
-- A kernel running inside an Apptainer/Singularity image (e.g. `atlas` on JURECA:
-- kernel.sh → `atlas-exec` → `singularity exec <sif>`) imports packages that only
-- exist inside the image, so every import is unresolved.
-- :KernelEnvSync <kernel> <sif> copies the image's Python sources (.py/.pyi/.pth/
-- py.typed under site-/dist-packages) out of its squashfs into
-- stdpath("cache")/kernel-env/<kernel>/. The image is read in place, so a .sif on
-- the sshfs mount (`mju`) is fine: only those files cross the wire (~400 MB for atlas).
-- plugins.repl.molten calls M.attach on kernel start/stop; the ty_otter client
-- (plugins.lsp) reads M.ty_settings in on_init and is restarted when that changes.
-- Needs `unsquashfs` (pack.json tools: squashfsTools).

local M = {}

local CACHE = vim.fs.joinpath(vim.fn.stdpath("cache"), "kernel-env")

-- nvim-lspconfig's ty root_markers.
M.markers = { "ty.toml", "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" }

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Kernel env" })
end

---ty workspace root of a buffer. otter's `<main>.otter.py` sits next to its main
---file, so the .qmd and its otter buffer map to the same ty_otter client.
---@param bufnr integer
---@return string
function M.root(bufnr)
  return vim.fs.root(bufnr, M.markers) or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
end

---@param kernel string
---@return { sif: string, python_version: string, paths: string[] }|nil
local function read_meta(kernel)
  local f = io.open(vim.fs.joinpath(CACHE, kernel, "env.json"))
  if not f then
    return nil
  end
  local ok, meta = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and type(meta) == "table" and meta or nil
end

---ty_otter root → kernel whose environment it uses.
---@type table<string, string>
local active = {}

---ty LSP settings for a ty_otter root, or nil to leave ty's own environment discovery.
---@param root string
---@return table|nil
function M.ty_settings(root)
  local kernel = active[root]
  local meta = kernel and read_meta(kernel)
  if not meta then
    return nil
  end
  local base = vim.fs.joinpath(CACHE, kernel, "root")
  return {
    ty = {
      configuration = {
        environment = {
          ["python-version"] = meta.python_version,
          ["extra-paths"] = vim.tbl_map(function(p)
            return vim.fs.joinpath(base, p)
          end, meta.paths),
        },
      },
    },
  }
end

---Point the ty_otter client of `bufnr` at `kernel`'s synced environment, or back to
---ty's own discovery (nil, or a kernel without one). Restarts ty_otter on a change.
---@param bufnr integer
---@param kernel string|nil
function M.attach(bufnr, kernel)
  if kernel and not read_meta(kernel) then
    kernel = nil
  end
  local root = M.root(bufnr)
  if active[root] == kernel then
    return
  end
  active[root] = kernel
  for _, client in ipairs(vim.lsp.get_clients({ name = "ty_otter" })) do
    if client.root_dir == root then
      -- :lsp restart reuses the client config, so on_init re-reads ty_settings.
      vim.cmd.lsp({ args = { "restart", "ty_otter" } })
      break
    end
  end
  if kernel then
    notify(("ty: %s packages (container image)"):format(kernel))
  end
end

---Byte offset of the squashfs partition inside a SIF (0 for a bare squashfs image).
---@param sif string
---@return integer|nil
local function squashfs_offset(sif)
  local f = io.open(sif, "rb")
  if not f then
    return nil
  end
  local head = f:read(1024 * 1024) or ""
  f:close()
  local at = head:find("hsqs", 1, true)
  return at and at - 1 or nil
end

---Shortest site-/dist-packages prefix of an image path (nested ones belong to it).
---@param path string
---@return string|nil
local function packages_dir(path)
  local site = path:match("^(.-/site%-packages)/")
  local dist = path:match("^(.-/dist%-packages)/")
  if site and dist then
    return #site < #dist and site or dist
  end
  return site or dist
end

---@param path string
---@return boolean
local function wanted(path)
  return path:match("%.pyi?$") ~= nil or path:match("%.pth$") ~= nil or path:match("/py%.typed$") ~= nil
end

---Extract `sif`'s Python sources into the cache as `kernel` (replacing any older copy).
---@param kernel string
---@param sif string
function M.sync(kernel, sif)
  if vim.fn.executable("unsquashfs") == 0 then
    return notify("`unsquashfs` not on PATH (squashfsTools).", vim.log.levels.ERROR)
  end
  sif = vim.fs.normalize(vim.fn.fnamemodify(sif, ":p"))
  local offset = squashfs_offset(sif)
  if not offset then
    return notify(("%s: no squashfs partition found (unreadable or not a SIF?)"):format(sif), vim.log.levels.ERROR)
  end
  local dest = vim.fs.joinpath(CACHE, kernel)
  local tmp = dest .. ".tmp"
  vim.fn.delete(tmp, "rf")
  vim.fn.mkdir(tmp, "p")
  local function fail(msg)
    vim.fn.delete(tmp, "rf")
    notify(msg, vim.log.levels.ERROR)
  end

  notify(("Listing %s…"):format(vim.fs.basename(sif)))
  vim.system({ "unsquashfs", "-o", tostring(offset), "-lls", sif }, { text = true }, vim.schedule_wrap(function(res)
    if res.code ~= 0 then
      return fail("unsquashfs -lls failed: " .. vim.trim(res.stderr or ""))
    end
    local files, dirs, versions = {}, {}, {}
    for line in res.stdout:gmatch("[^\n]+") do
      local path = line:sub(1, 1) == "-" and line:match("squashfs%-root/(.*)$")
      local dir = path and wanted(path) and packages_dir(path)
      if dir then
        files[#files + 1] = path
        dirs[dir] = true
        local minor = dir:match("python3%.(%d+)/")
        if minor then
          versions[minor] = (versions[minor] or 0) + 1
        end
      end
    end
    if #files == 0 then
      return fail(("%s has no site-/dist-packages Python files."):format(vim.fs.basename(sif)))
    end
    local minor, best = nil, 0
    for v, n in pairs(versions) do
      if n > best then
        minor, best = v, n
      end
    end
    -- Rough sys.path order: /usr/local before the distro's /usr/lib/python3*.
    local paths = vim.tbl_keys(dirs)
    table.sort(paths, function(a, b)
      local la, lb = a:find("/local/") ~= nil, b:find("/local/") ~= nil
      if la ~= lb then
        return la
      end
      return a < b
    end)
    local list = vim.fs.joinpath(tmp, "files.txt")
    vim.fn.writefile(files, list)

    notify(("Extracting %d Python files from %s…"):format(#files, vim.fs.basename(sif)))
    local root = vim.fs.joinpath(tmp, "root")
    vim.system(
      { "unsquashfs", "-q", "-n", "-f", "-o", tostring(offset), "-d", root, "-ef", list, sif },
      { text = true },
      vim.schedule_wrap(function(ex)
        if ex.code ~= 0 then
          return fail("unsquashfs failed: " .. vim.trim(ex.stderr or ex.stdout or ""))
        end
        vim.fn.delete(list)
        vim.fn.writefile({
          vim.json.encode({ sif = sif, python_version = minor and ("3." .. minor) or nil, paths = paths }),
        }, vim.fs.joinpath(tmp, "env.json"))
        vim.fn.delete(dest, "rf")
        local ok, err = vim.uv.fs_rename(tmp, dest)
        if not ok then
          return fail("rename failed: " .. tostring(err))
        end
        notify(("%s: Python %s, %d package dirs. Reattach the kernel (,I / ,k) to use it."):format(
          kernel,
          minor and ("3." .. minor) or "?",
          #paths
        ))
      end)
    )
  end))
end

---Kernels with a synced environment.
---@return string[]
function M.list()
  local names = {}
  if vim.fn.isdirectory(CACHE) == 0 then
    return names
  end
  for name, type in vim.fs.dir(CACHE) do
    if type == "directory" and read_meta(name) then
      names[#names + 1] = name
    end
  end
  return names
end

---Previously synced image of `kernel` (for a bare `:KernelEnvSync <kernel>`).
---@param kernel string
---@return string|nil
function M.sif(kernel)
  local meta = read_meta(kernel)
  return meta and meta.sif
end

return M
