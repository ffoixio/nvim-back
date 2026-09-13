# 快捷键手册（CHEATS）

> 数据来自**运行时 dump**（`nvim_get_keymap` 各模式，VeryLazy 之后），共 466 条，本文做了人工归类与筛选。
> 重新生成的方法见文末 §5。

## 0. 怎么用这份表 & 怎么自己查

- **`<leader>` = 空格**（`mapleader = <Space>`，`options.lua`）
- **模式记号**：未标注 = 普通模式 `n`；`[x]` = 可视模式也可用；另有 `i` 插入 / `c` 命令行 / `o` 操作符待定 / `t` 终端 / `s` 选择
- **随手查**：按 `<Space>` 弹出 which-key 分组；再按一层继续展开。弹窗内：`<esc>` 关闭、**`<bs>` 返回上一层**、`<c-d>`/`<c-u>` 滚动、`<c-w>` 进入窗口 Hydra
- 当前缓冲区专属键位：`<leader>?`；全部键位搜索：`<leader>sk`；原始列表：`:map`

## 1. 本配置对内置键的改动

| 键 | 作用 | 备注 |
|---|---|---|
| `j` / `k` | `gj` / `gk`（屏幕行移动） | 带计数时仍是真行；`v:count == 0` 才替换 |
| `H` / `L` | 上一个 / 下一个 buffer | 覆盖了内置的屏幕顶/底 |
| `<C-s>` | 保存 | `n` `i` `x` `s` 四个模式都有 |
| `<Esc>` | 清搜索高亮 | `n` 模式 |
| `q` / `Q` | `q` 无操作 / `Q` 录制宏 | 防误触；录制改到 `Q` |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | 左 / 下 / 上 / 右窗口 | 终端里这四个键归 shell（见 §4 末尾） |
| `<M-j>` / `<M-k>` | 上下移动行 | `i` `x` 模式 |
| `[` / `]` | 上方 / 下方添加空行（无计数时） | 之后接 `t` `h` `n` `q` `l` 等组成跳转 |
| `<C-a>` / `<C-x>` | 数字 +1 / -1（dial.nvim 增强） | 支持日期、true/false 等 |
| `p` `P` `gp` `gP` `y` `Y` | 粘贴/复制走 yanky 历史 | `n` `x` 模式 |
| `<C-Space>` | Treesitter 增量选择 | `n` `x` `o` |
| `<C-s>`（`i` `s`） | 保存 | 覆盖了 nvim 默认的 LSP 签名帮助；插入模式要签名帮助用 `<C-k>` |
| `[t` / `]t` | 上一个 / 下一个 TODO 注释 | 覆盖了内置 tag 跳转（`:tprevious` / `:tnext`） |
| `[B` / `]B` | 移动 buffer 位置 | 覆盖了内置 `:brewind` / `:blast` |
| `[b`/`]b`、`[q`/`]q`、`[d`/`]d` | buffer / quickfix / 诊断跳转 | 覆盖了内置同名动作（语义相近，desc 以插件为准） |

其余为 Neovim 原生，完整清单见 `:h quickref`。

**关于 `an` / `in`（`x` `o` 模式）**：这两个键 nvim 0.12 **核心自带**（`vim/_core/defaults.lua`），
语义是"按语法节点逐级扩选/回缩"，没有语法树时退回 `vim.lsp.buf.selection_range`（LSP 选择范围兜底）。
mini.ai 在 VeryLazy 会用同一个键覆盖它们，所以**实际生效的是 mini.ai 那套**（"下一个/上一个文本对象的
外面/里面"）—— 两者键位相同、语义不同，被覆盖是预期内的，不需要处理。
核心那套并没有消失：可视模式的 `[n` / `]n`（上/下一个节点）、`[N` / `]N`（上/下一个兄弟节点）
没有冲突，照样可用；另外 `<C-Space>`（flash）做的是增量选择，和它们互补。

## 2. `<leader>` 命名空间（与 which-key 的组一一对应）

### `<leader>b` — buffer（10）

| 键 | 说明 |
|---|---|
| `<leader>bb` | 切换到上一个 buffer |
| `<leader>bd` | 删除 buffer |
| `<leader>bD` | 删除 buffer 并关窗 |
| `<leader>bo` | 删除其它 buffer |
| `<leader>bl` / `<leader>br` | 删除左侧 / 右侧 buffer |
| `<leader>bi` | 删除不可见 buffer |
| `<leader>bP` | 删除未 pin 的 buffer |
| `<leader>bp` | pin / 取消 pin |
| `<leader>bj` | 用 picker 选 buffer |

### `<leader>c` — code（8）

| 键 | 说明 |
|---|---|
| `<leader>cf` | 格式化（`[x]` 可视模式也可用） |
| `<leader>cF` | 格式化注入的语言（如 markdown 里的代码块） |
| `<leader>cd` | 当前行的诊断 |
| `<leader>cs` | 符号列表（Trouble） |
| `<leader>cS` | 引用/定义等（Trouble） |
| `<leader>cm` | 打开 Mason |

### `<leader>d` — direnv / profiler（7）

| 键 | 说明 |
|---|---|
| `<leader>da` / `<leader>dd` | 允许 / 拒绝 direnv |
| `<leader>de` / `<leader>dr` | 编辑 `.envrc` / 重载 direnv |
| `<leader>dpp` | 开关 profiler |
| `<leader>dph` | 开关 profiler 高亮 |
| `<leader>dps` | 打开 profiler 的 scratch |

### `<leader>f` — file / find（13）

| 键 | 说明 |
|---|---|
| `<leader>ff` | 找文件（项目根） |
| `<leader>fF` | 找文件（当前目录） |
| `<leader>fg` | 只在 git 跟踪的文件里找 |
| `<leader>fb` / `<leader>fB` | buffer 列表 / 全部 buffer |
| `<leader>fR` | 最近文件（当前目录） |
| `<leader>fc` | 找配置文件 |
| `<leader>fC` | 打开本配置目录 |
| `<leader>fn` | 新建文件 |
| `<leader>fe` / `<leader>fE` | 文件树（项目根 / 当前目录） |
| `<leader>ft` / `<leader>fT` | 浮动终端（项目根 / 当前目录） |

### `<leader>g` — git（18）

| 键 | 说明 |
|---|---|
| `<leader>gg` / `<leader>gG` | Lazygit（项目根 / 当前目录） |
| `<leader>gb` | 当前行的 blame |
| `<leader>gd` | 差异（hunks） |
| `<leader>gD` | 与 origin 的差异 |
| `<leader>gl` / `<leader>gL` | git log（项目 / 当前目录） |
| `<leader>gf` | 当前文件的历史 |
| `<leader>gs` | git status |
| `<leader>gS` | stash |
| `<leader>gY` / `<leader>gB` | 复制 / 打开当前行的远端链接 |
| `<leader>gi` / `<leader>gI` | GitHub issue（打开的 / 全部） |
| `<leader>gp` / `<leader>gP` | GitHub PR（打开的 / 全部） |

### `<leader>h` — harpoon（11）

| 键 | 说明 |
|---|---|
| `<leader>ha` | 把当前文件加入 harpoon |
| `<leader>hm` | 打开 harpoon 快速菜单 |
| `<leader>h1` … `<leader>h9` | 跳到第 1–9 个标记文件 |

### `<leader>m` — metals（Scala）（3）

| 键 | 说明 |
|---|---|
| `<leader>mc` | Metals: compile cascade |
| `<leader>me` | Metals: 命令列表（自选） |
| `<leader>mh` | Metals: hover worksheet |

### `<leader>q` — quit / session（3）

| 键 | 说明 |
|---|---|
| `<leader>qs` | 保存会话（可命名，留空 = 默认槽位、同名覆盖） |
| `<leader>qS` | 选择要打开的会话 |
| `<leader>qq` | 退出全部 |

### `<leader>s` — search（37）

| 键 | 说明 |
|---|---|
| `<leader>sg` / `<leader>sG` | Grep（项目根 / 当前目录） |
| `<leader>sw` / `<leader>sW` | 搜索光标下的词 / 选区（项目根 / 当前目录，`[x]`） |
| `<leader>sb` | 搜索当前 buffer 的行 |
| `<leader>sB` | 在打开的 buffer 里 grep |
| `<leader>sr` | 搜索并替换（grug-far，`[x]`） |
| `<leader>sd` / `<leader>sD` | 工作区诊断 / 当前 buffer 诊断 |
| `<leader>st` / `<leader>sT` | Todo（全部关键词 / 仅 TODO·FIX·FIXME） |
| `<leader>sq` / `<leader>sl` | Quickfix / Location list |
| `<leader>sh` / `<leader>sM` | 帮助页 / man 手册 |
| `<leader>sk` | 键位搜索 |
| `<leader>sC` / `<leader>sc` | 命令列表 / 命令历史 |
| `<leader>s/` | 搜索历史 |
| `<leader>s"` | 寄存器 |
| `<leader>sm` | marks |
| `<leader>sj` | 跳转列表 |
| `<leader>sa` | autocmds |
| `<leader>si` | 图标 |
| `<leader>su` | undo 树 |
| `<leader>sH` | 高亮组 |
| `<leader>sp` | 搜索插件规格 |
| `<leader>sn…` | noice 子菜单：`sna` 全部 / `snh` 历史 / `snl` 最后一条 / `snd` 清空 / `snt` picker |
| `<leader>sR` | 恢复上一次搜索 |

### `<leader>u` — ui（26）

| 键 | 说明 |
|---|---|
| `<leader>uT` | 透明背景（会记住状态） |
| `<leader>ua` | Mini Animate（mini.animate 的动画） |
| `<leader>uA` | Snacks Animate（snacks 自己的动画开关，`vim.g.snacks_animate`） |
| `<leader>uH` | Treesitter 高亮开关 |
| `<leader>uC` | 主题/变体选择：选中**即记住**（写 `stdpath("state")/theme`，重启沿用）；复位 `:lua require("config.theme").reset()` |
| `<leader>uF` / `<leader>uf` | 自动格式化（当前 buffer / 全局） |
| `<leader>ud` | 诊断显示 |
| `<leader>us` | 拼写检查 |
| `<leader>uw` / `<leader>ul` / `<leader>uL` | wrap / 行号 / 相对行号 |
| `<leader>uc` | conceal 级别 |
| `<leader>ug` | 缩进参考线 |
| `<leader>uh` | inlay hints（LSP） |
| `<leader>up` | Mini Pairs |
| `<leader>uS` | 平滑滚动（smoothscroll） |
| `<leader>ub` | 深色/浅色背景 |
| `<leader>uD` | dim 非活动窗口 |
| `<leader>uB` | tabline（B = tab Bar；原在 `uA`） |
| `<leader>uZ` / `<leader>uz` | Zoom / Zen 模式 |
| `<leader>ui` / `<leader>uI` | Inspect pos / tree |
| `<leader>un` | 清空通知 |
| `<leader>ur` | 重绘 + 清搜索高亮 + diff 更新 |

### `<leader>w` — windows（2）

| 键 | 说明 |
|---|---|
| `<leader>wd` | 关闭窗口 |
| `<leader>wm` | Zoom 切换 |

### `<leader>x` — diagnostics / quickfix（8）

| 键 | 说明 |
|---|---|
| `<leader>xx` / `<leader>xX` | 诊断（工作区 / 当前 buffer）→ Trouble |
| `<leader>xq` / `<leader>xQ` | Quickfix（普通 / Trouble） |
| `<leader>xl` / `<leader>xL` | Location list（普通 / Trouble） |
| `<leader>xt` / `<leader>xT` | Todo（全部 / 仅 TODO·FIX·FIXME）→ Trouble |

### 单键（不属于任何组）

| 键 | 说明 |
|---|---|
| `<leader><Space>` / `<leader>/` | 找文件 / grep（项目根） |
| `<leader>,` | buffer 列表 |
| `<leader>e` / `<leader>E` | 文件树（项目根 / 当前目录） |
| `<leader>l` | Lazy |
| `<leader>n` | 通知历史 |
| `<leader>:` | 命令历史 |
| `<leader>p` | yank 历史（`[x]`） |
| `<leader>`` | 切换 buffer |
| `<leader>.` / `<leader>S` | scratch buffer（切换 / 选择） |
| `<leader>|` / `<leader>-` | 右分屏 / 下分屏 |
| `<leader>D` | DBUI 开关（数据库） |
| `<leader>K` | `'keywordprg'`（当前词查 man；Lua 里会报错，见下） |
| `<leader>R` | 重启 Neovim（= 重载配置；lazy.nvim 不支持原地重载，有未保存缓冲区时会先提示） |
| `<leader>T` | Vim 教程（中文） |
| `<leader>?` | 当前缓冲区的键位 |
| `<leader><Tab>…` | 页签子菜单：`<Tab><Tab>` 新建 / `[` `]` 上/下一个 / `d` 关闭 / `f` `l` 首/末 / `o` 关闭其它 |

## 3. 插件自带（非 `<leader>`）

| 键 | 来源 | 说明 |
|---|---|---|
| `s` / `S` | flash.nvim | 跳转 / Treesitter 跳转（`n` `x` `o`） |
| `r` / `R` | flash.nvim | Remote Flash / Treesitter 搜索（`o` `x`） |
| `gsa` `gsd` `gsr` | mini.surround | 添加 / 删除 / 替换包围（`n` `x`） |
| `gsf` `gsF` `gsh` `gsn` | mini.surround | 找右/左包围、高亮、更新行数 |
| `i` / `a` | mini.ai | 文本对象（`i` 内 / `a` 外）；`il` `in` / `al` `an` 上/下一个 |
| `gc` | 内置 + mini.ai | 注释（`n` `x`） |
| `]n` `[n` `]N` `[N` | treesitter-textobjects | 下一个/上一个节点、兄弟节点（`n` `x` `o`） |
| `]t` `[t` | todo-comments | 下一个 / 上一个 TODO 注释 |
| `<C-Space>` | nvim-treesitter | 增量选择（`n` `x` `o`） |
| `y` `p` `P` `gp` `gP` `Y` | yanky | 复制/粘贴走历史（`n` `x`） |
| `<C-a>` `<C-x>` | dial.nvim | 数字/日期/布尔 递增递减（`n` `x`） |
| `( ) [ ] { } " ' \`` | mini.pairs | 自动配对（`i` `c`） |
| `<CR>` `<BS>` | mini.pairs | 回车/退格智能处理（`i`） |
| `<Tab>` / `<S-Tab>` | snippet | 占位符跳转，无占位符时退回原行为（`i` `s`） |
| `<C-/>` / `<C-_>` | snacks | 终端（项目根）；终端里这四个键归 shell |
| `<C-W>` | which-key | Window Hydra（窗口操作小键盘） |

## 4. 终端里的特殊约定

终端是**真终端**（terminal mode），按键原样送给 shell，所以：

- `<C-h>` `<C-j>` `<C-k>` `<C-l>` 在**终端里**归 shell（Ctrl-L 清屏、Ctrl-K 删到行尾），离开终端后恢复为窗口跳转
- 单击 `<Esc>` 送给 shell；**200ms 内连按两次**才进 normal mode（normal 里 `q` 隐藏终端、`gf` 打开光标下文件、`[[`/`]]` 跳提示符）
- 收终端：`<C-/>`；shell 里 `exit` / Ctrl-D 直接关窗

## 5. 怎么重新生成这份表

```bash
# 1) 在项目根跑（只读，不改任何文件）
nvim -u init.lua --headless -i NONE \
  -c 'lua vim.wait(1200)' \
  -c 'lua vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })' \
  -c 'lua vim.wait(2500)' \
  -c 'lua local o={} for _,m in ipairs({"n","i","x","s","o","t","c"}) do for _,k in ipairs(vim.api.nvim_get_keymap(m)) do o[#o+1]=("%s\\t%s\\t%s\\t%s"):format(m,k.lhs,(k.rhs or ""):gsub("[\\r\\n]"," "),(k.desc or "")) end end vim.fn.writefile(o, "/tmp/maps.tsv")' \
  -c 'qa!'
# 2) 再按 §2 的分组（<leader> + 首字母）与 which-key 的组名整理成 md
# 注：VeryLazy 之后还有 toggle 是"插件加载时才注册"的（如 mini.animate、bufferline），
#     等待时间给到 2500ms 才不会漏；500ms 会少十几个键。
```

> 组名不在这份 dump 里（which-key 自己维护树），要改组名去配置里搜 `group = "…"`。
> `\`<leader>d\`` 的组名已改成 "direnv / profiler"（原先那条「待修」已解决）。
