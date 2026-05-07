return {
  {
    "selimacerbas/markdown-preview.nvim",
    dependencies = { "selimacerbas/live-server.nvim" },
    ft = "markdown",
    config = function()
      require("markdown_preview").setup({
        instance_mode = "takeover",
        port = 0,
        open_browser = true,
        debounce_ms = 300,
        mermaid_renderer = "rust", -- requires: cargo install mermaid-rs-renderer
        scroll_sync = true,
      })
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreview<cr>", ft = "markdown", desc = "Markdown preview" },
      { "<leader>mP", "<cmd>MarkdownPreviewStop<cr>", ft = "markdown", desc = "Markdown preview stop" },
      { "<leader>mr", "<cmd>MarkdownPreviewRefresh<cr>", ft = "markdown", desc = "Markdown preview refresh" },
    },
  },
}
