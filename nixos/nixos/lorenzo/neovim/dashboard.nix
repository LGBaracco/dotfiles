{
  dashboard = {
    dashboard-nvim = {
      enable = true;
      setupOpts = {
        theme = "doom";
        hide = {
          statusline = true;
          tabline = true;
          winbar = true;
        };
        config = {
          header = [
            ""
            "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣶⣶⠿⠿⠿⣶⣦⣀⠀⠀⠀"
            "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡾⠛⠉⠀⠀⠀⠀⠀⠀⠉⠻⣧⡀⠀"
            "⢠⣄⣀⣀⣀⣀⣀⣀⣴⠋⠀⠀⠀⠀⠀⣴⣆⠀⠀⠀⠀⠘⣿⡀"
            "⠀⠙⠻⣿⣟⠛⠛⠛⠋⠁⠀⠀⠀⠀⠀⠘⠿⠋⠀⠀⠀⠀⠀⣿⡇"
            "⠀⠀⠀⠀⠙⢷⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⡇"
            "⠀⠀⠀⠀⠀⠀⠘⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣽⠃"
            "⠀⠀⠀⠀⠀⠀⢰⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀"
            "⠀⠀⠀⠀⠀⠀⣾⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⡿⠀"
            "⠀⠀⠀⠀⠀⢸⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠃⠀"
            "⠀⠀⠀⠀⢀⡿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡟⠀⠀"
            "⠀⠀⠀⠀⣾⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⠇⠀⠀"
            ""
            ""

            "███▄▄▄▄      ▄████████  ▄██████▄   ▄█    █▄   ▄█    ▄▄▄▄███▄▄▄▄  "
            "███▀▀▀██▄   ███    ███ ███    ███ ███    ███ ███  ▄██▀▀▀███▀▀▀██▄ "
            "███   ███   ███    █▀  ███    ███ ███    ███ ███▌ ███   ███   ███ "
            "███   ███  ▄███▄▄▄     ███    ███ ███    ███ ███▌ ███   ███   ███ "
            "███   ███ ▀▀███▀▀▀     ███    ███ ███    ███ ███▌ ███   ███   ███ "
            "███   ███   ███    █▄  ███    ███ ███    ███ ███  ███   ███   ███ "
            "███   ███   ███    ███ ███    ███ ███    ███ ███  ███   ███   ███ "
            " ▀█   █▀    ██████████  ▀██████▀   ▀██████▀  █▀    ▀█   ███   █▀  "
            ""
            ""
            ""
            ""
          ];
          vertical_center = true;
          footer = [ "" ];
          center = [
            {
              icon = " ";
              icon_hl = "DashboardIcon";
              desc = "Open project           ";
              desc_hl = "DashboardDesc";
              key = "p";
              key_hl = "DashboardKey";
              key_format = " %s";
              action = "Telescope projects";
            }
            {
              icon = "󰈞 ";
              icon_hl = "DashboardIcon";
              desc = "Find file              ";
              desc_hl = "DashboardDesc";
              key = "f";
              key_hl = "DashboardKey";
              key_format = " %s";
              action = "Telescope find_files";
            }
            {
              icon = " ";
              icon_hl = "DashboardIcon";
              desc = "Recently opened files  ";
              desc_hl = "DashboardDesc";
              key = "r";
              key_hl = "DashboardKey";
              key_format = " %s";
              action = "Telescope oldfiles";
            }
            {
              icon = " ";
              icon_hl = "DashboardIcon";
              desc = "New file               ";
              desc_hl = "DashboardDesc";
              key = "e";
              key_hl = "DashboardKey";
              key_format = " %s";
              action = "enew";
            }
          ];
        };
      };
    };
  };

  themeExtraConfig = ''
    local header_ns = vim.api.nvim_create_namespace("lorenzo_dashboard_header")

    local function set_dashboard_hl()
      -- Provides theme-based colors for the dashboard
      vim.api.nvim_set_hl(0, "DashboardHeader", { fg = "#4589ff", bg = "NONE" })
      vim.api.nvim_set_hl(0, "DashboardHeaderArt", { fg = "#4589ff", bg = "NONE" })
      vim.api.nvim_set_hl(0, "DashboardKey", { fg = "#be95ff", bg = "NONE" })
      vim.api.nvim_set_hl(0, "DashboardIcon", { fg = "#42be65", bg = "NONE" })
      vim.api.nvim_set_hl(0, "DashboardDesc", { fg = "#f2f4f8", bg = "NONE" })
      vim.api.nvim_set_hl(0, "DashboardFooter", { fg = "#878d96", bg = "NONE" })
    end

    local function is_block_art_line(line)
      -- Make sure everything is loaded in the right order
      return line:find("█", 1, true) ~= nil and line:find("▄", 1, true) ~= nil
    end

    local function apply_header_art_highlights(buf)
      vim.api.nvim_buf_clear_namespace(buf, header_ns, 0, -1)

      for i = 0, vim.api.nvim_buf_line_count(buf) - 1 do
        local line = vim.api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
        if line:find("⠀", 1, true) then
          vim.api.nvim_buf_add_highlight(buf, header_ns, "DashboardHeaderArt", i, 0, -1)
        elseif is_block_art_line(line) then
          vim.api.nvim_buf_add_highlight(buf, header_ns, "DashboardHeader", i, 0, -1)
        end
      end
    end

    set_dashboard_hl()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = set_dashboard_hl })

    vim.api.nvim_create_autocmd("User", {
      pattern = "DashboardLoaded",
      callback = function()
        apply_header_art_highlights(vim.api.nvim_get_current_buf())
      end,
    })
  '';
}
