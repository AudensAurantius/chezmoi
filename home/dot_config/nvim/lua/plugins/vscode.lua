return {
  {
    "Mofiqul/vscode.nvim",
    priority = 1000,
    opts = {
      -- Style: "dark" or "light"
      style = "dark",

      -- Enable transparent background
      transparent = false,

      -- Enable italic comments
      italic_comments = true,

      -- Underline `auto` and `loop` keywords
      underline_links = true,

      -- Disable nvim-tree background color
      disable_nvimtree_bg = true,

      -- Apply theme colors to terminal
      terminal_colors = true,

      -- Override colors (see colors.lua)
      color_overrides = {
        -- vscLineNumber = "#FFFFFF",
      },

      -- Override highlight groups (see ./lua/vscode/theme.lua)
      group_overrides = {
        -- Cursor = { fg = c.vscDarkBlue, bg = c.vscLightGreen, bold = true },
      },
    },
  },
}
