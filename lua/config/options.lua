-- 基础选项（无插件依赖，随 config.lazy 最早加载）
-- 查询：:h option-list（全量）、:set <option>?（当前值）、:h '<option>'（详情）

-- 键位前缀（必须在 lazy.setup 之前设置，插件的 <leader> 键依赖它）
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- 默认主题：tokyonight / catppuccin / habamax（启动时加载，见 config.lazy）
-- 主题不在 options 里设了：见 lua/config/theme.lua（active + variant），改一处即可切换

local opt = vim.opt

-- ===== 编辑行为 =====
opt.expandtab = true -- Tab 输入展开为空格（默认 false）
opt.tabstop = 4 -- 文件中 Tab 的显示宽度（默认 8）
opt.shiftwidth = 4 -- >>/<</自动缩进宽度，与 tabstop 一致（默认 8）
opt.shiftround = true -- >>/<< 缩进取整到 shiftwidth 倍数（默认 false）
opt.smartindent = true -- 自动缩进（默认 false）
-- 哪些命令可以跨到上/下一行（nvim 默认 "b,s" = <BS> 和 <Space>）。之前把 h / l / 方向键 / [ ]
-- 也加进来了，结果一行内左右移到底会跳到上下行；改回默认。想完全禁止跨行就写 ""。
opt.whichwrap = "b,s"
opt.virtualedit = "block" -- 可视块模式允许光标进入无字符区域（默认 ""）
opt.autowrite = true -- 切换 buffer 前自动保存（默认 false）

-- ===== 视觉与 UI =====
opt.number = true -- 显示行号（默认 false）
opt.relativenumber = true -- 相对行号，配合 <n>j/k 跳转（默认 false）
opt.cursorline = true -- 高亮当前行（默认 false）
opt.colorcolumn = "120" -- 第 120 列参考线（默认 "" 关闭）
opt.signcolumn = "yes" -- 签名列常驻，避免诊断符号出现时文本抖动（默认 "auto"）
opt.termguicolors = true -- 24 位真彩色（默认 false）
opt.scrolloff = 16 -- 光标距上下边缘保留 16 行（约半屏；屏幕 32 行时≈居中）
opt.sidescrolloff = 8 -- 光标距左右边缘最小列数（默认 0；想水平也居中就同样改 999）
opt.smoothscroll = true -- <C-e>/<C-y> 平滑滚动（默认 false）
opt.list = true -- 显示不可见字符（默认 false）
opt.listchars = { tab = "» ", trail = "·" } -- Tab 与行尾空格显示（默认仅 trail "-"）
opt.fillchars = {
  foldopen = "", -- 折叠打开符号
  foldclose = "", -- 折叠关闭符号
  fold = " ", -- 折叠列填充
  foldsep = " ", -- 折叠分隔
  diff = "╱", -- diff 删除填充
  eob = " ", -- 隐藏 buffer 末尾的 ~
}
-- 浮动窗口背景混合度（0=不透明，100=全透明）。实测只要 >0 就会把浮层和背后的代码混色，
-- 表现为「两层字叠在一起」（lazy 面板、上下文浮层都中招），所以保持 0。想轻微透明可从 10 试起。
-- 影响 picker / hover / 通知 / snacks 浮窗；它是窗口局部选项，之后可以按窗口单独调。
-- 旧配置里这里是 winblend = 15（注释着）。
opt.winblend = 0 -- 浮动窗口不混色（>0 会让浮层透出底下的代码，糊成两层）
opt.conceallevel = 2 -- 隐藏 markdown 加粗/斜体等标记（默认 0）
opt.laststatus = 3 -- 全局单条状态栏（默认 2）
opt.showmode = false -- 不显示 "-- INSERT --"，状态栏已展示（默认 true）
opt.ruler = false -- 不显示右下角行列，状态栏已展示（默认 true）
opt.pumheight = 10 -- 补全菜单最大条目数（默认 0 不限制）
opt.pumblend = 0 -- 补全菜单不混色（同上）

-- ===== 搜索 =====
opt.ignorecase = true -- 搜索忽略大小写（默认 false）
opt.smartcase = true -- 搜索串含大写时恢复大小写敏感（默认 false）
opt.inccommand = "nosplit" -- 增量替换预览，不分窗（默认 "nosplit"）

-- ===== 补全 =====
opt.completeopt = "menu,menuone,noselect" -- menuone 单个匹配也显示、noselect 不自动选中（默认 "menu,popup"）

-- ===== 分窗与跳转 =====
opt.splitbelow = true -- :split 开在当前窗口下方（默认 false）
opt.splitright = true -- :vsplit 开在右侧（默认 false）
opt.splitkeep = "screen" -- 分窗/关窗时保持屏幕内容（默认 "cursor"）
opt.winminwidth = 5 -- 窗口最小宽度（默认 1）
opt.jumpoptions = "view" -- 大范围跳转保留视图（默认 "clean"）

-- ===== 折叠 =====
opt.foldlevel = 99 -- 默认展开所有折叠（默认 0）
opt.foldmethod = "indent" -- 按缩进折叠（默认 "manual"）
opt.foldtext = "" -- 折叠行文本置空（默认显示折叠内容）

-- ===== 性能与行为 =====
opt.timeoutlen = 300 -- 键序列等待时长(ms)，越小 which-key 越快（默认 1000）
opt.updatetime = 200 -- swap 写入与 CursorHold 间隔(ms)（默认 4000）
opt.mouse = "a" -- 全模式启用鼠标（默认部分模式）
opt.clipboard = vim.env.SSH_CONNECTION and "" or "unnamedplus" -- 系统剪贴板；SSH 下关闭走 OSC52（默认 ""）
opt.confirm = true -- 有未保存修改时退出需确认（默认 false）
opt.wildmode = "longest:full,full" -- 命令行补全：先最长公共前缀再全量（默认 "full"）
opt.wrap = false -- 不自动折行（默认 true）
opt.linebreak = true -- 折行时在单词边界断行（默认 false）
opt.shortmess:append({ W = true, I = true, c = true, C = true }) -- 精简提示信息
opt.shortmess:append("q") -- 不显示 "recording @q" 宏录制指示（也避免 noice 状态栏滞留）
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" } -- 会话保存内容
opt.undofile = false -- 不做持久化撤销（= nvim 默认；之前开过，按需求关掉）
opt.undolevels = 10000 -- 撤销层级数（默认 1000）
opt.spelllang = { "en" } -- 拼写检查语言（默认空）

-- ===== 工具集成（引用 util 模块） =====
opt.grepprg = "rg --vimgrep" -- 搜索用 ripgrep（默认内建 grep）
opt.grepformat = "%f:%l:%c:%m" -- rg 输出解析格式
opt.formatoptions = "jcroqlnt" -- 自动注释/格式化行为
opt.formatexpr = "v:lua.require('util.format').formatexpr()" -- gq 格式化走 conform
opt.statuscolumn = [[%!v:lua.require('util.statuscolumn').get()]] -- 状态列（行号/诊断/折叠，走 snacks）

-- markdown 缩进修复（默认会错误缩进）
vim.g.markdown_recommended_style = 0
