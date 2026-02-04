return {
  {
    "uloco/bluloco.nvim",
    priority = 1000,
    dependencies = { "rktjmp/lush.nvim" },
    opts = {
      style = "auto", -- "auto", "dark", or "light"
      transparent = false,
      italics = true,
      terminal = vim.fn.has("gui_running") == 1,
      guicursor = true,
    },
    -- Available colorschemes:
    -- bluloco
    -- bluloco-dark
    -- bluloco-light
  },
}
