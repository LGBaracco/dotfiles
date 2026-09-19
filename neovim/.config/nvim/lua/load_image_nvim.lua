-- Shadow molten's load_image_nvim so virt-text plots sit below Molten's output
-- text instead of painting over it (benlubas/molten-nvim#346).
--
-- Molten attaches text virt_lines and image.nvim's padded image to the same
-- buffer line; image.nvim positions graphics from that line without accounting
-- for Molten's virt_lines. We set render_offset_top to the Molten virt_line
-- count (minus the one-line image placeholder) before rendering.

local ok, image = pcall(require, "image")
if not ok then
  vim.api.nvim_echo({ { "[Molten] `image.nvim` not found" } }, true, { err = true })
  return { image_api = {} }
end

local utils = require("image.utils")

local image_api = {}
local images = {}

local MOLTEN_NS = "molten-extmarks"

---Count Molten virt_lines on a buffer row (0-indexed).
---@param bufnr integer
---@param row integer
---@return integer
local function molten_virt_lines_at(bufnr, row)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return 0
  end
  local ns = vim.api.nvim_get_namespaces()[MOLTEN_NS]
  if not ns then
    return 0
  end
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, { row, 0 }, { row, -1 }, { details = true })
  local n = 0
  for _, mark in ipairs(marks) do
    local details = mark[4]
    if details and details.virt_lines then
      n = n + #details.virt_lines
    end
  end
  return n
end

image_api.from_file = function(path, opts)
  opts = opts or {}
  if opts.window and opts.window == vim.NIL then
    opts.window = nil
  end
  images[path] = image.from_file(path, opts)
  return path
end

image_api.render = function(identifier, geometry)
  geometry = geometry or {}
  local img = images[identifier]
  if not img then
    return
  end

  if img.buffer and not img.window then
    local wins = vim.fn.getbufinfo(img.buffer)[1].windows
    if #wins > 0 then
      img.window = wins[1]
    end
  end

  if not img.window or not vim.api.nvim_win_is_valid(img.window) then
    img.window = nil
  end

  if not img.window then
    return
  end

  -- Shift the plot below Molten's virt-text on the same anchor line.
  -- Last Molten virt_line is a one-char placeholder for the image itself.
  if img.buffer and img.with_virtual_padding and img.geometry and img.geometry.y then
    local molten_lines = molten_virt_lines_at(img.buffer, img.geometry.y)
    if molten_lines > 0 then
      img.render_offset_top = math.max(0, molten_lines - 1)
    end
  end

  img:render(geometry)
end

image_api.clear = function(identifier)
  local img = images[identifier]
  if img then
    img:clear()
  end
end

image_api.clear_all = function()
  for _, img in pairs(images) do
    img:clear()
  end
end

image_api.move = function(identifier, x, y)
  local img = images[identifier]
  if img then
    img:move(x, y)
  end
end

image_api.image_size = function(identifier)
  local img = images[identifier]
  local term_size = require("image.utils.term").get_size()
  local gopts = img.global_state.options
  local true_size = {
    width = math.min(img.image_width / term_size.cell_width, gopts.max_width or math.huge),
    height = math.min(img.image_height / term_size.cell_height, gopts.max_height or math.huge),
  }
  local width, height = utils.math.adjust_to_aspect_ratio(
    term_size,
    img.image_width,
    img.image_height,
    true_size.width,
    true_size.height
  )
  return { width = math.ceil(width), height = math.ceil(height) }
end

return { image_api = image_api }
