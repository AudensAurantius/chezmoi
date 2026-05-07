return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(lang)
        return lang ~= "jsonc"
      end, opts.ensure_installed or {})
      vim.list_extend(opts.ensure_installed, {
        -- previously explicit
        "sql",
        "c_sharp",

        -- markup / docs
        "markdown",         -- block-level elements
        "markdown_inline",  -- inline elements (links, emphasis); needed for full highlighting
        "mermaid",
        "html",
        "vimdoc",

        -- scripting / shell
        "python",           -- one parser covers Python 2 and 3
        "bash",             -- covers sh and bash
        "zsh",              -- separate zsh parser (georgeharker/tree-sitter-zsh)
        "lua",
        "luadoc",

        -- systems / compiled
        "go",
        "rust",

        -- data / config
        "yaml",
        "json",
        "toml",
        "ini",              -- INI/conf files; no standalone "conf" parser exists

        -- build / task runners
        "make",             -- Makefiles; parser name is "make" not "makefile"
        "just",             -- Justfiles

        -- templates
        "gotmpl",           -- Go templates, including chezmoi .tmpl files

        -- vcs / containers
        "gitcommit",
        "gitignore",
        "dockerfile",

        -- misc
        "regex",
        "comment",          -- TODO/FIXME/NOTE highlights across languages
        "vim",
      })
    end,
  },
}
