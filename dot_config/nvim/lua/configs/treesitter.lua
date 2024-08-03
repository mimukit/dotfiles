local options = {
	ensure_installed = {
		"bash",
		"css",
		"csv",
		"dockerfile",
		"fish",
		"html",
		"javascript",
		"jsdoc",
		"json",
		"kdl",
		"lua",
		"luadoc",
		"markdown",
		"php",
		"printf",
		"robots",
		"scss",
		"ssh_config",
		"tmux",
		"toml",
		"typescript",
		"vim",
		"vimdoc",
		"yaml",
	},

	highlight = {
		enable = true,
		use_languagetree = true,
	},

	indent = { enable = true },
}

require("nvim-treesitter.configs").setup(options)
