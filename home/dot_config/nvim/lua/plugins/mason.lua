-- Detect whether the nearest .csproj is SDK-style (<Project Sdk=) or old-style.
-- Returns the project root if the predicate matches, nil otherwise.
local util = require("lspconfig.util")

local function find_csproj_root(fname)
  return util.root_pattern("*.csproj")(fname)
    or util.root_pattern("*.sln")(fname)
    or util.root_pattern("omnisharp.json")(fname)
end

local function is_sdk_style_project(root)
  if not root then
    return nil
  end
  -- Find the first .csproj in the root directory
  local csproj = vim.fn.glob(root .. "/*.csproj")
  if csproj == "" then
    -- No .csproj at root (likely matched on .sln or omnisharp.json).
    -- Fall through to default omnisharp (net6.0) since it handles more cases.
    return true
  end
  -- If glob returned multiple, take the first
  csproj = vim.split(csproj, "\n")[1]
  local content = vim.fn.readfile(csproj, "", 5) -- first 5 lines is enough
  for _, line in ipairs(content) do
    if line:match("<Project%s+Sdk=") then
      return true
    end
  end
  return false
end

return {
  -- Dual OmniSharp setup:
  --   omnisharp (net6.0)  -> SDK-style projects (net6.0, net8.0, etc.)
  --   omnisharp_mono      -> old-style .NET Framework 4.7.2 projects
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- net6.0 build: SDK-style projects only
        omnisharp = {
          root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            local root = find_csproj_root(fname)
            if root and is_sdk_style_project(root) then
              on_dir(root)
            end
          end,
          enable_roslyn_analyzers = false,
          organize_imports_on_format = true,
          enable_import_completion = false,
        },
        -- Mono build: old-style .NET Framework projects only
        omnisharp_mono = {
          cmd = { "omnisharp-mono", "--languageserver", "--hostPID", tostring(vim.fn.getpid()) },
          root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            local root = find_csproj_root(fname)
            if root and not is_sdk_style_project(root) then
              -- Prefer solution root so $(SolutionDir) resolves correctly
              -- for cross-repo ProjectReferences that import nuget.targets
              local sln_root = util.root_pattern("*.sln")(fname)
              on_dir(sln_root or root)
            end
          end,
          enable_roslyn_analyzers = false,
          organize_imports_on_format = true,
          enable_import_completion = false,
        },
      },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      automatic_enable = {
        "omnisharp",
        "omnisharp_mono",
        "jedi_language_server",
        "bashls",
        "lua_ls",
        "jsonls",
        "stylua",
        "taplo",
        "texlab",
        "yamlls",
        "docker_language_server",
        "docker_compose_language_service",
      },
      ensure_installed = {
        "jedi_language_server",
        "bashls",
        "lua_ls",
        "jsonls",
        "stylua",
        "taplo",
        "texlab",
        "yamlls",
        "docker_language_server",
        "docker_compose_language_service",
      },
    },
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      "neovim/nvim-lspconfig",
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {

      -- a list of all tools you want to ensure are installed upon
      -- start
      ensure_installed = {

        -- you can do conditional installing
        {
          "gopls",
          condition = function()
            return vim.fn.executable("go") == 1
          end,
        },
        "editorconfig-checker",
        "ruff",
        "isort",
      },

      -- if set to true this will check each tool for updates. If updates
      -- are available the tool will be updated. This setting does not
      -- affect :MasonToolsUpdate or :MasonToolsInstall.
      -- Default: false
      auto_update = false,

      -- automatically install / update on startup. If set to false nothing
      -- will happen on startup. You can use :MasonToolsInstall or
      -- :MasonToolsUpdate to install tools and check for updates.
      -- Default: true
      run_on_start = false,

      -- set a delay (in ms) before the installation starts. This is only
      -- effective if run_on_start is set to true.
      -- e.g.: 5000 = 5 second delay, 10000 = 10 second delay, etc...
      -- Default: 0
      start_delay = 3000, -- 3 second delay

      -- Only attempt to install if 'debounce_hours' number of hours has
      -- elapsed since the last time Neovim was started. This stores a
      -- timestamp in a file named stdpath('data')/mason-tool-installer-debounce.
      -- This is only relevant when you are using 'run_on_start'. It has no
      -- effect when running manually via ':MasonToolsInstall' etc....
      -- Default: nil
      debounce_hours = 5, -- at least 5 hours between attempts to install/update

      -- By default all integrations are enabled. If you turn on an integration
      -- and you have the required module(s) installed this means you can use
      -- alternative names, supplied by the modules, for the thing that you want
      -- to install. If you turn off the integration (by setting it to false) you
      -- cannot use these alternative names. It also suppresses loading of those
      -- module(s) (assuming any are installed) which is sometimes wanted when
      -- doing lazy loading.
      integrations = {
        ["mason-lspconfig"] = true,
        -- ["mason-null-ls"] = true,
        -- ["mason-nvim-dap"] = true,
      },
    },
  },
}
