-- Quarto (.qmd) literate buffers: filetype, python host, quarto-nvim + otter,
-- image.nvim, img-clip, and the molten-nvim loader (body: plugins.repl.molten).
-- This file is required eagerly; the plugins themselves load on ft=quarto.

--- Filetype (must run before the first buffer is detected, i.e. during init) ---
vim.filetype.add({
  extension = {
    qmd = "quarto",
  },
})

-- Quarto has no dedicated treesitter grammar; reuse markdown for render-markdown etc.
vim.treesitter.language.register("markdown", "quarto")

--- Python host for molten (remote plugin) ---
-- uv tool env `pynvim` (uv-managed CPython). Must be set before the host starts.
-- Install/refresh: uv tool install --python 3.12 --with jupyter_client --with pillow
--   --with cairosvg --with nbformat --with plotly --with kaleido --with pnglatex
--   --with pyperclip --with requests --with websocket-client pynvim
do
  local uv_tools = vim.env.UV_TOOL_DIR or vim.fn.expand("~/.local/share/uv/tools")
  local uv_host = uv_tools .. "/pynvim/bin/python"
  if vim.fn.executable(uv_host) == 1 then
    vim.g.python3_host_prog = uv_host
  end
end

--- Plugins ---
require("lze").load({
  {
    "quarto-nvim",
    ft = { "quarto" },
    dep_of = { "molten-nvim" },
    after = function()
      -- Code running uses molten (opt-in via ,i).
      require("quarto").setup({
        debug = false,
        closePreviewOnExit = true,
        lspFeatures = {
          enabled = true,
          languages = { "python" }, -- julia / multi-lang later
          chunks = "all",
          diagnostics = {
            enabled = true,
            triggers = { "BufWritePost" },
          },
          completion = {
            enabled = true,
          },
        },
        codeRunner = {
          enabled = true,
          default_method = "molten",
          never_run = { "yaml" },
        },
      })

      -- Activate otter/LSP features for the current quarto buffer.
      require("quarto").activate()
    end,
  },
  {
    "otter.nvim",
    dep_of = { "quarto-nvim" },
    cmd = { "OtterActivate", "OtterDeactivate" },
    after = function()
      require("otter").setup({})
    end,
  },
  {
    "image.nvim",
    ft = { "markdown", "norg", "vimwiki", "quarto" },
    dep_of = { "molten-nvim" },
    after = function()
      require("image").setup({
        backend = "kitty",
        processor = "magick_cli",
        max_width = 100,
        max_height = 12,
        max_height_window_percentage = math.huge,
        max_width_window_percentage = math.huge,
        window_overlap_clear_enabled = true,
        window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
        -- Document ![](…) images: cursor-gated so they don't fight Molten plots.
        integrations = {
          markdown = {
            enabled = true,
            filetypes = { "markdown", "vimwiki", "quarto" },
            only_render_image_at_cursor = true,
            only_render_image_at_cursor_mode = "popup",
          },
        },
      })
    end,
  },
  {
    "img-clip.nvim",
    cmd = { "PasteImage", "ImgClipDebug", "ImgClipConfig" },
    after = function()
      require("img-clip").setup({})
    end,
  },
  {
    "molten-nvim",
    -- molten-nvim has no plugin/ dir (rplugin + lua only), so packadd is free.
    -- Buffer-local ,-maps are registered by plugins.repl.molten on FileType.
    ft = { "quarto", "python" },
    -- Do NOT list Molten* here: they are remote-plugin commands defined by the
    -- rplugin manifest at startup; lze's cmd handler would delete them on load.
    cmd = { "MoltenLiterateInit" },
    after = function()
      require("plugins.repl.molten")
    end,
  },
})

vim.keymap.set("n", "<leader>lo", "<cmd>OtterActivate<CR>", { desc = "Activate LSP on Cursor Position [otter-nvim]" })
