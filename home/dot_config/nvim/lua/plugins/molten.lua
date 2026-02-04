return {
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    dependencies = { "3rd/image.nvim" },
    build = ":UpdateRemotePlugins",
    init = function()
      -- Output window settings
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_auto_open_output = false
      vim.g.molten_wrap_output = true
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_lines_off_by_1 = true
    end,
    keys = {
      { "<leader>mi", "<cmd>MoltenInit<cr>", desc = "Initialize Molten" },
      { "<leader>me", "<cmd>MoltenEvaluateOperator<cr>", desc = "Evaluate operator" },
      { "<leader>ml", "<cmd>MoltenEvaluateLine<cr>", desc = "Evaluate line" },
      { "<leader>mr", "<cmd>MoltenReevaluateCell<cr>", desc = "Re-evaluate cell" },
      { "<leader>md", "<cmd>MoltenDelete<cr>", desc = "Delete cell" },
      { "<leader>mo", "<cmd>MoltenShowOutput<cr>", desc = "Show output" },
      { "<leader>mh", "<cmd>MoltenHideOutput<cr>", desc = "Hide output" },
      { "<leader>mx", "<cmd>MoltenInterrupt<cr>", desc = "Interrupt kernel" },
      {
        "<leader>mv",
        ":<C-u>MoltenEvaluateVisual<cr>gv",
        mode = "v",
        desc = "Evaluate visual selection",
      },
    },
  },
}
