return {
  {
    "lervag/vimtex",
    lazy = false,
    init = function()
      -- Viewer settings
      vim.g.vimtex_view_method = "zathura" -- or "skim" on macOS, "sioyek", "mupdf"

      -- Compiler settings
      vim.g.vimtex_compiler_method = "latexmk"
      vim.g.vimtex_compiler_latexmk = {
        aux_dir = ".aux",
        out_dir = ".",
        callback = 1,
        continuous = 1,
        executable = "latexmk",
        hooks = {},
        options = {
          "-verbose",
          "-file-line-error",
          "-synctex=1",
          "-interaction=nonstopmode",
        },
      }

      -- Quickfix settings
      vim.g.vimtex_quickfix_mode = 0
      vim.g.vimtex_quickfix_open_on_warning = 0

      -- Mappings
      vim.g.vimtex_mappings_enabled = 1

      -- Fold settings
      vim.g.vimtex_fold_enabled = 0

      -- Format settings
      vim.g.vimtex_format_enabled = 1

      -- Indent settings
      vim.g.vimtex_indent_enabled = 1

      -- Syntax settings
      vim.g.vimtex_syntax_enabled = 1
      vim.g.vimtex_syntax_conceal = {
        accents = 1,
        ligatures = 1,
        cites = 1,
        fancy = 1,
        spacing = 1,
        greek = 1,
        math_bounds = 1,
        math_delimiters = 1,
        math_fracs = 1,
        math_super_sub = 1,
        math_symbols = 1,
        sections = 0,
        styles = 1,
      }

      -- TOC settings
      vim.g.vimtex_toc_config = {
        name = "TOC",
        layers = { "content", "todo", "include" },
        split_width = 25,
        todo_sorted = 0,
        show_help = 1,
        show_numbers = 1,
      }

      -- Disable imaps (use snippets instead)
      vim.g.vimtex_imaps_enabled = 0
    end,
    keys = {
      { "<leader>L", "", desc = "+LaTeX" },
      { "<leader>Lc", "<cmd>VimtexCompile<cr>", desc = "Compile LaTeX" },
      { "<leader>Lv", "<cmd>VimtexView<cr>", desc = "View PDF" },
      { "<leader>Lt", "<cmd>VimtexTocToggle<cr>", desc = "Toggle TOC" },
      { "<leader>Le", "<cmd>VimtexErrors<cr>", desc = "Show errors" },
      { "<leader>Lk", "<cmd>VimtexStop<cr>", desc = "Stop compilation" },
      { "<leader>LK", "<cmd>VimtexStopAll<cr>", desc = "Stop all" },
      { "<leader>Ll", "<cmd>VimtexLog<cr>", desc = "Show log" },
      { "<leader>LC", "<cmd>VimtexClean<cr>", desc = "Clean aux files" },
    },
    ft = { "tex", "latex", "bib" },
  },
}
