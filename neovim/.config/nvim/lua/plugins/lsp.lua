-- Completion --------------------------------------------------------------

require("blink.cmp").setup({
  keymap = {
    preset = "none",
    ["<Tab>"] = { "select_next", "fallback" },
    ["<S-Tab>"] = { "select_prev", "fallback" },
    ["<CR>"] = { "accept", "fallback" },
    ["<C-space>"] = { "show", "fallback" },
  },
  sources = {
    default = { "lazydev", "lsp", "path", "snippets", "buffer" },
    providers = {
      lazydev = {
        name = "LazyDev",
        module = "lazydev.integrations.blink",
        score_offset = 100,
      },
    },
  },
  snippets = { preset = "luasnip" },
})

-- Formatting ---------------------------------------------------------------

require("conform").setup({
  formatters_by_ft = {
    c = { "clang_format" },
    cpp = { "clang_format" },
    cmake = { "gersemi" },
    css = { "prettier" },
    dockerfile = { "dockerfmt" },
    fish = { "fish_indent" },
    java = { "astyle" },
    json = { "jsonfmt" },
    jsonc = { "prettier" },
    lua = { "stylua" },
    make = { "mbake" },
    markdown = { "deno_fmt" },
    nix = { "nixfmt" },
    plaintex = { "tex-fmt" },
    tex = { "tex-fmt" },
    python = { "ruff_format" },
    sh = { "shfmt" },
    toml = { "taplo" },
  },
  formatters = {
    gersemi = { command = "gersemi", args = { "-" }, stdin = true },
    dockerfmt = { command = "dockerfmt", stdin = true },
    astyle = { command = "astyle", args = { "--mode=java", "-n", "$FILENAME" }, stdin = false },
    jsonfmt = { command = "jsonfmt", args = { "--write", "-" }, stdin = true },
    mbake = { command = "mbake", args = { "format", "$FILENAME" }, stdin = false },
    ["tex-fmt"] = { command = "tex-fmt", args = { "--stdin" }, stdin = true },
    stylua = {
      prepend_args = { "--indent-type", "Spaces", "--indent-width", "4" },
    },
  },
  format_on_save = function(bufnr)
    if not vim.g.formatsave or vim.b[bufnr].disableFormatSave then
      return
    end
    return { timeout_ms = 500, lsp_format = "fallback" }
  end,
})

-- nvim-lint: skipped for now, most languages here are covered by LSP
-- diagnostics already; add `require("lint")` setup here if a linter is
-- needed that isn't provided by its LSP server.

-- Diagnostics display -------------------------------------------------------
-- Default Neovim keeps virtual_text / virtual_lines off; modes below make the
-- gutter + in-buffer cues louder without stacking CursorHold floats on top.

local DiagSev = vim.diagnostic.severity

local diagnostic_signs = {
  text = {
    [DiagSev.ERROR] = "󰅚",
    [DiagSev.WARN] = "󰀪",
    [DiagSev.INFO] = "󰋽",
    [DiagSev.HINT] = "󰌶",
  },
}

local diagnostic_base = {
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = true,
    header = "",
    prefix = "",
  },
  -- Signs stay at HINT so harper/prose still mark the gutter; underline and
  -- virtual cues start at WARN so code errors read louder than hints.
  signs = vim.tbl_extend("force", { severity = { min = DiagSev.HINT } }, diagnostic_signs),
  underline = { severity = { min = DiagSev.WARN } },
}

-- Inline cues show the first paragraph only: ruff appends "\n\nhelp: …", which
-- virtual_lines would render as an extra line. The float keeps the full message.
---@param d vim.Diagnostic
local function first_paragraph(d)
  return (d.message:gsub("\n%s*\n.*", ""))
end

local diagnostic_modes = {
  quiet = {
    virtual_text = false,
    virtual_lines = false,
  },
  focus = {
    virtual_text = false,
    virtual_lines = {
      current_line = true,
      severity = { min = DiagSev.WARN },
      format = first_paragraph,
    },
  },
  loud = {
    virtual_text = {
      spacing = 2,
      source = "if_many",
      prefix = "●",
      severity = { min = DiagSev.WARN },
      format = first_paragraph,
    },
    virtual_lines = false,
  },
}

local diagnostic_mode_order = { "quiet", "focus", "loud" }
vim.g.diagnostic_display_mode = "focus"

local function apply_diagnostic_mode(mode)
  local opts = diagnostic_modes[mode]
  if not opts then
    return
  end
  vim.g.diagnostic_display_mode = mode
  vim.diagnostic.config(vim.tbl_deep_extend("force", diagnostic_base, opts))
end

apply_diagnostic_mode(vim.g.diagnostic_display_mode)

local function cycle_diagnostic_mode()
  local current = vim.g.diagnostic_display_mode or "focus"
  local next_mode = diagnostic_mode_order[1]
  for i, name in ipairs(diagnostic_mode_order) do
    if name == current then
      next_mode = diagnostic_mode_order[(i % #diagnostic_mode_order) + 1]
      break
    end
  end
  apply_diagnostic_mode(next_mode)
  vim.notify("Diagnostics: " .. next_mode, vim.log.levels.INFO, { title = "diagnostic" })
end

-- Misc LSP UI ---------------------------------------------------------------

-- Only cursor-local fixes/refactors: ruff offers source.fixAll/organizeImports
-- on every line, which would keep the bulb permanently lit.
require("nvim-lightbulb").setup({
  autocmd = { enabled = true },
  action_kinds = { "quickfix", "refactor" },
  -- nil offers refactor.rewrite (flatten/pack attrset, indent string) on
  -- nearly every Nix binding; only light the bulb for its quickfixes.
  filter = function(client_name, result)
    if client_name == "nil_ls" then
      return result.kind ~= nil and vim.startswith(result.kind, "quickfix")
    end
    return true
  end,
})

-- Treesitter (nvim-treesitter main rewrite for Nvim 0.12+)
-- Parsers come from Nix (`withAllGrammars`), off Nix from :PackSync (pack.json
-- `treesitter`, per profile); highlighting/indent use core APIs.
require("nvim-treesitter").setup({})
vim.api.nvim_create_autocmd("FileType", {
  desc = "Enable treesitter highlight + indent",
  callback = function(event)
    if vim.bo[event.buf].filetype == "dashboard" then
      return
    end
    local ok = pcall(vim.treesitter.start, event.buf)
    if ok then
      vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
require("treesitter-context").setup({})
require("nvim-ts-autotag").setup({})
-- Text objects (main branch: no keymaps in setup; maps live where they are used,
-- e.g. @code_cell in plugins.repl.molten).
require("nvim-treesitter-textobjects").setup({
  select = {
    lookahead = true,
    selection_modes = {
      ["@code_cell.outer"] = "V",
      ["@code_cell.inner"] = "V",
    },
  },
})

-- LSP servers -----------------------------------------------------------------
-- Names match nvim-lspconfig's lsp/<name>.lua so its cmd/root_markers/settings
-- merge in; blocks below only hold overrides. cmd entries are bare PATH binary
-- names (no /nix/store paths). Most come from pack.json `tools`: the nix wrapper
-- PATH (module.nix runtimePkgs), off Nix mason (config.tools) or the host. Python
-- is the exception: `ty` and `ruff` (LSP + conform) are uv tools on ~/.local/bin —
-- never in the wrapper or mason.
-- LspAttach keymaps live in config.keymaps; this wires up navic breadcrumbs,
-- inlay hints and completion capabilities on attach.

local capabilities = vim.lsp.protocol.make_client_capabilities()
local has_blink, blink = pcall(require, "blink.cmp")
if has_blink then
  capabilities = blink.get_lsp_capabilities(capabilities)
end

vim.lsp.config("*", {
  capabilities = capabilities,
  on_attach = function(client, bufnr)
    local has_navic, navic = pcall(require, "nvim-navic")
    if has_navic and client:supports_method("textDocument/documentSymbol") then
      navic.attach(client, bufnr)
    end
    if client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    end
    -- ty owns hover in Python; ruff's only documents noqa rule codes.
    if client.name == "ruff" or client.name == "ruff_otter" then
      client.server_capabilities.hoverProvider = false
    end
  end,
})

vim.lsp.config("clangd", {
  cmd = { "clangd" },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
})

vim.lsp.config("fennel_ls", {
  cmd = { "fennel-ls" },
  filetypes = { "fennel" },
})

-- Prose only: lspconfig's harper_ls also spell-checks comments in ~28 code filetypes.
vim.lsp.config("harper_ls", {
  filetypes = { "markdown", "gitcommit", "text" },
})

-- LanguageServer.jl is a Julia package, not a PATH binary. Launch via julia.
-- --project=@v#.# loads the default versioned env (where LanguageServer lives).
vim.lsp.config("julials", {
  cmd = {
    "julia",
    "--startup-file=no",
    "--history-file=no",
    "--project=@v#.#",
    "-e",
    [[
      using LanguageServer
      @info "Running language server" VERSION pwd()
      LanguageServer.runserver()
    ]],
  },
  filetypes = { "julia" },
  root_markers = { "Project.toml", "JuliaProject.toml" },
})

vim.lsp.config("lemminx", {
  cmd = { "lemminx" },
  filetypes = { "xml" },
})

-- Neovim API types for lua_ls (must run before the server attaches).
require("lazydev").setup({
  library = {
    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
  },
})

-- Client name must be "lua_ls" so lazydev can inject Neovim types.
vim.lsp.config("lua_ls", {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
      hint = { enable = true },
    },
  },
})

vim.lsp.config("marksman", {
  cmd = { "marksman", "server" },
  filetypes = { "markdown" },
})

vim.lsp.config("neocmakelsp", {
  cmd = { "neocmakelsp", "--stdio" },
  filetypes = { "cmake" },
})

vim.lsp.config("qmlls", {
  cmd = { "qmlls" },
  filetypes = { "qml" },
})

vim.lsp.config("sqls", {
  cmd = { "sqls" },
  filetypes = { "sql" },
})

vim.lsp.config("superhtml", {
  cmd = { "superhtml", "lsp" },
  filetypes = { "html" },
})

vim.lsp.config("taplo", {
  cmd = { "taplo", "lsp", "stdio" },
  filetypes = { "toml" },
})

vim.lsp.config("texlab", {
  cmd = { "texlab" },
  filetypes = { "tex", "plaintex", "bib" },
  settings = {
    texlab = {
      -- VimTeX owns build + SyncTeX; texlab is completions/diagnostics only.
      build = { onSave = false },
      forwardSearch = { executable = "", args = {} },
    },
  },
})

vim.lsp.config("ty", {
  cmd = { "ty", "server" },
  filetypes = { "python" },
})

-- Ruff = lint/fixes/organize imports, ty = types/names/hover/inlay hints.
-- F821 (undefined name) duplicates ty's unresolved-reference. filesystemFirst:
-- a project's own ruff config wins over these editor settings.
local ruff_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" }

---@param otter boolean attach only to otter's hidden `<main>.otter.py` buffers, or never
local function ruff_root_dir(otter)
  return function(bufnr, on_dir)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if (name:match("%.otter%.py$") ~= nil) == otter then
      on_dir(vim.fs.root(bufnr, ruff_markers) or vim.fs.dirname(name))
    end
  end
end

vim.lsp.config("ruff", {
  root_dir = ruff_root_dir(false),
  init_options = {
    settings = {
      configurationPreference = "filesystemFirst",
      lint = { ignore = { "F821" } },
    },
  },
})

-- Quarto/notebook cells (otter concatenates them into one .py): notebook idioms.
vim.lsp.config("ruff_otter", {
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  root_dir = ruff_root_dir(true),
  init_options = {
    settings = {
      configurationPreference = "filesystemFirst",
      lint = {
        ignore = {
          "F821", -- undefined name: ty
          "E402", -- imports in later cells
          "E703", -- trailing `;` suppresses cell output
          "F811", -- redefinition when cells are re-run / re-imported
          "F704", -- top-level await
        },
      },
    },
  },
})

vim.lsp.enable({
  "bashls",
  "clangd",
  "cssls",
  "docker_language_server",
  "fennel_ls",
  "fish_lsp",
  "harper_ls",
  "jsonls",
  "julials",
  "lemminx",
  "lua_ls",
  "marksman",
  "neocmakelsp",
  "nil_ls",
  "qmlls",
  "ruff",
  "ruff_otter",
  "sqls",
  "superhtml",
  "taplo",
  "texlab",
  "ty",
})

-- Deferred LSP UI extras ------------------------------------------------------
-- fastaction is required from the LspAttach <leader>la map (config.keymaps).

require("lze").load({
  {
    "fastaction.nvim",
    event = "DeferredUIEnter",
    on_require = "fastaction",
    after = function()
      require("fastaction").setup({
        popup = { border = "rounded" },
      })
    end,
  },
  {
    "nvim-docs-view",
    cmd = { "DocsViewToggle", "DocsViewUpdate" },
    after = function()
      require("docs-view").setup({})
    end,
  },
  {
    "trouble.nvim",
    cmd = { "Trouble" },
    after = function()
      require("trouble").setup({})
    end,
  },
})

local map = vim.keymap.set
map("n", "<leader>lvt", "<cmd>DocsViewToggle<CR>", { desc = "Open or close the docs view panel" })
map("n", "<leader>lvu", "<cmd>DocsViewUpdate<CR>", { desc = "Manually update the docs view panel" })
map("n", "<leader>lwd", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Workspace diagnostics [trouble]" })
map("n", "<leader>ld", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", { desc = "Document diagnostics [trouble]" })
map("n", "<leader>lr", "<cmd>Trouble lsp_references toggle<CR>", { desc = "LSP References [trouble]" })
map("n", "<leader>ltd", cycle_diagnostic_mode, { desc = "Cycle diagnostic display (quiet/focus/loud)" })
