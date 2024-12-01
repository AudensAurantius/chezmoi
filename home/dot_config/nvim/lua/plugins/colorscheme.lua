return {
	-- add gruvbox
	{ "lunarvim/darkplus.nvim", priority = 1000 },
	{ "Mofiqul/dracula.nvim", priority = 1000 },
	{ "shaunsingh/nord.nvim", priority = 1000 },
	{ "ishan9299/nvim-solarized-lua", priority = 1000 },
	{ "sainnhe/sonokai", priority = 1000 },
	{ "sainnhe/edge", priority = 1000 },
	{ "bluz71/vim-moonfly-colors", priority = 1000 },
	{ "wuelnerdotexe/vim-enfocado", priority = 1000 },
	{
		"oxfist/night-owl.nvim",
		lazy = false, -- make sure we load this during startup if it is your main colorscheme
		priority = 1000, -- make sure to load this before all the other start plugins
		config = function()
			-- load the colorscheme here
			require("night-owl").setup({
				-- These are the default settings
				bold = true,
				italics = true,
				underline = true,
				undercurl = true,
				transparent_background = false,
			})
		end,
	},
	{
		"maxmx03/fluoromachine.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			local fm = require("fluoromachine")

			fm.setup({
				theme = "fluoromachine",
				brightness = 0.05,
				glow = true,
				transparent = false,
				styles = {
					comments = {},
					functions = {},
					variables = {},
					numbers = {},
					constants = {},
					parameters = {},
					keywords = {},
					types = {},
				},
				colors = {},
				overrides = {},
				plugins = {
					bufferline = true,
					cmp = true,
					dashboard = true,
					editor = true,
					gitsign = true,
					hop = true,
					ibl = true,
					illuminate = true,
					lazy = true,
					minicursor = true,
					ministarter = true,
					minitabline = true,
					ministatusline = true,
					navic = true,
					neogit = true,
					neotree = true,
					noice = true,
					notify = true,
					lspconfig = true,
					syntax = true,
					telescope = true,
					treesitter = true,
					tree = true,
					wk = true,
				},
			})
		end,
	},
	{
		"marko-cerovac/material.nvim",
		priority = 1000,
		opts = {

			contrast = {
				terminal = false, -- Enable contrast for the built-in terminal
				sidebars = false, -- Enable contrast for sidebar-like windows ( for example Nvim-Tree )
				floating_windows = false, -- Enable contrast for floating windows
				cursor_line = false, -- Enable darker background for the cursor line
				lsp_virtual_text = false, -- Enable contrasted background for lsp virtual text
				non_current_windows = false, -- Enable contrasted background for non-current windows
				filetypes = {}, -- Specify which filetypes get the contrasted (darker) background
			},

			styles = { -- Give comments style such as bold, italic, underline etc.
				comments = { --[[ italic = true ]]
				},
				strings = { --[[ bold = true ]]
				},
				keywords = { --[[ underline = true ]]
				},
				functions = { --[[ bold = true, undercurl = true ]]
				},
				variables = {},
				operators = {},
				types = {},
			},

			plugins = { -- Uncomment the plugins that you use to highlight them
				-- Available plugins:
				-- "coc",
				-- "colorful-winsep",
				-- "dap",
				-- "dashboard",
				-- "eyeliner",
				-- "fidget",
				-- "flash",
				-- "gitsigns",
				-- "harpoon",
				-- "hop",
				-- "illuminate",
				-- "indent-blankline",
				-- "lspsaga",
				-- "mini",
				-- "neogit",
				-- "neotest",
				-- "neo-tree",
				-- "neorg",
				-- "noice",
				-- "nvim-cmp",
				-- "nvim-navic",
				-- "nvim-tree",
				-- "nvim-web-devicons",
				-- "rainbow-delimiters",
				-- "sneak",
				-- "telescope",
				-- "trouble",
				-- "which-key",
				-- "nvim-notify",
			},

			disable = {
				colored_cursor = false, -- Disable the colored cursor
				borders = false, -- Disable borders between vertically split windows
				background = false, -- Prevent the theme from setting the background (NeoVim then uses your terminal background)
				term_colors = false, -- Prevent the theme from setting terminal colors
				eob_lines = false, -- Hide the end-of-buffer lines
			},

			high_visibility = {
				lighter = false, -- Enable higher contrast text for lighter style
				darker = false, -- Enable higher contrast text for darker style
			},

			lualine_style = "default", -- Lualine style ( can be 'stealth' or 'default' )

			async_loading = true, -- Load parts of the theme asynchronously for faster startup (turned on by default)

			custom_colors = nil, -- If you want to override the default colors, set this to a function

			custom_highlights = {}, -- Overwrite highlights with your own
		},
	},
	{
		"scottmckendry/cyberdream.nvim",
		lazy = false,
		priority = 1000,
	},
	{
		"ribru17/bamboo.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("bamboo").setup({
				-- Main options --
				-- NOTE: to use the light theme, set `vim.o.background = 'light'`
				style = "vulgaris", -- Choose between 'vulgaris' (regular), 'multiplex' (greener), and 'light'
				toggle_style_key = nil, -- Keybind to toggle theme style. Leave it nil to disable it, or set it to a string, e.g. "<leader>ts"
				toggle_style_list = { "vulgaris", "multiplex", "light" }, -- List of styles to toggle between
				transparent = false, -- Show/hide background
				dim_inactive = false, -- Dim inactive windows/buffers
				term_colors = true, -- Change terminal color as per the selected theme style
				ending_tildes = false, -- Show the end-of-buffer tildes. By default they are hidden
				cmp_itemkind_reverse = false, -- reverse item kind highlights in cmp menu

				-- Change code style ---
				-- Options are anything that can be passed to the `vim.api.nvim_set_hl` table
				-- You can also configure styles with a string, e.g. keywords = 'italic,bold'
				code_style = {
					comments = { italic = true },
					conditionals = { italic = true },
					keywords = {},
					functions = {},
					namespaces = { italic = true },
					parameters = { italic = true },
					strings = {},
					variables = {},
				},
				-- Lualine options --
				lualine = {
					transparent = false, -- lualine center bar transparency
				},

				-- Custom Highlights --
				colors = {}, -- Override default colors
				highlights = {}, -- Override highlight groups

				-- Plugins Config --
				diagnostics = {
					darker = false, -- darker colors for diagnostic
					undercurl = true, -- use undercurl instead of underline for diagnostics
					background = true, -- use background color for virtual text
				},
			})
			require("bamboo").load()
		end,
	},
	{
		"neanias/everforest-nvim",
		version = false,
		lazy = false,
		priority = 1000, -- make sure to load this before all the other start plugins
		-- Optional; default configuration will be used if setup isn't called.
		config = function()
			require("everforest").setup({
				-- Your config here
			})
		end,
	},
	{
		"craftzdog/solarized-osaka.nvim",
		lazy = false,
		priority = 1000,
		opts = {
			-- your configuration comes here
			-- or leave it empty to use the default settings
			transparent = true, -- Enable this to disable setting the background color
			terminal_colors = true, -- Configure the colors used when opening a `:terminal` in [Neovim](https://github.com/neovim/neovim)
			styles = {
				-- Style to be applied to different syntax groups
				-- Value is any valid attr-list value for `:help nvim_set_hl`
				comments = { italic = true },
				keywords = { italic = true },
				functions = {},
				variables = {},
				-- Background styles. Can be "dark", "transparent" or "normal"
				sidebars = "dark", -- style for sidebars, see below
				floats = "dark", -- style for floating windows
			},
			sidebars = { "qf", "help" }, -- Set a darker background on sidebar-like windows. For example: `["qf", "vista_kind", "terminal", "packer"]`
			day_brightness = 0.3, -- Adjusts the brightness of the colors of the **Day** style. Number between 0 and 1, from dull to vibrant colors
			hide_inactive_statusline = false, -- Enabling this option, will hide inactive statuslines and replace them with a thin border instead. Should work with the standard **StatusLine** and **LuaLine**.
			dim_inactive = false, -- dims inactive windows
			lualine_bold = false, -- When `true`, section headers in the lualine theme will be bold

			--- You can override specific color groups to use other groups or a hex color
			--- function will be called with a ColorScheme table
			---@param colors ColorScheme
			on_colors = function(colors) end,

			--- You can override specific highlights to use other groups or a hex color
			--- function will be called with a Highlights and ColorScheme table
			---@param highlights Highlights
			---@param colors ColorScheme
			on_highlights = function(highlights, colors) end,
		},
	},
	{
		"rebelot/kanagawa.nvim",
		priority = 1000,
		opts = {
			compile = false, -- enable compiling the colorscheme
			undercurl = true, -- enable undercurls
			commentStyle = { italic = true },
			functionStyle = {},
			keywordStyle = { italic = true },
			statementStyle = { bold = true },
			typeStyle = {},
			transparent = false, -- do not set background color
			dimInactive = false, -- dim inactive window `:h hl-NormalNC`
			terminalColors = true, -- define vim.g.terminal_color_{0,17}
			colors = { -- add/modify theme and palette colors
				palette = {},
				theme = { wave = {}, lotus = {}, dragon = {}, all = {} },
			},
			overrides = function(colors) -- add/modify highlights
				return {}
			end,
			theme = "wave", -- Load "wave" theme when 'background' option is not set
			background = { -- map the value of 'background' option to a theme
				dark = "wave", -- try "dragon" !
				light = "lotus",
			},
		},
	},
	{
		"sho-87/kanagawa-paper.nvim",
		lazy = false,
		priority = 1000,
		opts = {
			undercurl = true,
			transparent = false,
			gutter = false,
			dimInactive = true, -- disabled when transparent
			terminalColors = true,
			commentStyle = { italic = true },
			functionStyle = { italic = false },
			keywordStyle = { italic = false, bold = false },
			statementStyle = { italic = false, bold = false },
			typeStyle = { italic = false },
			colors = { theme = {}, palette = {} }, -- override default palette and theme colors
			overrides = function() -- override highlight groups
				return {}
			end,
		},
	},
	{
		"navarasu/onedark.nvim",
		priority = 1000,
		opts = {
			-- Main options --
			style = "dark", -- Default theme style. Choose between 'dark', 'darker', 'cool', 'deep', 'warm', 'warmer' and 'light'
			transparent = false, -- Show/hide background
			term_colors = true, -- Change terminal color as per the selected theme style
			ending_tildes = false, -- Show the end-of-buffer tildes. By default they are hidden
			cmp_itemkind_reverse = false, -- reverse item kind highlights in cmp menu

			-- toggle theme style ---
			toggle_style_key = nil, -- keybind to toggle theme style. Leave it nil to disable it, or set it to a string, for example "<leader>ts"
			toggle_style_list = { "dark", "darker", "cool", "deep", "warm", "warmer", "light" }, -- List of styles to toggle between

			-- Change code style ---
			-- Options are italic, bold, underline, none
			-- You can configure multiple style with comma separated, For e.g., keywords = 'italic,bold'
			code_style = {
				comments = "italic",
				keywords = "none",
				functions = "none",
				strings = "none",
				variables = "none",
			},

			-- Lualine options --
			lualine = {
				transparent = false, -- lualine center bar transparency
			},

			-- Custom Highlights --
			colors = {}, -- Override default colors
			highlights = {}, -- Override highlight groups

			-- Plugins Config --
			diagnostics = {
				darker = true, -- darker colors for diagnostic
				undercurl = true, -- use undercurl instead of underline for diagnostics
				background = true, -- use background color for virtual text
			},
		},
	},
	{
		"rmehri01/onenord.nvim",
		priority = 1000,
		opts = {
			theme = nil, -- "dark" or "light". Alternatively, remove the option and set vim.o.background instead
			borders = true, -- Split window borders
			fade_nc = false, -- Fade non-current windows, making them more distinguishable
			-- Style that is applied to various groups: see `highlight-args` for options
			styles = {
				comments = "NONE",
				strings = "NONE",
				keywords = "NONE",
				functions = "NONE",
				variables = "NONE",
				diagnostics = "underline",
			},
			disable = {
				background = false, -- Disable setting the background color
				float_background = false, -- Disable setting the background color for floating windows
				cursorline = false, -- Disable the cursorline
				eob_lines = true, -- Hide the end-of-buffer lines
			},
			-- Inverse highlight for different groups
			inverse = {
				match_paren = false,
			},
			custom_highlights = {}, -- Overwrite default highlight groups
			custom_colors = {}, -- Overwrite default colors
		},
	},
	{
		"Shatur/neovim-ayu",
		priority = 1000,
		opts = {
			mirage = false, -- Set to `true` to use `mirage` variant instead of `dark` for dark background.
			terminal = true, -- Set to `false` to let terminal manage its own colors.
			overrides = {
				Normal = { bg = "None" },
				ColorColumn = { bg = "None" },
				SignColumn = { bg = "None" },
				Folded = { bg = "None" },
				FoldColumn = { bg = "None" },
				CursorLine = { bg = "None" },
				CursorColumn = { bg = "None" },
				WhichKeyFloat = { bg = "None" },
				VertSplit = { bg = "None" },
			},
		},
	},
	{
		"EdenEast/nightfox.nvim",
		priority = 1000,
		opts = {
			options = {
				-- Compiled file's destination location
				compile_path = vim.fn.stdpath("cache") .. "/nightfox",
				compile_file_suffix = "_compiled", -- Compiled file suffix
				transparent = false, -- Disable setting background
				terminal_colors = true, -- Set terminal colors (vim.g.terminal_color_*) used in `:terminal`
				dim_inactive = false, -- Non focused panes set to alternative background
				module_default = true, -- Default enable value for modules
				colorblind = {
					enable = false, -- Enable colorblind support
					simulate_only = false, -- Only show simulated colorblind colors and not diff shifted
					severity = {
						protan = 0, -- Severity [0,1] for protan (red)
						deutan = 0, -- Severity [0,1] for deutan (green)
						tritan = 0, -- Severity [0,1] for tritan (blue)
					},
				},
				styles = { -- Style to be applied to different syntax groups
					comments = "NONE", -- Value is any valid attr-list value `:help attr-list`
					conditionals = "NONE",
					constants = "NONE",
					functions = "NONE",
					keywords = "NONE",
					numbers = "NONE",
					operators = "NONE",
					strings = "NONE",
					types = "NONE",
					variables = "NONE",
				},
				inverse = { -- Inverse highlight for different types
					match_paren = false,
					visual = false,
					search = false,
				},
				modules = { -- List of various plugins and additional options
					-- ...
				},
			},
			palettes = {},
			specs = {},
			groups = {},
		},
	},
	{
		"ellisonleao/gruvbox.nvim",
		priority = 1000,
		config = true,
		opts = {
			terminal_colors = true, -- add neovim terminal colors
			undercurl = true,
			underline = true,
			bold = true,
			italic = {
				strings = true,
				emphasis = true,
				comments = true,
				operators = false,
				folds = true,
			},
			strikethrough = true,
			invert_selection = false,
			invert_signs = false,
			invert_tabline = false,
			invert_intend_guides = false,
			inverse = true, -- invert background for search, diffs, statuslines and errors
			contrast = "", -- can be "hard", "soft" or empty string
			palette_overrides = {},
			overrides = {},
			dim_inactive = false,
			transparent_mode = false,
		},
	},
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		opts = {
			flavour = "auto", -- latte, frappe, macchiato, mocha
			background = { -- :h background
				light = "latte",
				dark = "mocha",
			},
			transparent_background = false, -- disables setting the background color.
			show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
			term_colors = false, -- sets terminal colors (e.g. `g:terminal_color_0`)
			dim_inactive = {
				enabled = false, -- dims the background color of inactive window
				shade = "dark",
				percentage = 0.15, -- percentage of the shade to apply to the inactive window
			},
			no_italic = false, -- Force no italic
			no_bold = false, -- Force no bold
			no_underline = false, -- Force no underline
			styles = { -- Handles the styles of general hi groups (see `:h highlight-args`):
				comments = { "italic" }, -- Change the style of comments
				conditionals = { "italic" },
				loops = {},
				functions = {},
				keywords = {},
				strings = {},
				variables = {},
				numbers = {},
				booleans = {},
				properties = {},
				types = {},
				operators = {},
				-- miscs = {}, -- Uncomment to turn off hard-coded styles
			},
			color_overrides = {},
			custom_highlights = {},
			default_integrations = true,
			integrations = {
				cmp = true,
				gitsigns = true,
				nvimtree = true,
				treesitter = true,
				notify = false,
				mini = {
					enabled = true,
					indentscope_color = "",
				},
				-- For more plugins integrations please scroll down (https://github.com/catppuccin/nvim#integrations)
			},
		},
	},
	-- Configure LazyVim to load gruvbox
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "gruvbox",
		},
	},
}
