-- Disable auto-apply on save for Chezmoi files that feed run_onchange scripts.
-- The auto-watch runs `chezmoi apply --source-path`, which is a targeted apply
-- that burns the onchange hash without triggering the script.
return {
  {
    "xvzc/chezmoi.nvim",
    opts = {
      edit = {
        ignore_patterns = {
          "dot_wslconfig*",
        },
      },
    },
  },
}
