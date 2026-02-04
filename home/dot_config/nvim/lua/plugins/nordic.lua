return {
  {
    "AlexvZyl/nordic.nvim",
    priority = 1000,
    opts = {
      -- Theme style: "flat" or "classic"
      theme = "default",

      -- Enable bold keywords
      bold_keywords = false,

      -- Enable italic comments
      italic_comments = true,

      -- Transparent background
      transparent = {
        bg = false,
        float = false,
      },

      -- Brighter float borders
      bright_border = false,

      -- Reduced blue in the editor
      reduced_blue = true,

      -- Swap dark and light backgrounds
      swap_backgrounds = false,

      -- Cursorline options
      cursorline = {
        bold = false,
        bold_number = true,
        theme = "dark",
        blend = 0.85,
      },

      -- Noice style: "classic", "flat", or false
      noice = {
        style = "classic",
      },

      -- Telescope style: "classic" or "flat"
      telescope = {
        style = "flat",
      },

      -- Leap style
      leap = {
        dim_backdrop = false,
      },

      -- ts_context style
      ts_context = {
        dark_background = true,
      },

      -- Override palette
      on_palette = function(palette) end,

      -- Custom highlight groups
      after_palette = function(palette) end,
      on_highlight = function(highlights, palette) end,
    },
  },
}
