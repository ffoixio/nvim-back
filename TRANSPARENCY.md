# 背景透明：机制 · 结构 · 诊断手册

> 透明化牵涉的高亮组很多，**出问题不要靠猜**。这份文档记录机制、当前结构与一条可复现的诊断流程。
> 代码只有一处总表：`lua/util/transparency.lua`（142 行）。

## 0. 一句话机制

Neovim 只能做两件事之一：**画背景**，或者**完全不画**（`bg = NONE`）。它**没有**百分比透明度；
所谓 90%/95% 来自**终端模拟器自己的 opacity**——只有 Neovim 不画背景的地方，终端的透明度才看得见。

## 1. 三个概念别混

| | 作用对象 | 「混合」的对象 | 归属 |
|---|---|---|---|
| `transparent_background` | 编辑器主体（`Normal` 等） | 不混合，直接**不画** → 露出**终端底色/壁纸** | 配色方案选项 |
| `winblend` | 浮动窗口 | 浮窗背景 ↔ **编辑器里它背后的内容** | Neovim 选项（窗口局部，0-100） |
| `pumblend` | 补全菜单 | 同上 | Neovim 选项（全局，0-100） |

- `winblend > 0` 必然出现「两层字叠在一起」（跟底色无关）→ 本配置**保持 0**。
- 浮窗是**替换**格子，不是叠加：`bg = NONE` 的浮窗不会露出底下的代码，只会露出终端底色。

## 2. 当前结构（只有一处总表）

`lua/util/transparency.lua` 里两张表，是唯一的事实来源：

- `M.follow`：跟着透明状态走的组，格式 `{组名, 字段, 透明时的值, 不透明时的值}`
- `M.always_opaque`：**透明模式下仍强制实底**的例外，格式 `{组名, 字段, 值}`；**默认为空**。
  早期版本把 picker / lazy / 通知这些都钉在这里，结果是"遇到一个浮窗补一条"；现在它们统一走 `M.follow`
  （所有浮窗底色都来自 `NormalFloat` / `Pmenu` 两个根），只有确实看不清的才加回这张表一行。
- 值只写两种：**catppuccin 调色板键名**（`base`/`mantle`/`surface0`…）或 `"NONE"`

两个消费者读同一张表：

1. **编译期**：`lua/plugins/colorscheme.lua` 的 `custom_highlights(colors)` 遍历这两张表；
2. **运行时**：`M.apply(on)`（`<leader>uT` 开关走 `M.set`，会额外写状态文件）；
   另外 `VeryLazy` 时会再 `apply` 一次兜底（见坑 1）。

状态：文件 `stdpath("state")/transparent_background`（`true`/`false`）；没有文件时 `M.default()` 返回 `true`。

## 3. 硬规则（每条都是实测结论）

### 坑 1（最重要）：`default = true` 会盖掉「只有 bg」的组

插件常这样建自己的高亮：

```lua
vim.api.nvim_set_hl(0, "WhichKeyNormal", { link = "NormalFloat", default = true })
```

而 Neovim 把「只设了 `bg = NONE`、没有其它属性」的组当成**未定义** → `default = true` 照样覆盖 ✗。
实测对照：

```
设 bg=NONE  → 再被 default=true 的 link 覆盖 → 被盖掉 ✗
带 fg 的组   → 再被 default=true 的 link 覆盖 → 盖不动 ✓
```

**结论：凡是会被插件用 `default = true` 链接的组，覆盖时必须连 `fg` 一起写死**（表里就是同一个组写两行）。
已知这类组：`WhichKeyNormal` / `WhichKey`（which-key）、`SnacksNormalNC` / `FloatFooter`（默认 link 别的组）。

### 坑 2：面板默认也透明（"默认透明 + 例外"）

早期版本认为 picker / lazy / 补全菜单 / 通知「盖在代码上」，一律强制实底 —— 代价是每装一个新插件
都要手动补一条，而且随时可能漏（漏了就是"某处莫名一块底色"）。现在改成：

- **默认跟随开关**：一切浮窗底色都来自 `NormalFloat` / `Pmenu` 两个根，接进 `M.follow` 即可全覆盖；
- **例外显式列出**：确实看不清的（两层字叠一起）才写进 `M.always_opaque`，一行搞定，且默认是空表。

注意：`always_opaque` 之外还有两处"看起来是实底"的，那是有意为之、不在这个机制里 ——
picker 的选中行（链接到 `Visual`）与 DBUI 侧栏（`NormalSB`，见 `plugins/lang/sql.lua`）。

### 坑 3：查插件的底色组要看它的 `winhighlight`

浮窗的底色 = 该窗口 `winhighlight` 里映射的 `Normal`。例：

- which-key：`which-key/win.lua` 里 `"Normal:WhichKeyNormal,..."` → 管背景的是 **WhichKeyNormal**，不是 `WhichKey`。
- snacks：`snacks/win.lua` 里 `"Normal:SnacksNormal,NormalNC:SnacksNormalNC,..."`。
- **scratch 风格例外**：`snacks/scratch.lua` 把整串换成 `"NormalFloat:Normal"`，于是 `FloatTitle`/`FloatFooter`
  不再映射到 `Snacks*`，直接用了全局组（主题里带 mantle 底）→ 那就是标题/页脚那两块色块。

### 坑 4：边框 `FloatBorder` 的底色留空 = 跟随所属浮窗自身背景

留空时：picker（实底）边框跟着实底 ✓，scratch/terminal（内容透明）边框也跟着透明 ✓，不再有一圈色块。

### 坑 5：catppuccin 的编译缓存

`M.load()` **只在缓存文件不存在时**才编译（`catppuccin/init.lua:138`）；缓存哈希由配置结构算出，
所以**同一次会话内**改开关再 `:colorscheme` 不会重编译（实测无效），**新会话**才会重编（缓存 mtime = 启动时刻）。
→ 运行时开关必须直接改高亮组（`M.apply`），不能靠重新上色。

### 坑 6：`screenattr()` 必须先 `redraw`

没 redraw 时返回 `-1`、`screenstring()` 返回空串，会让人误判成「没有 UI」。

## 4. 诊断流程（照做，不用猜）

### Step 1 — 先确认状态

```vim
:lua =require("util.transparency").enabled()          " 当前实际状态
:lua =require("util.transparency").default()          " 启动默认（读状态文件）
:lua =vim.api.nvim_get_hl(0, { name = "Normal" })      " bg = nil 才是透明
```

### Step 2 — 列出所有「还在画背景」的组

```vim
:lua for _,g in ipairs(vim.fn.getcompletion("","highlight")) do local h=vim.api.nvim_get_hl(0,{name=g}) if h.bg then print(g,h.bg) end end
```

把前缀换掉（`g:match("^Snacks")` 之类）可以只看某一类。**注意**：`h.bg` 为 nil 也可能是「被清成 NONE」，见 Step 3。

### Step 3 — 屏幕级判定（读实际渲染，金标准）

在真实终端里、**which-key 弹出来的时候**跑：

```lua
vim.cmd("redraw")                                   -- 必须，见坑 6
local names = { [2698300] = "mantle", [3159110] = "base", [2303540] = "crust", [4277593] = "surface0" }
local function decode(r, c)
  local a = vim.fn.screenattr(r, c)
  local h = vim.api.nvim_get_hl_by_id(a, true)
  if h.background == nil or h.background == -1 then return "透明" end
  return names[h.background] or ("bg=" .. h.background)
end
for _, w in ipairs(vim.api.nvim_list_wins()) do
  if vim.api.nvim_win_get_config(w).relative ~= "" and vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "wk" then
    local p, wd = vim.api.nvim_win_get_position(w), vim.api.nvim_win_get_width(w)
    print("面板行", p[1], "左/中/右:", decode(p[1] + 1, p[2] + 1), decode(p[1] + 1, p[2] + wd // 2), decode(p[1] + 1, p[2] + wd - 2))
  end
end
```

面板里的**空白单元**如果解码出「透明」，就说明 Neovim 那一侧没画背景；如果解码出 mantle/base，就是真在画。

### Step 4 — 染色确认因果

把候选组临时改成一个刺眼颜色，再跑 Step 3 看那个单元的属性变不变：

```vim
:lua vim.api.nvim_set_hl(0, "WhichKeyNormal", { fg = 16777215, bg = 16711680 })
```

变了 → 就是它；没变 → 换下一个候选（`NormalFloat` / `Pmenu` / 插件的其它组）。

## 5. 新增一个组的流程

1. 用 Step 2 找出候选（谁还在画背景）；
2. 用 Step 3 + Step 4 确认它**真的**在画；
3. 决定归类：跟着透明走 → `M.follow`；始终实底 → `M.always_opaque`；
4. 加一行，并写一句 `NOTE:` 说明「它是谁、为什么」（`<leader>st` 能列出来）；
5. **若该组会被插件用 `default = true` 链接，补一行 `fg`**（坑 1）；
6. 验证：`<leader>uT` 来回切两次，两个方向都要对（见下面探针）。

## 6. 现成验证探针

```lua
local function show(g)
  local h = vim.api.nvim_get_hl(0, { name = g })
  local link = vim.api.nvim_get_hl(0, { name = g, link = true }).link
  print(g, "bg=" .. tostring(h.bg), "fg=" .. tostring(h.fg), "link=" .. tostring(link))
end
local T = require("util.transparency")
show("WhichKeyNormal")                 -- 期望 bg=nil 且 fg 有值（有 fg 才防得住坑 1）
T.apply(true)   ; show("WhichKeyNormal")
T.apply(false)  ; show("WhichKeyNormal")
vim.api.nvim_set_hl(0, "WhichKeyNormal", { link = "NormalFloat", default = true })
show("WhichKeyNormal")                 -- 期望仍然是 bg=nil + fg（盖不动）
```

## 7. 文件清单

| 文件 | 职责 |
|---|---|
| `lua/util/transparency.lua` | 总表 + `apply/set/default/enabled` + VeryLazy 兜底 |
| `lua/plugins/colorscheme.lua` | 编译期：`custom_highlights` 遍历总表；透明开关在文件顶部 |
| `lua/config/options.lua` | `winblend = 0` / `pumblend = 0`（必须保持 0，见坑 3/1 节） |
| `lua/config/keymaps.lua` | `<leader>uT` 开关（Snacks.toggle，调 `util.transparency`） |
| `~/.local/state/nvim/transparent_background` | 记住的开关状态（`true`/`false`） |

## 8. 换主题（`config/theme.lua` 里改 `active`）时要注意两件事

1. **透明选项名各主题不同**：`M.themes.<主题>.transparent(on)` 里已经为六个主题各写了一份片段
   （`transparent_background` / `transparent` / `styles.transparency` / `options.transparent` /
   `transparent_mode` / `transparent_background_level`）。换到没实测过的主题时，先确认这一项真的生效。
2. **`palette()` 目前只认 catppuccin**：它从 `vim.g.colors_name` 的 `catppuccin-XXX` 后缀取 flavour，
   换别的主题会**静默拿到 frappe 的调色板** —— 开着透明时无所谓（值都是 `NONE`），但关掉透明后
   面板底色会是 frappe 的灰，而不是当前主题的。真要长期用别的主题，就给 `palette()` 加分支
   （tokyonight 是 `require("tokyonight.colors").setup()`），见 `TODO.md`。

## 9. 保持不变成屎山的三条约束

1. **只有一张表**：所有透明相关的高亮组都在 `M.follow` / `M.always_opaque`，不要在各处写特判；
2. **两个入口读同一张表**：编译期（`custom_highlights`）与运行时（`M.apply`），不许各写一份；
3. **每条都有 NOTE**：说明它是谁、为什么这么处理，否则下次没人（包括 AI）能判断该不该动。
