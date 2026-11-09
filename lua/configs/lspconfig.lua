require("nvchad.configs.lspconfig").defaults()

local servers = {
  "html",
  "cssls",
  "ts_ls",
  "gopls",
  "sqlls",
  "jsonls",
  "dockerls",
  "clangd",
  "rust_analyzer",
}

vim.lsp.enable(servers)
