return {
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    priority = 1000,
    config = function()
      require("github-theme").setup({
        options = {
          compile_path = vim.fn.stdpath("cache") .. "/github-theme",
          compile_file_suffix = "_compiled",
          hide_end_of_buffer = true,
          hide_nc_statusline = true,
          transparent = false,
          terminal_colors = true,
          dim_inactive = false,
          module_default = true,

          styles = {
            comments = "italic",
            keywords = "bold",
            types = "italic,bold",
            functions = "NONE",
            variables = "NONE",
            conditionals = "NONE",
            constants = "NONE",
            numbers = "NONE",
            operators = "NONE",
            strings = "NONE",
          },

          inverse = {
            match_paren = false,
            visual = false,
            search = false,
          },

          darken = {
            floats = true,
            sidebars = {
              enable = true,
              list = {},
            },
          },

          modules = {},
        },

        palettes = {},
        specs = {},
        groups = {},
      })
    end,
    -- Available themes:
    -- github_dark
    -- github_dark_default
    -- github_dark_dimmed
    -- github_dark_high_contrast
    -- github_dark_colorblind
    -- github_dark_tritanopia
    -- github_light
    -- github_light_default
    -- github_light_high_contrast
    -- github_light_colorblind
    -- github_light_tritanopia
  },
}
