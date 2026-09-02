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
    default = { "lsp", "path", "snippets", "buffer" },
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
    jsonc = { "jsonfmt" },
    lua = { "stylua" },
    make = { "mbake" },
    markdown = { "deno_fmt" },
    nix = { "nixfmt" },
    plaintex = { "tex-fmt" },
    tex = { "tex-fmt" },
    python = { "ruff_format" },
    sh = { "shfmt" },
    sql = { "sqlfluff" },
    toml = { "taplo" },
  },
  formatters = {
    gersemi = { command = "gersemi", args = { "-" }, stdin = true },
    dockerfmt = { command = "dockerfmt", stdin = true },
    astyle = { command = "astyle", args = { "--mode=java", "-n", "$FILENAME" }, stdin = false },
    jsonfmt = { command = "jsonfmt", args = { "--write", "-" }, stdin = true },
    mbake = { command = "mbake", args = { "format", "$FILENAME" }, stdin = false },
    ["tex-fmt"] = { command = "tex-fmt", args = { "--stdin" }, stdin = true },
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

-- Misc LSP UI ---------------------------------------------------------------

require("nvim-lightbulb").setup({ autocmd = { enabled = true } })
require("otter").setup({})
require("docs-view").setup({})
require("trouble").setup({})

-- Treesitter (nvim-treesitter main rewrite for Nvim 0.12+)
-- Parsers come from Nix (`withAllGrammars`); highlighting/indent use core APIs.
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

-- LSP servers -----------------------------------------------------------------
-- cmd entries are bare PATH binary names (no /nix/store paths); Nix puts the
-- right packages on PATH via the wrapper module.
-- LspAttach keymaps live in config.keymaps-nvf; this only wires up
-- navic breadcrumbs and completion capabilities on attach.

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
  end,
})

vim.lsp.config("bash-language-server", {
  cmd = { "bash-language-server", "start" },
  filetypes = { "bash", "sh" },
})

vim.lsp.config("clangd", {
  cmd = { "clangd" },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
})

vim.lsp.config("docker-language-server", {
  cmd = { "docker-language-server", "start", "--stdio" },
  filetypes = { "dockerfile" },
})

vim.lsp.config("fennel_ls", {
  cmd = { "fennel-ls" },
  filetypes = { "fennel" },
})

vim.lsp.config("fish-lsp", {
  cmd = { "fish-lsp", "start" },
  filetypes = { "fish" },
})

vim.lsp.config("harper", {
  cmd = { "harper-ls", "--stdio" },
  filetypes = { "markdown", "gitcommit", "text" },
})

vim.lsp.config("jdt-language-server", {
  cmd = { "jdt-language-server" },
  filetypes = { "java" },
})

vim.lsp.config("julia-languageserver", {
  cmd = { "julia-languageserver" },
  filetypes = { "julia" },
})

vim.lsp.config("lemminx", {
  cmd = { "lemminx" },
  filetypes = { "xml" },
})

vim.lsp.config("lua-language-server", {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  settings = {
    Lua = {
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
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

vim.lsp.config("nil", {
  cmd = { "nil" },
  filetypes = { "nix" },
})

vim.lsp.config("qmlls", {
  cmd = { "qmlls" },
  filetypes = { "qml" },
})

vim.lsp.config("r-languageserver", {
  cmd = { "r-languageserver" },
  filetypes = { "r", "rmd" },
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
})

vim.lsp.config("ty", {
  cmd = { "ty", "server" },
  filetypes = { "python" },
})

vim.lsp.config("vscode-css-language-server", {
  cmd = { "vscode-css-language-server", "--stdio" },
  filetypes = { "css", "scss", "less" },
})

vim.lsp.config("vscode-json-language-server", {
  cmd = { "vscode-json-language-server", "--stdio" },
  filetypes = { "json", "jsonc" },
})

vim.lsp.enable({
  "bash-language-server",
  "clangd",
  "docker-language-server",
  "fennel_ls",
  "fish-lsp",
  "harper",
  "jdt-language-server",
  "julia-languageserver",
  "lemminx",
  "lua-language-server",
  "marksman",
  "neocmakelsp",
  "nil",
  "qmlls",
  "r-languageserver",
  "sqls",
  "superhtml",
  "taplo",
  "texlab",
  "ty",
  "vscode-css-language-server",
  "vscode-json-language-server",
})
