vim.cmd.colorscheme("oxocarbon")

require("config.appearance").setup()

-- dashboard-nvim: doom theme, header ported verbatim from appearance.nix
require("dashboard").setup({
  theme = "doom",
  hide = {
    statusline = true,
    tabline = true,
    winbar = true,
  },
  config = {
    header = {
      "",
      "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣶⣶⠿⠿⠿⣶⣦⣀⠀⠀⠀",
      "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡾⠛⠉⠀⠀⠀⠀⠀⠀⠉⠻⣧⡀⠀",
      " ⢠⣄⣀⣀⣀⣀⣀⣀⣴⠋⠀⠀⠀⠀⠀⣴⣆⠀⠀⠀⠀⠘⣿⡀",
      "⠀⠙⠻⣿⣟⠛⠛⠛⠋⠁⠀⠀⠀⠀⠀⠘⠿⠋⠀⠀⠀⠀⠀⣿⡇",
      "⠀⠀⠀⠀⠙⢷⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⡇",
      "⠀⠀⠀⠀⠀⠀⠘⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣽⠃",
      "⠀⠀⠀⠀⠀⠀⢰⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀",
      "⠀⠀⠀⠀⠀⠀⣾⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⡿⠀",
      "⠀⠀⠀⠀⠀⢸⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠃⠀",
      "⠀⠀⠀⠀⢀⡿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡟⠀⠀",
      "⠀⠀⠀⠀⣾⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⠇⠀⠀",
      "",
      "",
      "███▄▄▄▄      ▄████████  ▄██████▄   ▄█    █▄   ▄█    ▄▄▄▄███▄▄▄▄  ",
      "███▀▀▀██▄   ███    ███ ███    ███ ███    ███ ███  ▄██▀▀▀███▀▀▀██▄ ",
      "███   ███   ███    █▀  ███    ███ ███    ███ ███▌ ███   ███   ███ ",
      "███   ███  ▄███▄▄▄     ███    ███ ███    ███ ███▌ ███   ███   ███ ",
      "███   ███ ▀▀███▀▀▀     ███    ███ ███    ███ ███▌ ███   ███   ███ ",
      "███   ███   ███    █▄  ███    ███ ███    ███ ███  ███   ███   ███ ",
      "███   ███   ███    ███ ███    ███ ███    ███ ███  ███   ███   ███ ",
      " ▀█   █▀    ██████████  ▀██████▀   ▀██████▀  █▀    ▀█   ███   █▀  ",
      "",
      "",
      "",
      "",
    },
    vertical_center = true,
    footer = { "" },
    center = {
      {
        icon = " ",
        icon_hl = "DashboardIcon",
        desc = "Open project                           ",
        desc_hl = "DashboardDesc",
        key = "p",
        key_hl = "DashboardKey",
        key_format = " %s",
        action = "Telescope projects",
      },
      {
        icon = "󰈞 ",
        icon_hl = "DashboardIcon",
        desc = "Find file                              ",
        desc_hl = "DashboardDesc",
        key = "f",
        key_hl = "DashboardKey",
        key_format = " %s",
        action = "Telescope find_files",
      },
      {
        icon = " ",
        icon_hl = "DashboardIcon",
        desc = "Recently opened files                  ",
        desc_hl = "DashboardDesc",
        key = "r",
        key_hl = "DashboardKey",
        key_format = " %s",
        action = "Telescope oldfiles",
      },
      {
        icon = " ",
        icon_hl = "DashboardIcon",
        desc = "New file                               ",
        desc_hl = "DashboardDesc",
        key = "e",
        key_hl = "DashboardKey",
        key_format = " %s",
        action = "enew",
      },
    },
  },
})

require("nvim-web-devicons").setup()
require("scrollbar").setup({
  excluded_filetypes = {
    "prompt",
    "TelescopePrompt",
    "noice",
    "NvimTree",
    "neo-tree",
    "dashboard",
    "alpha",
    "notify",
    "Navbuddy",
    "fastaction_popup",
  },
})
require("nvim-cursorline").setup({
  -- Plugin defaults hide cursorline while moving and restore after timeout=1000.
  -- Disable that; use native instantaneous cursorline instead (matches nvf).
  cursorline = { enable = false, timeout = 0, number = false },
  cursorword = { enable = false },
})
require("cinnamon").setup()
require("fidget").setup()
require("highlight-undo").setup({
  -- Dashboard fills the buffer in one shot; without this, HighlightUndo
  -- paints the whole screen for `duration` ms on every open.
  ignored_filetypes = {
    "dashboard",
    "neo-tree",
    "fugitive",
    "TelescopePrompt",
    "mason",
    "lazy",
    "notify",
  },
})
require("blink-indent").setup()
require("ibl").setup({
  exclude = {
    filetypes = {
      "dashboard",
      "lspinfo",
      "checkhealth",
      "help",
      "man",
      "gitcommit",
      "TelescopePrompt",
      "TelescopeResults",
      "neo-tree",
      "",
    },
    buftypes = { "terminal", "nofile", "quickfix", "prompt" },
  },
})
require("noice").setup()
require("colorizer").setup({
  filetypes = { "*", "!dashboard" },
})
require("illuminate").configure({
  filetypes_denylist = {
    "dirvish",
    "fugitive",
    "help",
    "dashboard",
    "neo-tree",
    "notify",
    "NvimTree",
    "TelescopePrompt",
    "DressingInput",
  },
})

-- smartcolumn/colorcolumn removed: the mid-screen grey ruler bar.
-- (nvf enabled it; disable until wanted again.)

require("fastaction").setup({
  popup = { border = "rounded" },
})
require("notify").setup()
vim.notify = require("notify")

-- lualine + navic/navbuddy breadcrumbs
require("nvim-navic").setup()
require("nvim-navbuddy").setup({
  lsp = { auto_attach = true },
})

require("lualine").setup({
  sections = {
    lualine_c = {
      "filename",
      { function() return require("nvim-navic").get_location() end, cond = require("nvim-navic").is_available },
    },
  },
})
