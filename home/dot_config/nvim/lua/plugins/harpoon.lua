-- NOTE: LazyVim already includes harpoon with these default keybindings:
--   <leader>h  - Harpoon Quick Menu
--   <leader>H  - Add file to Harpoon
--   <leader>1-9 - Jump to Harpoon files 1-9
--
-- This config extends LazyVim's harpoon with additional keybindings.
-- Remove this file if you prefer LazyVim's defaults.

return {
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      settings = {
        save_on_toggle = true,
        sync_on_ui_close = true,
      },
    },
    keys = {
      {
        "<leader>Ha",
        function()
          require("harpoon"):list():add()
        end,
        desc = "Harpoon add file",
      },
      {
        "<leader>Hh",
        function()
          local harpoon = require("harpoon")
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end,
        desc = "Harpoon quick menu",
      },
      {
        "<leader>Hp",
        function()
          require("harpoon"):list():prev()
        end,
        desc = "Harpoon prev",
      },
      {
        "<leader>Hn",
        function()
          require("harpoon"):list():next()
        end,
        desc = "Harpoon next",
      },
    },
  },
}
