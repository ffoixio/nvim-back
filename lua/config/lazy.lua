-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- options and autocmds are loaded early, before lazy.nvim installs plugins.
require("config.options")
require("config.autocmds")

-- register the LazyFile event used by some plugin specs
local Event = require("lazy.core.handler.event")
Event.mappings.LazyFile = { id = "LazyFile", event = { "BufReadPost", "BufNewFile", "BufWritePre" } }
Event.mappings["User LazyFile"] = Event.mappings.LazyFile

-- capture global option defaults used by util.set_default
require("util.init").setup()

require("lazy").setup({
  spec = {
    -- import every spec file under lua/plugins/ (including plugins/lang/)
    { import = "plugins" },
  },
  -- 并发拉取数（默认 20）：降到 8，避免同时开太多到 GitHub 的 TLS 连接被随机掐断
  concurrency = 8,
  defaults = {
    lazy = false, -- custom plugins load during startup
    version = false, -- always use the latest git commit
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = {
    enabled = true,
    notify = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

-- 加载默认主题（在 options.lua 里改 vim.g.colorscheme 切换）
vim.cmd.colorscheme(vim.g.colorscheme or "tokyonight")

-- keymaps and format/root setup run after startup (VeryLazy).
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    require("config.keymaps")
    require("util.format").setup()
    require("util.root").setup()
  end,
})
