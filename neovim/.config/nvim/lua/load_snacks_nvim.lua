-- Shadow of molten-nvim's lua/load_snacks_nvim.lua (wins by rtp order: ~/.config/nvim
-- before packpath). Same API for the Python side; three upstream bugs fixed:
--
-- 1. Upstream keys images by *file path* and ignores the identifier Molten passes
--    (`virt-<path>` vs `<path>`). With molten_image_location = "both" the virt and
--    float images share one path, so the float's from_file overwrote the virt entry
--    and its snacks placement could never be closed (plots survived
--    MoltenHideOutput / MoltenDelete / MoltenRestart! / MoltenDeinit).
-- 2. clear_all() passed the entry table instead of its key to clear(), so it never
--    closed anything.
-- 3. ImageOutputChunk.place() stores only one img_identifier. With location=both,
--    float place() overwrites the virt id, so remove_image on clear/restart only
--    closes one placement. clear() also closes the virt-/non-virt sibling.
--
-- Drop this file once https://github.com/benlubas/molten-nvim fixes load_snacks_nvim.lua
-- and stores both identifiers when image_location is "both".

local ok, snacks = pcall(require, "snacks")
if not ok then
  vim.api.nvim_echo({ { "[Molten] `snacks.nvim` not found" } }, true, { err = true })
  return
end

local snacks_api = {}
---@type table<string, {path: string, buffer: integer, opts: table, placement: any}>
local images = {}

local function doc_opt(key, default)
  local doc = snacks.config.image and snacks.config.image.doc
  return doc and doc[key] or default
end

---@param id string
local function clear_one(id)
  local img = images[id]
  if not img then
    return
  end
  if img.placement then
    img.placement:close()
  end
  images[id] = nil
end

--- Molten uses `virt-<path>` for inline and `<path>` for the float; with
--- image_location=both only the last place() id is kept on the chunk.
local function sibling_id(identifier)
  if type(identifier) ~= "string" then
    return nil
  end
  if identifier:sub(1, 5) == "virt-" then
    return identifier:sub(6)
  end
  return "virt-" .. identifier
end

---@param path string image file
---@param opts {id: string, buffer: integer, x: integer, y: integer}
---@return string identifier
snacks_api.from_file = function(path, opts)
  local id = opts.id or path
  clear_one(id)
  images[id] = {
    path = path,
    buffer = opts.buffer,
    placement = nil,
    opts = {
      inline = true,
      pos = { opts.y, opts.x },
      max_width = doc_opt("max_width", 80),
      max_height = doc_opt("max_height", 40),
    },
  }
  return id
end

snacks_api.render = function(identifier)
  local img = images[identifier]
  if not img then
    return
  end
  if img.placement == nil then
    img.placement = Snacks.image.placement.new(img.buffer, img.path, img.opts)
  end
end

snacks_api.clear = function(identifier)
  clear_one(identifier)
  local sib = sibling_id(identifier)
  if sib then
    clear_one(sib)
  end
end

snacks_api.clear_all = function()
  for _, id in ipairs(vim.tbl_keys(images)) do
    clear_one(id)
  end
end

--- Estimated cell size (actual size is only known after render()).
snacks_api.image_size = function(identifier)
  local img = images[identifier]
  if not img then
    return { width = 0, height = 0 }
  end
  return snacks.image.util.fit(img.path, { width = img.opts.max_width, height = img.opts.max_height })
end

return { snacks_api = snacks_api }
