-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

local lspconfig = require("lspconfig")

local servers = {
	"bashls",
	"cssls",
	"dockerls",
	"docker_compose_language_service",
	"eslint",
	"emmet_ls",
	"html",
	"jsonls",
	"marksman",
	"mdx_analyzer",
	"phpactor",
	"postgres_lsp",
	"pyright",
	"sqls",
	"somesass_ls",
	"tailwindcss",
	"taplo",
	"tsserver",
	"typos_lsp",
	"yamlls",
}
local nvlsp = require("nvchad.configs.lspconfig")

-- lsps with default config
for _, lsp in ipairs(servers) do
	lspconfig[lsp].setup({
		on_attach = nvlsp.on_attach,
		on_init = nvlsp.on_init,
		capabilities = nvlsp.capabilities,
	})
end
