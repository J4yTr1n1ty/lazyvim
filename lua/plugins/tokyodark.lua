return {
  "tiagovla/tokyodark.nvim",
  opts = {
    transparent_background = false,
  },
  config = function(_, opts)
    require("tokyodark").setup(opts)
    vim.cmd([[colorscheme tokyodark]])
  end,
}
