-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.cmd([[
  autocmd BufNewFile,BufRead *.cshtml set filetype=html.cshtml.razor
]])

-- Disable autoformat for Chezmoi template files (template syntax breaks formatters)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*.chezmoitmpl",
  callback = function(args)
    vim.b[args.buf].autoformat = false
  end,
})
