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

-- 功能模块与语言模块的加载清单都来自 config/modules.lua（只在那一个文件里开关）
local modules = require("config.modules")
local specs = {}
for _, name in ipairs(modules.list("feature")) do
  specs[#specs + 1] = { import = "plugins." .. name }
end
-- 语言模块必须逐个"文件"导入：给目录（import = "plugins.lang"）lazy 会把目录下所有文件都导进来，
-- 开关就失效了（实测 julia 开/关插件数都是 52）。
for _, name in ipairs(modules.list("lang")) do
  specs[#specs + 1] = { import = "plugins.lang." .. name }
end

require("lazy").setup({
  spec = specs,
  -- 并发拉取数（默认 20）：降到 4，进一步减少同时打开的 GitHub 连接
  concurrency = 4,
  -- :Lazy 的浮动窗口（默认 border = "none"）
  ui = { border = "rounded" },
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
        -- "tutor", -- 不禁用：保留内置教程命令 :Tutor / :Tutor zh
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
