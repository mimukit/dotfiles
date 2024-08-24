local function is_macos()
  local os_type = vim.loop.os_uname().sysname
  return os_type == "Darwin"
end

local treesitter_list = {}

if is_macos() then
  treesitter_list = {
    "bash",
    "c",
    "css",
    "csv",
    "dockerfile",
    "fish",
    "gitignore",
    "html",
    "javascript",
    "jsdoc",
    "json",
    "kdl",
    "lua",
    "luadoc",
    "markdown",
    "markdown_inline",
    "php",
    "printf",
    "query",
    "regex",
    "robots",
    "scss",
    "ssh_config",
    "tmux",
    "toml",
    "tsx",
    "typescript",
    "vim",
    "vimdoc",
    "yaml",
  }
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = treesitter_list,
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = { "ruby" },
      },
      indent = { enable = true, disable = { "ruby" } },
    },
  },
}
