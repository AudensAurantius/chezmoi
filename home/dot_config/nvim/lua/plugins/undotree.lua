return {
	{
		"debugloop/telescope-undo.nvim",
		dependencies = { -- note how they're inverted to above example
			{
				"nvim-telescope/telescope.nvim",
				dependencies = { "nvim-lua/plenary.nvim" },
			},
		},
		keys = {
			{ -- lazy style key map
				"<leader>U",
				"<cmd>Telescope undo<cr>",
				desc = "undo history",
			},
		},
		opts = {
			-- don't use `defaults = { }` here, do this in the main telescope spec
			extensions = {
				undo = {
					use_delta = true,
					-- use_custom_command = nil, -- setting this implies `use_delta = false`. Accepted format is: { "bash", "-c", "echo '$DIFF' | delta" }
					side_by_side = true,
					layout_strategy = "vertical",
					layout_config = {
						preview_height = 0.8,
					},
					vim_diff_opts = {
						ctxlen = vim.o.scrolloff,
					},
					entry_format = "state #$ID, $STAT, $TIME",
					time_format = "",
					saved_only = false,
					mappings = {
						-- set mapping to `false` to disable it
						i = {
							["<cr>"] = function(bufnr)
								return require("telescope-undo.actions").yank_additions
							end,
							["<S-cr>"] = function(bufnr)
								return require("telescope-undo.actions").yank_deletions
							end,
							["<C-cr>"] = function(bufnr)
								return require("telescope-undo.actions").restore
							end,
							-- alternative defaults, for users whose terminals do questionable things with modified <cr>
							["<C-y>"] = function(bufnr)
								return require("telescope-undo.actions").yank_deletions
							end,
							["<C-r>"] = function(bufnr)
								return require("telescope-undo.actions").restore
							end,
						},
						n = {
							["y"] = function(bufnr)
								return require("telescope-undo.actions").yank_additions
							end,
							["Y"] = function(bufnr)
								return require("telescope-undo.actions").yank_deletions
							end,
							["u"] = function(bufnr)
								return require("telescope-undo.actions").restore
							end,
						},
					},
				},
				-- no other extensions here, they can have their own spec too
			},
		},
		config = function(_, opts)
			-- Calling telescope's setup from multiple specs does not hurt, it will happily merge the
			-- configs for us. We won't use data, as everything is in it's own namespace (telescope
			-- defaults, as well as each extension).
			require("telescope").setup(opts)
			require("telescope").load_extension("undo")
		end,
	},
}
