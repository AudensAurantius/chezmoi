return {
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        snippets = {
          search_paths = {
            vim.fn.stdpath("config") .. "/snippets",
            vim.fn.getcwd() .. "/.vscode",
          },
        },
      },
    },
  },
}
