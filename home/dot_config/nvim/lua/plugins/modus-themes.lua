return {
  {
    "miikanissi/modus-themes.nvim",
    priority = 1000,
    opts = {
      -- Theme style: "auto", "modus_operandi", "modus_vivendi"
      -- "auto" follows vim.o.background
      style = "auto",

      -- Variant: "default", "tinted", "deuteranopia", "tritanopia"
      variant = "default",

      -- Saturation: "", "faint", or "warmer"
      -- Only applies to tinted variant
      saturation = "",

      -- Dims inactive windows
      dim_inactive = false,

      -- Transparent background
      transparent = false,

      -- Override styles
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = {},
        variables = {},
      },

      -- Callback for custom highlights
      on_colors = function(colors) end,
      on_highlights = function(highlights, colors) end,
    },
    -- Available colorschemes:
    -- modus_operandi (light)
    -- modus_vivendi (dark)
  },
}
