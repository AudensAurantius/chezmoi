return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(lang)
        return lang ~= "jsonc"
      end, opts.ensure_installed or {})
      vim.list_extend(opts.ensure_installed, { "sql" })
    end,
  },
}
