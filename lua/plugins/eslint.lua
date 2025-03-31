return {
  "MunifTanjim/eslint.nvim",
  enabled = false,
  dependencies = {
    "jose-elias-alvarez/null-ls.nvim",
    "neovim/nvim-lspconfig",
  },
  event = "BufRead",
  config = function()
    local null_ls = require("null-ls")
    local eslint = require("eslint")

    null_ls.setup()

    eslint.setup({
      bin = "eslint", -- or `eslint_d`
      code_actions = {
        enable = true,
        apply_on_save = {
          enable = true,
          types = { "directive", "problem", "suggestion", "layout" },
        },
        disable_rule_comment = {
          enable = true,
          location = "separate_line", -- or `same_line`
        },
      },
      diagnostics = {
        enable = true,
        report_unused_disable_directives = false,
        run_on = "type", -- or `save`
      },
    })
  end,
}
