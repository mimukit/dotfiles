local options = {
	css = { "prettier" },
	graphql = { "prettier" },
	html = { "prettier" },
	javascript = { "prettier" },
	javascriptreact = { "prettier" },
	json = { "prettier" },
	liquid = { "prettier" },
	lua = { "stylua" },
	markdown = { "prettier" },
	python = { "isort", "black" },
	svelte = { "prettier" },
	typescript = { "prettier" },
	typescriptreact = { "prettier" },
	yaml = { "prettier" },
	formatters_by_ft = {},

	format_on_save = {
		-- These options will be passed to conform.format()
		timeout_ms = 1000,
		lsp_fallback = true,
	},
}

return options
