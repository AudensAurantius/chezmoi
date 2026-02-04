return {
  {
    "loctvl842/monokai-pro.nvim",
    priority = 1000,
    opts = {
      transparent_background = false,
      terminal_colors = true,
      devicons = true,

      -- Filter: "classic", "octagon", "pro", "machine", "ristretto", "spectrum"
      filter = "pro",

      -- Plugins with day/night cycle
      day_night = {
        enable = false,
        day_filter = "pro",
        night_filter = "spectrum",
      },

      -- Render more background colors for some plugins
      inc_search = "background",

      -- Background colors for certain plugins
      background_clear = {
        -- "toggleterm",
        -- "telescope",
        -- "which-key",
        -- "renamer",
        -- "notify",
        -- "nvim-tree",
        -- "neo-tree",
        -- "bufferline",
        "float_win",
      },

      plugins = {
        bufferline = {
          underline_selected = false,
          underline_visible = false,
        },
        indent_blankline = {
          context_highlight = "default", -- default, pro
          context_start_underline = false,
        },
      },

      override = function(c) end,
    },
  },
}
