-- 模块开关：语言模块（plugins/lang/*）和功能模块（plugins/*）的启停，只在这一个文件里控制。
--
-- 用法：把对应项写成 false 即可关闭（文件仍留在仓库里，只是不加载），改完重启 nvim 生效。
--   · lang    —— 每种语言一个模块，里面装 parser / LSP / 格式化 / lint
--   · feature —— 每个功能一块：core(Snacks 等) / editor / picker / ui / lsp / formatting …
-- 注意两点：
--   1. 关掉的是"这一块配置"，不是某个插件本身（同一个插件可能被多个模块配置）；
--   2. 新增模块文件后要来这里登记，否则不会加载 —— :checkhealth config 会提示漏登记的模块。

local M = {}

---@type table<string, boolean>
M.lang = {
  clangd = true, -- C / C++
  cmake = true,
  docker = true,
  git = true, -- gitcommit / git_config / gitattributes / diff
  go = false, -- 暂不学 Go，要用时改 true（需 pacman -S go）
  json = true,
  julia = false, -- 系统未装 julia，要用时改 true
  make = true, -- Makefile + Justfile
  nix = true,
  perl = false, -- 暂不写 Perl
  python = true,
  rust = false, -- 暂不写 Rust（要用时还需 pacman -S rust）
  scala = false, -- 暂不写 Scala（metals 由 coursier 自取）
  sql = false, -- SQL 交给 IDEA/Navicat，nvim 侧只保留基础编辑
  tcl = false, -- 暂时没有 xdc/Tcl 要写
  toml = true,
  verilog = true, -- Verilog / SystemVerilog（verible）
  yaml = true,
  zig = false, -- 暂不学 Zig，要用时改 true（需 pacman -S zig）
}

---@type table<string, boolean>
M.feature = {
  coding = true, -- mini.ai / mini.pairs 等编辑增强
  colorscheme = true, -- catppuccin / tokyonight + 透明背景
  completion = true, -- blink.cmp
  core = true, -- lazy.nvim / snacks 基础能力
  editor = true, -- which-key / todo-comments / illuminate …
  explorer = true, -- 文件浏览器
  formatting = true, -- conform
  linting = true, -- nvim-lint
  lsp = true, -- LSP 总配置 + mason
  picker = true, -- snacks picker 的各项 picker
  treesitter = true,
  ui = true, -- bufferline / lualine / 状态栏 / 各种 UI
  util = true, -- 杂项小工具插件
}

--- 某个类别里已开启的模块名（按字母序，保证每次启动加载顺序一致）
---@param kind "lang"|"feature"
---@return string[]
function M.list(kind)
  local enabled = {}
  for name, on in pairs(M[kind] or {}) do
    if on then
      enabled[#enabled + 1] = name
    end
  end
  table.sort(enabled)
  return enabled
end

return M
