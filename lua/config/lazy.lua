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
  -- 并发拉取数。注意 lazy 源码里的默认是 nil —— runner 只在给了数字时才限流（runner.lua:113），
  -- 也就是"不限制"，并不是文档里常说的 20；这里显式写 20，避免一次开太多 GitHub 连接。
  concurrency = 20,
  -- :Lazy 的浮动窗口（默认 border = "none"）
  ui = { border = "rounded" },
  defaults = {
    lazy = false, -- custom plugins load during startup
    version = false, -- always use the latest git commit
  },
  -- 装插件期间临时用的配色（不是默认主题；默认主题看 config/theme.lua 的 active）。
  -- lazy 按顺序挑第一个能加载的；"habamax" 是内建兜底，lazy 自己也会在末尾再补一个。
  install = { colorscheme = { "catppuccin", "habamax" } },
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

-- 主题无关的字体样式层（斜体/粗体…）：必须赶在第一次 :colorscheme 之前挂上 ColorScheme 钩子，
-- 之后每次换主题都会自动重刷。颜色还是主题说了算，见 lua/util/styles.lua 的表。
require("util.styles")

-- 加载当前主题（切主题改 lua/config/theme.lua 的 active 一行）。
-- theme.load() 内部会校验配置并 pcall，任何问题都回退到 catppuccin/frappe。
require("config.theme").load()

-- keymaps and format/root setup run after startup (VeryLazy).
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    require("config.keymaps")
    require("util.format").setup()
    require("util.root").setup()
  end,
})
