return {
  {
    "ellisonleao/glow.nvim",
    cmd = "Glow",
    ft = "markdown",
    opts = {
      width = 120,
      width_ratio = 0.85,
      height_ratio = 0.85,
      border = "rounded",
    },
    keys = {
      { "<leader>mg", "<cmd>Glow<cr>", ft = "markdown", desc = "Glow preview" },
    },
  },
}
