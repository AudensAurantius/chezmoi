return {
  {
    "zenbones-theme/zenbones.nvim",
    priority = 1000,
    dependencies = { "rktjmp/lush.nvim" },
    config = function()
      -- Zenbones options (set before colorscheme)
      vim.g.zenbones_darken_comments = 45
      vim.g.zenbones_lighten_comments = 45
      vim.g.zenbones_lighten_cursor_line = 5
      vim.g.zenbones_darken_cursor_line = 5
      vim.g.zenbones_lighten_non_text = 20
      vim.g.zenbones_darken_non_text = 25
      vim.g.zenbones_lighten_line_nr = 25
      vim.g.zenbones_darken_line_nr = 25
      vim.g.zenbones_transparent_background = false
      vim.g.zenbones_italic_comments = true
      vim.g.zenbones_solid_vert_split = false
      vim.g.zenbones_solid_float_border = false
      vim.g.zenbones_solid_line_nr = false
      vim.g.zenbones_compat = false
    end,
    -- Available colorschemes:
    -- zenbones (light/dark)
    -- zenwritten (light/dark)
    -- neobones (light/dark)
    -- vimbones (light/dark)
    -- rosebones (light/dark)
    -- forestbones (light/dark)
    -- nordbones (light/dark)
    -- tokyobones (light/dark)
    -- seoulbones (light/dark)
    -- duckbones (light/dark)
    -- zenburned (dark only)
    -- kanagawabones (dark only)
    -- randombones (random!)
  },
}
