return {
  {
    "2giosangmitom/nightfall.nvim",
    priority = 1000,
    opts = {
      compile_path = vim.fn.stdpath("cache") .. "/nightfall",
      transparent = false,
      terminal_colors = true,
      dim_inactive = false,

      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = {},
        variables = {},
        numbers = {},
        conditionals = {},
        constants = {},
        operators = {},
        strings = {},
        types = {},
        booleans = {},
      },

      default_integrations = true,
      integrations = {
        lazy = { enabled = true },
        telescope = { enabled = true, style = "borderless" },
        illuminate = { enabled = true },
        treesitter = { enabled = true, context = true },
        lspconfig = { enabled = true },
        flash = { enabled = true },
      },
    },
    -- Available colorschemes:
    -- nightfall
    -- deeper-night
    -- maron
  },
}
