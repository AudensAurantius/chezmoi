if true then
  return {}
end
return {
  "GCBallesteros/jupytext.nvim",
  config = true,
  -- Depending on your nvim distro or config you may need to make the loading not lazy
  lazy = false,
  opts = {
    style = "percent",
    output_extension = "auto", -- Default extension. Don't change unless you know what you are doing
    force_ft = nil, -- Default filetype. Don't change unless you know what you are doing
    custom_language_formatting = {},
  },
}
