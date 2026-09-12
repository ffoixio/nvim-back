# TODO / 待办

> 只记“想改但先不动”的事。代码里的待办写成 `TODO` 加冒号的注释，放在对应域的文件里；
> `:TodoQuickFix`（或 `<leader>st`）能一次列出所有 TODO / FIXME / HACK / NOTE。

## 状态栏：换成 Neovim 原生 statusline，去掉 lualine

**代码位置**：`lua/plugins/ui.lua`（lualine 规格上方有对应的 TODO 注释）

**动机**：原生 `vim.o.statusline` 已经够用，不必再“插件 + hack”；好处是以后加项不用等插件支持，
代价是每一项都得自己写求值函数。

**可放的信息项 = 下面三张表的并集**（还没最终敲定，先全列出来）

### A. Neovim 原生就有的 `%` 项（一行 Lua 都不用写）

| 项 | 显示 | 备注 |
|---|---|---|
| `%t` / `%f` / `%F` | 文件名 / 相对路径 / 绝对路径 | `%t` 只有文件名 |
| `%m` / `%M` | 修改标记 | `[+]` / `,+` |
| `%r` / `%R` | 只读标记 | |
| `%h` / `%H` | help 缓冲区标记 | |
| `%w` / `%W` | preview 窗口标记 | |
| `%y` / `%Y` | 文件类型 | `[lua]` / `,LUA` |
| `%q` | quickfix / location list 指示 | |
| `%k` | keymap 名 | 用了 lmap 才有 |
| `%n` | 缓冲区编号 | |
| `%b` / `%B` | 光标下字符（十进制 / 十六进制） | |
| `%o` / `%O` | 光标处字节偏移 | |
| `%l` / `%L` | 当前行 / 总行数 | |
| `%c` / `%v` / `%V` | 列 / 虚拟列 | `%V` 与 `%c` 相同时不显示 |
| `%p` | 文件百分比 | 就是现在那个 `93%` |
| `%P` | 可视窗口内的百分比 | 和 ruler 一样，固定 3 字符 |
| `%S` | **showcmd 内容**（待完成的按键） | 相当于 noice 显示的那个 `gj` / `2d` |
| `%a` | 参数列表 {当前}/{总数} | |
| `%{expr}` / `%{%expr%}` | 求值（后者把结果再当格式串解析） | |
| `%( %)` | 分组，可统一设宽度 / 对齐 | |
| `%=` | 左右分界 | |
| `%#Group#` | 切换高亮组 | |
| `%%` | 字面量 % | |

**用 `%{...}` 包一层 Vimscript 表达式就能拿到（仍算原生，不需要 Lua 模块）**：

- `%{&fenc}` 编码、`%{&ff}` 换行格式（fileformat）
- `%{getfsize(bufname('%'))}` 文件大小、`%{hostname()}` 主机名
- `%{strftime('%R')}` 时钟、`%{tabpagenr()}/%{tabpagenr('$')}` 页签

### B. lualine 自带、但需要自己写 Lua 的组件

| 组件 | 显示 | 原生替代方案 |
|---|---|---|
| mode | 模式名 `NORMAL` | `%{mode()}` 只给 `n`，得自己映射 |
| branch | git 分支 | gitsigns 的 `vim.b.gitsigns_head` |
| diagnostics | 诊断计数 | `vim.diagnostic.count(0)` |
| diff | 增 / 删 / 改行数 | `vim.b.gitsigns_status_dict` |
| location | 行:列 | 原生 `%l:%c` 就够 |
| progress | 百分比（含 `Top`/`Bot` 变体） | 原生 `%p%%`；要变体才写 Lua |
| searchcount | 搜索计数 `3/12` | `vim.fn.searchcount()` |
| selectioncount | 选中行数 | `vim.fn.line("v")` 之类 |
| lsp_status | LSP 客户端名 | `vim.lsp.get_clients()` |
| filetype | 类型 / 图标 | 原生 `%y`；要图标才写 Lua |
| encoding / fileformat / filesize / hostname / datetime | 编码 / 换行 / 大小 / 主机 / 时钟 | 见 A 表，原生即可 |
| filename | 路径 | 原生 `%f` / `%t`；你的 `pretty_path()` 要 Lua |
| buffers / tabs / windows | 缓冲区、页签、窗口列表 | 需要 Lua 遍历 |
| special | 所在目录 | `%{expand('%:h')}` |

### C. 你配置里自定义的（迁移时必须自己搬）

| 组件 | 来源 | 说明 |
|---|---|---|
| 项目根目录名 | `util/lualine.lua` 的 `root_dir()` | 可简化成 `vim.fs.basename(root.get())` |
| 相对路径（最多 3 段、文件名加粗） | `util/lualine.lua` 的 `pretty_path()` | 逻辑较长，建议整个 util 搬过去 |
| navic 面包屑 | nvim-navic | `require("nvim-navic").get_location()` |
| lazy 更新数 | `lazy.status.updates()` | 无更新时返回 `false`，必须兜底 |
| noice 命令 / 模式 | `noice.api.status.*` | 待完成命令、recording 等 |
| profiler 状态 | `Snacks.profiler.status()` | 只在剖析时出现 |

### 骨架（已实测渲染通过）

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

vim.o.statusline = " %{v:lua.Status.mode()} | %{v:lua.Status.branch()} | %{v:lua.Status.path()} %{v:lua.Status.navic()} %= %{v:lua.Status.updates()} %{v:lua.Status.diff()} %{v:lua.Status.diag()} | %p%% | %l:%c | %{strftime('%R')} "
```

### 坑

- `%{}` **每次重绘都会求值** → 函数要便宜，必要时自己缓存。
- 没数据要返回空串：`updates()` 无更新时返回 `false`，直接塞进状态栏会显示成 `false`。
- 左右对齐靠 `%=`；高亮要自己写 `%#Group#`。
- 分组 `%( %)` 可以整体设宽度和截断，适合左边那串路径。
- lualine 的 `navic` 组件其实是 **nvim-navic 自己提供的**（`nvim-navic/lua/lualine/components/navic.lua`）；去掉 lualine 后直接调 nvim-navic。
- lualine 还有 `disabled_filetypes`（dashboard / alpha 等不显示状态栏），原生方案要用 `FileType` autocmd 处理。

## 2. 全量审计留下的待办（2026-09-13，详见 `AUDIT.md`）

- ~~mason 孤儿包 `golangci-lint`~~ / ~~parser 孤儿 `go`/`gomod`/`gosum`/`gowork`~~：**已解决**——2026-09-13 起 Go 进"以后要用"的清单，`plugins/lang/go.lua` 已接上 gopls + goimports + golangci-lint，那几个 parser 就是它的高亮。
- **parser 孤儿 `haskell`**：仍然是孤儿（配置里没有 Haskell），无害；要清就删 `~/.local/share/nvim/site/parser/haskell.so` 与 `parser-info/haskell.revision`。
  注：**`dtd` 不是孤儿**——它是声明里 `xml` 的 `requires`（`parsers.lua:2284`），别删。
- **透明模块的 `palette()` 只认 catppuccin**：换非 catppuccin 主题时会静默回退成 frappe 调色板（开着透明无所谓，关掉透明后面板底色会是 frappe 的灰）。真要用别的主题再给它加分支（tokyonight 是 `require("tokyonight.colors").setup()`）。
- ~~启动耗时剖析~~：**已做（2026-09-13）** —— 实测总启动 ≈ 20ms，最大项是 `require("config.lazy")` ≈ 8.6ms、`config.autocmds` ≈ 0.13ms，没有值得优化的项。
