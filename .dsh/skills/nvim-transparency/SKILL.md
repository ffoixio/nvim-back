---
name: nvim-transparency
description: 调试或扩展本配置的背景透明化时使用：出现「该透没透」「某处还是实底/色块」，或需要新增一个跟随透明状态的高亮组。
whenToUse: 用户报告 which-key / picker / lazy / 上下文粘行 / scratch / terminal / 边框等处仍有色块或仍是不透明时；或要往透明总表里加组时。
---

# 背景透明化（本项目专用）

## 三条硬事实（先确认，别猜）

1. Neovim 只能「画背景」或「完全不画」（`bg = NONE`）。**没有百分比**；90%/95% 来自终端模拟器自己的 opacity。
2. `winblend` / `pumblend` 是另一层：把浮窗/菜单与**它背后的编辑器内容**混色。只要 > 0 就会出现「两层字叠一起」→ 本项目保持 **0**（`lua/config/options.lua`）。
3. 浮窗是**替换**格子：`bg = NONE` 的浮窗不会露出底下代码，只会露出终端底色。

## 结构（改动只在一处）

- 总表：`lua/util/transparency.lua`
  - `M.follow` = `{组名, 字段, 透明时的值, 不透明时的值}`（跟着透明状态走）
  - `M.always_opaque` = `{组名, 字段, 值}`（透明模式下仍强制实底的**例外**，默认空表；
    普通浮窗一律走 `M.follow` —— 所有浮窗底色都来自 `NormalFloat` / `Pmenu` 两个根）
  - 值只写 catppuccin 调色板键名（`base`/`mantle`/`surface0`…）或 `"NONE"`；这两列只给**编译期**用，
    运行时（`M.apply`）改成快照式：`ColorScheme` 后抓一遍各组原值当「不透明值」，透明时写 `NONE`，
    所以运行时与主题无关（修之前它会拿 catppuccin 调色板去刷别的主题）
- 两个入口读同一张表：编译期 `lua/plugins/colorscheme.lua` 的 `custom_highlights`；运行时 `M.apply`（`<leader>uT` 走 `M.set`：写状态文件 → 应用 → 发 `User TransparencyChanged` → `config/theme.lua` 重配主题）。
- 切主题：`ColorScheme` 钩子里先 `M.snapshot()` 再 `M.apply(M.enabled())`；bufferline 的高亮也在同一个钩子里按新配色重算（否则标签栏会留着旧主题的颜色）。
- 状态文件：`stdpath("state")/transparent_background`（`true`/`false`），`M.default()` 读它。

## 最容易栽的坑（务必先查这条）

**插件用 `nvim_set_hl(0, "X", { link = "NormalFloat", default = true })` 建自己的组时，会把「只设了 `bg = NONE`」的组当成未定义直接盖掉**（Neovim 行为，已实测），于是浮层又变回实底。

对照实验（可复现）：

```lua
vim.api.nvim_set_hl(0, "T", { bg = "NONE" })
vim.api.nvim_set_hl(0, "T", { link = "Normal", default = true })
print(vim.inspect(vim.api.nvim_get_hl(0, { name = "T" })))  -- 变成 link ✗ 被盖了

vim.api.nvim_set_hl(0, "T2", { fg = 16711680, bg = "NONE" })
vim.api.nvim_set_hl(0, "T2", { link = "Normal", default = true })
print(vim.inspect(vim.api.nvim_get_hl(0, { name = "T2" }))) -- 仍是 fg ✓ 盖不动
```

→ **凡是被插件链接的组（which-key 的 `WhichKeyNormal`/`WhichKey`、snacks 的 `SnacksNormalNC`、`FloatFooter` 等），覆盖时必须连 `fg` 一起写死**（总表里同一个组写两行）。

## 诊断流程（必须按顺序，禁止直接改表试错）

**Step 1 确认状态**

```vim
:lua =require("util.transparency").enabled()   " 当前是否透明
:lua =require("util.transparency").default()   " 启动默认（读状态文件）
:lua =vim.api.nvim_get_hl(0, { name = "Normal" })  " bg = nil 才是透明
```

**Step 2 找出「谁还在画背景」**

```vim
:lua for _,g in ipairs(vim.fn.getcompletion("","highlight")) do local h=vim.api.nvim_get_hl(0,{name=g}) if h.bg then print(g,h.bg) end end
```

**Step 3 屏幕级判定（金标准，读实际渲染）**：在真实终端里让目标浮窗显示出来，然后

```lua
vim.cmd("redraw")  -- 必须；否则 screenattr 返回 -1
local w -- 找到目标浮窗：which-key 的 filetype 是 "wk"，其余看 filetype/bufname
for _, x in ipairs(vim.api.nvim_list_wins()) do
  if vim.bo[vim.api.nvim_win_get_buf(x)].filetype == "wk" then w = x end
end
local p, wd = vim.api.nvim_win_get_position(w), vim.api.nvim_win_get_width(w)
local a = vim.fn.screenattr(p[1] + 1, p[2] + wd // 2)
local h = vim.api.nvim_get_hl_by_id(a, true)
print(h.background)  -- nil / -1 = 没画背景；2698300 = mantle；3159110 = base
```

采样要取浮窗内的**空白单元**（`screenstring(r,c) == " "`）。

**Step 4 染色确认因果**（不确定是哪个组时）

```vim
:lua vim.api.nvim_set_hl(0, "候选组", { fg = 16777215, bg = 16711680 })
```

再跑 Step 3，看那个单元的属性变不变：变了就是它。

## 修复流程

1. 归类：**默认**加进 `M.follow`（跟着开关走）；只有"透了以后两层字看不清"的才进 `M.always_opaque`。
   判据：浮窗里是要盯着看的代码、而且盖在同类内容上。
2. 加一行 `{组名, 字段, 透明值, 不透明值}`，**并写一句 `NOTE:` 说明它是谁、为什么**（`<leader>st` 可列出）。
3. 被插件 `default = true` 链接的组：补一行 `fg`（见上）。
4. 验证：`<leader>uT` 来回切两次，两个方向都要对；再跑一次「盖不动」测试：

```lua
require("util.transparency").apply(true)
vim.api.nvim_set_hl(0, "WhichKeyNormal", { link = "NormalFloat", default = true })
print(vim.inspect(vim.api.nvim_get_hl(0, { name = "WhichKeyNormal" })))  -- 仍应 bg=nil 且 fg 有值
```

## 改完必须知道的两件事

- 配色由 catppuccin 编译缓存（`stdpath("cache")/catppuccin`）承载，且 `M.load()` 只在缓存缺失时才重编；**同一次会话内**改开关再 `:colorscheme` 不生效 → 运行时改动必须走 `M.apply`。
- 有的插件在配色之后才建自己的组（which-key 等），所以 `util/transparency.lua` 里有一条 `VeryLazy` 时再 `apply` 的兜底；新增同类插件时别忘了这条机制。

## 参考

- `TRANSPARENCY.md`（仓库根目录）：给人看的完整手册，含全部踩坑记录、概念对照表与文件清单。
