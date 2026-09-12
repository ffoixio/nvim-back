# TODO / 待办

> 这里放"想改但先不动"的事。代码里的待办写成 `TODO` 加冒号的注释，写在对应域的文件里，
> `:TodoQuickFix`（或 `<leader>sT`）能一次列出所有 TODO/FIXME/HACK/NOTE。

## 1. 状态栏：换成 Neovim 原生 statusline，去掉 lualine

**代码位置**：`lua/plugins/ui.lua`（lualine 规格上方有对应的 `TODO` 注释）

**动机**：原生 `vim.o.statusline` 已经够用，不必再"插件 + hack"；代价是每一项都得自己写求值函数。

**要迁移的信息项（12 个）**：
mode / branch / 项目根目录 / 诊断计数 / filetype / 文件路径 / navic 面包屑 /
lazy 更新数 / diff / 进度% / 行:列 / 时钟

**分工：哪些是内置的，哪些要自己写 Lua**

| 信息 | 原生方案 |
|---|---|
| 行:列 / 进度 / 文件名 / 已修改 | 内置：`%l:%c`、`%p%%`、`%f`、`%m` |
| 时钟 | 内置：`%{strftime('%R')}` |
| 模式名（要 `NORMAL` 而不是 `n`） | Lua：`vim.api.nvim_get_mode().mode` |
| navic 面包屑 | Lua：`require("nvim-navic").get_location()` |
| lazy 更新数 | Lua：`require("lazy.status").updates()`（无更新时返回 `false`，必须兜底） |
| diff / 诊断 / git 分支 | Lua：`vim.b.gitsigns_status_dict`、`vim.diagnostic.count()`、`vim.b.gitsigns_head` |

**已验证可行的骨架**（在沙箱里真实渲染过；7 个 `v:lua` 函数，全部包了 pcall 兜底）：

```lua
Status = {}
local function safe(fn)
  return function()
    local ok, r = pcall(fn)
    return ok and tostring(r or "") or ""
  end
end
Status.mode    = safe(function() return vim.api.nvim_get_mode().mode:upper() end)
Status.branch  = safe(function() return vim.b.gitsigns_head or "" end)
Status.root    = safe(function() return vim.fs.basename(require("util.root").get({ normalize = true })) end)
Status.path    = safe(function() return vim.fn.expand("%:.") end)
Status.navic   = safe(function() return require("nvim-navic").get_location() end)
Status.updates = safe(function() return require("lazy.status").updates() or "" end)
Status.diff    = safe(function()
  local g = vim.b.gitsigns_status_dict
  if not g then return "" end
  return ("+%d ~%d -%d"):format(g.added or 0, g.changed or 0, g.removed or 0)
end)
Status.diag = safe(function()
  local d = vim.diagnostic.count(0)
  return ("E%d W%d I%d H%d"):format(d[1] or 0, d[2] or 0, d[3] or 0, d[4] or 0)
end)

vim.o.statusline = " %{v:lua.Status.mode()} │ %{v:lua.Status.branch()} │ %{v:lua.Status.path()} %{v:lua.Status.navic()} %= %{v:lua.Status.updates()} %{v:lua.Status.diff()} %{v:lua.Status.diag()} │ %p%% │ %l:%c │ %{strftime('%R')} "
```

**坑**
- `%{}` **每次重绘都会求值** → 函数要便宜，必要时自己缓存。
- 没数据要返回空串：`updates()` 在没更新时返回 `false`，直接放进状态栏会显示成 `false`。
- 左右对齐靠 `%=`；高亮要自己写 `%#Group#`。
- lualine 的 `navic` 组件其实是 **nvim-navic 自己提供的**（`nvim-navic/lua/lualine/components/navic.lua`）；去掉 lualine 后要直接调 nvim-navic。
- lualine 的 `disabled_filetypes`（dashboard / alpha 等不显示状态栏）要用 `FileType` autocmd 自己处理。

## 2. 背景透明（当前：**开启中**，开关在 `lua/plugins/colorscheme.lua` 顶部）

**两个入口**：

- 启动默认值：`lua/plugins/colorscheme.lua` 顶部的 `transparent()`（读 `vim.g.transparent_background`，nil 视为 true）；
- 运行时一键切换：**`<leader>uT`**（逻辑在 `lua/util/transparency.lua`，直接改高亮组——因为 catppuccin 的编译缓存不认开关变化，重新上色拿到的还是旧主题）。

它同时驱动三件事：

1. catppuccin `transparent_background` / tokyonight `transparent` —— 让 `Normal` 等变成 `bg=NONE`，
   终端的 opacity 才有东西可透；
2. `TreesitterContext` / `TreesitterContextLineNumber` 的底色：透明时 `NONE`（有底色就是一块突兀色块），
   不透明时 `base`（和正文同色）；
3. 透明时强制这 9 个“盖在代码上”的面板为实底（catppuccin 的透明模式会把它们清空、底下代码会透上来）：
   `NormalFloat`、`FloatBorder`、`Pmenu`、`NotifyBackground`、`LazyNormal`、
   `LazyButton`、`LazyButtonActive`、`TroubleNormal`、`SnacksPickerNormal`

**必须保持 `winblend = 0`**（`lua/config/options.lua`）：只要 > 0 就会把浮层和背后的代码混色，
表现为“两层字叠在一起”，跟底色无关。

**环境前提，先自检**：
- `:echo $WT_SESSION` 有值 = 确实在 Windows Terminal 里；`:echo $TMUX` 为空 = 中间没有 tmux 挡着。
- Windows Terminal 的 `opacity` 是“**不**透明度”（100 = 完全不透明，50 = 半透明）；
  非 Windows 11 需要 `"useAcrylic": true` 才有不模糊的透明。
- 终端 opacity 若还是 100，开透明看起来会和没开一样。

**已知副作用**（不喜欢就把开关改回 false）：状态栏、signcolumn 等也会一起变透明。
## 3. 动画参数（已调好，一般不用动）

- **滚动**：`unit = "step"`、12ms/步、`max_output_steps = 20`
  （实测 2 步 24ms / 5 步 60ms / 20 步 240ms；旧的 `unit = "total"` 恒 150ms，
  贴边只能滚几行时也演满 150ms，观感很怪）
- **光标**：默认 250ms（5 步），偏慢，快速移动时"追不上"（纯视觉，不影响操作）。
  嫌慢可调 `cursor.timing`，或 `cursor = { enable = false }` 只关光标动画。
- **窗口缩放**：50ms。
- `<leader>ua` 一键开关 Mini Animate，用来 A/B 对比卡顿来源。
