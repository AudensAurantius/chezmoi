return {
  {
    "olivercederborg/poimandres.nvim",
    priority = 1000,
    opts = {
      bold_vert_split = false,
      dim_nc_background = false,
      disable_background = false,
      disable_float_background = false,
      disable_italics = false,

      highlight_groups = {
        -- Override highlight groups
      },
    },
    config = function(_, opts)
      require("poimandres").setup(opts)
    end,
  },
}
