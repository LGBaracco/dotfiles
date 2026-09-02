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
require("fidget").setup()
require("noice").setup()
require("notify").setup()
vim.notify = require("notify")

require("nvim-navic").setup()
require("lualine").setup({
  sections = {
    lualine_c = {
      "filename",
      { function() return require("nvim-navic").get_location() end, cond = require("nvim-navic").is_available },
    },
  },
})
