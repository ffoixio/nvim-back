local U = require("util.init")

return {
  { "folke/lazy.nvim", version = "*" },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {},
    config = function(_, opts)
      local notify = vim.notify
      require("snacks").setup(opts)
      -- HACK: restore vim.notify after snacks setup and let noice.nvim take over
      if U.has("noice.nvim") then
        vim.notify = notify
      end
    end,
  },
}
