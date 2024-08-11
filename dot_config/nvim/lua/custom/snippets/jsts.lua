local ls = require('luasnip')
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

-- stylua: ignore
local console_log_detailed = s("cld", {
  t("console.log(`🐞🐞🐞 "), i(1), t("`, "), i(2), t(");"),
})

-- Add snippets for each file type
ls.add_snippets('javascript', { console_log_detailed })
ls.add_snippets('typescript', { console_log_detailed })
ls.add_snippets('javascriptreact', { console_log_detailed })
ls.add_snippets('typescriptreact', { console_log_detailed })
