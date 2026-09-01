[
  # --- Global ---
  {
    key = "<leader><leader>";
    mode = "n";
    action = "<cmd>Telescope find_files<cr>";
    desc = "Fuzzy find files";
  }

  # --- Buffers (<leader> b) ---
  {
    key = "<leader>bb";
    mode = "n";
    action = "<cmd>Telescope buffers<cr>";
    desc = "Switch buffer";
  }
  {
    key = "<leader>bn";
    mode = "n";
    action = "<cmd>bnext<cr>";
    desc = "Next buffer";
  }
  {
    key = "<leader>bp";
    mode = "n";
    action = "<cmd>bprevious<cr>";
    desc = "Previous buffer";
  }
  {
    key = "<leader>bs";
    mode = "n";
    action = "<cmd>w<cr>";
    desc = "Save buffer";
    nowait = true;
  }
  {
    key = "<leader>bS";
    mode = "n";
    action = "<cmd>wa<cr>";
    desc = "Save all buffers";
    nowait = true;
  }
  {
    key = "<leader>bk";
    mode = "n";
    # All this to have dashboard when closing all buffers
    action = "<cmd>bdelete<cr><cmd>lua vim.schedule(function() local b = vim.fn.getbufinfo({buflisted = 1}); if #b == 0 or (#b == 1 and b[1].name == '' and vim.bo[b[1].bufnr].buftype == '') then vim.cmd('Dashboard') end end)<cr>";
    desc = "Kill buffer";
  }
  {
    key = "<leader>bd";
    mode = [ "n" ];
    action = "<cmd>bdelete<cr><cmd>lua vim.schedule(function() local b = vim.fn.getbufinfo({buflisted = 1}); if #b == 0 or (#b == 1 and b[1].name == '' and vim.bo[b[1].bufnr].buftype == '') then vim.cmd('Dashboard') end end)<cr>";
    desc = "kill buffer";
  }
  {
    key = "<leader>br";
    mode = "n";
    action = "<cmd>e!<cr>";
    desc = "Reload buffer";
  }

  # --- Windows (<leader> w) ---
  {
    key = "<leader>wv";
    mode = "n";
    action = "<C-w>v";
    desc = "Split vertical";
  }
  {
    key = "<leader>ws";
    mode = "n";
    action = "<C-w>s";
    desc = "Split horizontal";
  }
  {
    key = "<leader>wd";
    mode = "n";
    action = "<C-w>q";
    desc = "Close window";
  }
  {
    key = "<leader>wo";
    mode = "n";
    action = "<C-w>o";
    desc = "Close other windows";
  }
  {
    key = "<leader>wh";
    mode = "n";
    action = "<C-w>h";
    desc = "Focus left";
  }
  {
    key = "<leader>wl";
    mode = "n";
    action = "<C-w>l";
    desc = "Focus right";
  }
  {
    key = "<leader>wj";
    mode = "n";
    action = "<C-w>j";
    desc = "Focus down";
  }
  {
    key = "<leader>wk";
    mode = "n";
    action = "<C-w>k";
    desc = "Focus up";
  }
  {
    key = "<leader>w=";
    mode = "n";
    action = "<C-w>=";
    desc = "Balance windows";
  }
  {
    key = "s";
    mode = [
      "n"
      "x"
    ];
    action = "<cmd>HopChar2<cr>";
    desc = "Hop to a 2-character sequence";
  }
  {
    key = "S";
    mode = [
      "n"
      "x"
    ];
    action = "<cmd>HopWord<cr>";
    desc = "Hop to a word";
  }

  # --- Files (<leader> f) ---
  {
    key = "<leader>fn";
    mode = "n";
    action = "<cmd>Neotree toggle reveal<cr>";
    desc = "Toggle Neo-tree";
  }
  {
    key = "<leader>fo";
    mode = "n";
    action = "<cmd>Oil<cr>";
    desc = "Open oil.nvim";
  }
]
