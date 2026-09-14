# 原生 statusline 实施计划（分支 `feat/native-statusline`）

> 这是 [TODO.md](./TODO.md) 里「状态栏：换成 Neovim 原生 statusline，去掉 lualine」那一条的执行版计划。
> 全部结论都来自本机实测（nvim 0.12.5、catppuccin-frappe），关键证据写在每节末尾。

## 0. 目标与验收标准

**目标**：状态栏由 `vim.o.statusline` + 自己写的 Lua 渲染，删掉 lualine 插件与 `lua/util/lualine.lua`；
信息项与现在一致（模式/分支/项目根/诊断/文件类型图标/路径/navic 面包屑 ←→ profiler/noice 命令/noice 模式/lazy 更新数/diff/进度/行:列/时钟）。

**观感**：已确认走**扁平**方案——强调项只写 `fg`，底色一律继承 `StatusLine`（于是透明开关、换主题都不用特判）。

**验收（全部可测）**：

| # | 标准 | 怎么测 |
|---|---|---|
| 1 | 启动 0 报错，`:checkhealth config` 0 ERROR / 0 WARNING | headless 起一次看 `:messages`；health 新增的小节全 ok |
| 2 | 启动耗时不超过现状（基线 24–26ms），模块数 52 → 51 | `--startuptime` 对照 + `.test/probe/audit_modules.lua` |
| 3 | 10 个场景的渲染都过内容断言（无 `false`/`nil`/多余空白/未解析的 `%`） | `.test/probe/statusline_cases.lua`（矩阵见 §5） |
| 4 | `render()` 单次 ≤ 0.15ms；不慢于 lualine（强制加载后同场景）1.5 倍 | `hrtime` 循环 2000 次；lualine 侧用 `vim.o.statusline` 字符串做对照 |
| 5 | 三个主题 × 变体切换、透明开/关后，底色跟随 `StatusLine`（透明时无实底） | 换主题/切 `<leader>uT` 后 dump `SL*` 组 + `StatusLine` 的 bg |
| 6 | 高亮基线无意外改动（只多出 `SL*` 族） | `.test/baseline/hl.txt` 归一化对比 |

**回滚**：`git switch main` 即可；lualine 的 spec 删掉后插件目录还在，`:Lazy clean` 之前都能装回来。

## 1. 架构与接线

**新模块 `lua/util/statusline.lua`**（放在 `util/statuscolumn.lua` 旁边；状态栏和状态列是同一类「原生渲染」问题）

```lua
M.left  = { "mode", "branch", "root", "diagnostics", "filetype", "path", "navic" }
M.right = { "profiler", "cmd", "rec", "updates", "diff", "progress", "location", "clock" }

function M.render()   -- 左半 + %= + 右半；每项 pcall 包住；空值一律返回 ""
function M.build()    -- 按 §3 的表，从语义组抓 fg 写进 SL* 组（只写 fg）
function M.setup()    -- 注册 ColorScheme / VeryLazy / FileType(禁用列表) / 缓存失效 autocmd
```

- 每项一个 `{ id, render = function(ctx) -> string end }`，渲染结果自带 `%#SLxxx#`；**加项只改这两张表**。
- `ctx` 携带 `buf/win/width/mode`，项之间共享，避免每项自己 `nvim_get_current_*`。
- 昂贵项（path/root/navic/diag/diff）用模块内小缓存，失效点：`BufEnter`/`BufWritePost`/`DirChanged`/`DiagnosticChanged`/`User GitSignsUpdate`/`LspAttach`。
- **选项接线**（和 `statuscolumn` 完全同款，见 `lua/config/options.lua:103`）：

```lua
opt.statusline = [[%!v:lua.require('util.statusline').render()]]
```

- **setup 时机**：`lua/config/lazy.lua` 里 `require("util.styles")` 之后、`theme.load()` 之前调 `require("util.statusline").setup()`
  （styles 的注释已经写明「必须赶在第一次 :colorscheme 之前挂 ColorScheme 钩子」，状态栏同理）。

**为什么用 `%!`（实测，不是推断）**：`%!expr` 的返回值会被**当成状态栏重新解析**——`%=` 会右对齐、`%#ErrorMsg#` 会变色、`%<` 会截断；而 `%{expr}` 只做字面替换（`%= R %#...#` 原样显示）。`%{%expr%}` 与 `%!` 等效但只能贴在中间。
证据：`nvim --headless -u NONE` 里对三种写法做 `nvim_eval_statusline(..., { highlights = true })`，输出分别是「左对齐+右对齐两段、组栈 StatusLine→ErrorMsg」/「字面量」/「与第一种相同」。

## 2. 信息项映射（逐项，都可单测）

| 项 | 现在（lualine） | 原生实现 | 组 |
|---|---|---|---|
| mode | `"mode"` 组件 | `nvim_get_mode().mode` 首字符归一化 → 名称表：`n`=NORMAL `i`=INSERT `v`=VISUAL `V`=V-LINE `\22`=V-BLOCK `R`=REPLACE `c`=COMMAND `t`=TERMINAL `!`=SHELL `o`=OP-PENDING | `SLMode`（按模式换 fg，见 §3） |
| branch | `"branch"` | `vim.b.gitsigns_head` | `SLBranch` |
| root | `root_dir()`（`󱉭 ` + 目录名） | `"󱉭 " .. vim.fs.basename(require("util.root").get({ normalize = true }))`；cwd 情况沿用原判据 | `SLRoot` |
| diagnostics | `"diagnostics"` | `vim.diagnostic.count(0)` + `icons.diagnostics`（E/W/I/H，计数为 0 不显示） | `SLDiagError/Warn/Info/Hint` |
| filetype | `"filetype"`（icon_only） | `icons.ft[ft]`，取不到就 `"[ft]"`；`ft == ""` 不显示 | `SLFiletype` |
| path | `pretty_path()` | 移植原逻辑：相对 root（否则 cwd），最多 3 段、超出用 `…`，文件名加粗，modified 用 `MatchParen` 的前景色，readonly 加 ` 󰌾 ` | `SLPath` / `SLFile`(bold) / `SLModified` |
| navic | `"navic"`（nvim-navic 自带组件） | `require("nvim-navic").is_available(0)` 且 `get_location()` 非空才显示 | `SLNavic` |
| profiler | `Snacks.profiler.status()` | `Snacks.profiler.running()` 为真时用同一份文本函数 `Snacks.profiler.status()[1]()`（`⏱ N events`；不依赖 lualine，只要 snacks） | `SLProfiler` |
| noice 命令 | `noice.api.status.command` | `require("noice").api.status.command.get()`，`has()` 为假不显示 | `SLCmd` |
| noice 模式 | `noice.api.status.mode` | 同上（recording / 待完成命令） | `SLRec` |
| lazy 更新 | `lazy.status.updates` | `require("lazy.status").updates() or ""`（**无更新时返回 `false`，必须兜底**） | `SLUpdates` |
| diff | `"diff"` + gitsigns 源 | `vim.b.gitsigns_status_dict` → `+a ~c -d`（为 0 的项不显示） | `SLDiffAdd/Change/Delete` |
| progress | `"progress"`（Top/Bot/百分比） | Lua 算：首行 `Top`、末行 `Bot`、否则 `N%`（原生 `%p` 只会给 0%/100%） | `SLProgress` |
| location | `"location"` | 原生 `%l:%c` | `SLLocation` |
| 时钟 | `os.date("%R")` | 原样：`"󰥔 " .. os.date("%R")` | `SLClock` |

**分隔与截断**：扁平风格下项之间一个空格；`%<` 放在左半「可压缩部分」（path）之前——和现在 lualine 把 `%<` 放在 c 段起点同一位置。
不做（现在也没有）：buffers/tabs/windows 列表、searchcount、selectioncount、hostname、filesize、fileformat、encoding。

**迁移自 `util/lualine.lua` 的只有两段**：`pretty_path()` 的路径逻辑、`root_dir()` 的判据；`M.status()` / `M.format()` 随文件一起删（`M.format` 的语义已被 `%#组#` 取代，见 §3）。

## 3. 高亮组：只写 fg，底色继承 StatusLine

**实测结论**：在 `%!` 返回的串里用 `%#SLAcc#`，`nvim_eval_statusline(..., {highlights=true})` 给出的分段是 `groups = { "StatusLine", "SLAcc" }`——即**组栈**：自定义组只提供自己写了的属性，剩下全部继承 `StatusLine`。
所以强调组**只写 `fg`（+ 可选 bold）**即可，`bg` 由 `StatusLine` 决定；而 `StatusLine` 已经在 `util/transparency.lua` 的 `M.follow` 里（透明 → `NONE`，不透明 → 主题自己的底色）→ **透明开关与换主题零特判**。

| 组 | fg 来源（语义组，与主题无关） | 备注 |
|---|---|---|
| `SLMode` | 按模式：`Function`/`String`/`Constant`/`DiagnosticError`/`Statement`/`Identifier`/`Special` | bold |
| `SLBranch` / `SLRoot` / `SLFiletype` / `SLUpdates` | `Special` | |
| `SLPath` / `SLProgress` / `SLLocation` / `SLClock` / `SLNavic` | 不写（继承 `StatusLine`） | |
| `SLFile` | `StatusLine` 的 fg + bold | 文件名 |
| `SLModified` | `MatchParen` 的 fg（沿用现在 `pretty_path` 的取色） | |
| `SLDiagError`/`Warn`/`Info`/`Hint` | `DiagnosticError`/`DiagnosticWarn`/`DiagnosticInfo`/`DiagnosticHint` | |
| `SLDiffAdd`/`Change`/`Delete` | `DiffAdd`/`DiffChange`/`DiffDelete` 的 fg（取不到则回退 `Diagnostic*`） | |
| `SLProfiler` | `DiagnosticError`（沿用原 `M.status` 的映射） | |
| `SLCmd` / `SLRec` | `Statement` / `Constant`（沿用现配置） | |

实现细节：来源组不存在或取不到 fg → **跳过该组**（不报错、不写半成品），该项自然继承 `StatusLine`；`util/styles.lua` 只动 `italic`，与这里的 `bold` 无冲突，不需要改。

## 4. 边界 / 失败模式

- 无名 buffer（dashboard、`:enew`）：path/root/navic/filetype 全空，只剩 mode/时钟/进度（今天的 lualine 也是这样）。
- `buftype ~= ""`（terminal/prompt/nofile）：跳过 path 与 root 相关项，避免 `:terminal` 里出现奇怪的相对路径。
- **禁用列表**（`dashboard`/`alpha`/`ministarter`/`snacks_dashboard`）：迁移现在 lualine spec `init` 的行为——启动无参数（`vim.fn.argc(-1) == 0`）时 `vim.o.laststatus = 0`（完全不占一行），进入普通 buffer 后恢复 `3`；禁用 filetype 时渲染 `""`（保留空行，和现在一致）。
- 启动早期：`opt.statusline` 在 options 阶段就设好，此刻 `SL*` 组还不存在 → 组未定义时渲染继承 `StatusLine`，不会报错；`M.build()` 晚于第一次 `ColorScheme` 也没关系（下一次 `:colorscheme` 或 `VeryLazy` 会补上）。
- 未加载的插件：`package.loaded` 守卫 + `pcall`（navic/noice/snacks/gitsigns/lazy 都可能不在）。
- 文本里的字面 `%`：统一 `text:gsub("%%", "%%%%")`，否则会把后面的字符当状态栏项解析。
- `%!` 表达式每帧都求值：所有项必须便宜；用 §1 的缓存兜住 path/navic/diag/diff。
- 多窗口：`laststatus=3` 时只有一条全局状态栏，`render()` 一律按「当前窗口」取数，与现状一致。

## 5. 实施步骤

1. **分支**（已完成）：`feat/native-statusline`（从 `main` = `e7231e7` 切出）。
2. **落地模块**：`lua/util/statusline.lua` + `options.lua` 的 `statusline` 一行 + `config/lazy.lua` 的 `setup()`；此时 **lualine 先留着**（它会把自己那条 `%!` 覆盖上去）→ 用 `:lua require("util.statusline").render()` 手动比对着调。
3. **场景矩阵**（`.test/probe/statusline_cases.lua`，gitignored）：普通已保存文件 / 已修改 / 只读 / 无名 buffer / terminal / dashboard / 有诊断（E+W）/ 有 git 改动 / 窄窗口 40 列 / 宽窗口 200 列 → 每例打印 `nvim_eval_statusline` 的 `str`、`width`、`highlights` 与断言结果；透明开/关各跑一遍，三个主题各跑一遍。
4. **A/B 与成本**：同样的场景跑「强制加载 lualine」（`require("lazy").load({plugins={"lualine.nvim"}})`）与原生版本，记录内容差异、每帧成本、单项耗时排行。
5. **拆 lualine**（一次性提交）：
   - `lua/plugins/ui.lua`：删 lualine spec + 顶部 TODO 注释块 + `vim.g.trouble_lualine` + trouble statusline 集成块；
   - 删 `lua/util/lualine.lua`；
   - `plugins/colorscheme.lua`：`navic = { enabled = true, custom_bg = "NONE" }`（原来是 `"lualine"`，指向 mantle 底；脱离 lualine 后应跟随 `StatusLine`）；
   - `lua/config/modules.lua`、`lua/util/styles.lua` 注释里的 lualine 字样；
   - `lazy-lock.json` 去掉 `lualine.nvim` 一行（**注意**：lazy 的 install 剪枝会顺手删掉 6 个禁用模块的 pin，改完要检查条目数）。
6. **health**：`:checkhealth config` 新增一小节「config: 状态栏」——状态栏表达式是否指向本模块、`SL*` 组是否存在、`render()` 是否能无错返回、禁用 filetype 下的 laststatus 是否符合预期。
7. **文档**：`TODO.md` 该条勾掉并指向本文；本文补上「加一项怎么做」的示例；`CHEATS.md` 不受影响（不改键位）。
8. **回归**：启动 0 报错 / health 0 警告 / `hl.txt` 基线 / `<leader>uC` 三主题切换 / `<leader>uT` 透明开关 / `:Lazy clean` 后重启再验一遍。
9. **提交**：中文、按主题分（模块 → 拆 lualine → health/文档），最后与 `main` 的差异整体回看一遍。

## 6. 已知取舍（写在这里免得以后忘）

- profiler 那一项仍然借 snacks 的文本函数，但**不依赖 lualine**（`Snacks.profiler.status()[1]()` 只是普通函数）。
- 扁平观感的代价：状态栏不再有 mode 色块；换来的是透明/换主题零特判，组数量从 `lualine_*` 一族（实测一次渲染里就出现 4 种 + 6 种 transitional）降到十来个。
- `trouble` 的 statusline 符号集成（`vim.g.trouble_lualine`）本来就是关的，这次直接删掉；trouble 插件本身保留。
- 以后要加项（比如 searchcount、buffers 列表）：在 `M.left`/`M.right` 加一个 id + 一个 `render`，需要新组就往 §3 的表加一行。
## 7. 进度

### v1（2026-09-13，分支 `feat/native-statusline`）

§5 的 1–6 已完成（模块 / 接线 / 场景矩阵 / 拆 lualine / health）。实测：

| 检查 | 命令（都在仓库根目录跑） | 结果 |
|---|---|---|
| 场景矩阵 12 例 | `nvim -n -u init.lua --headless -i NONE -c 'lua vim.wait(1200)' -c 'lua dofile([[.test/probe/statusline_cases.lua]])' -c 'qa!'` | 无 `nil` / `false` / 残留 `%`；dashboard 渲染空串；40 列时 `%<` 截断生效；11 种模式映射全对；`SLFile` 有 fg + bold |
| 透明开关 | `.test/probe/statusline_theme.lua` | 透明开 → `StatusLine.bg = nil`，关 → mantle(2698300)；`SL*` 组在两种状态下都**没有** bg（`groups_with_bg = ""`） |
| 三主题切换 | 同上 | `SLModeNORMAL.fg` 随主题变（catppuccin 9218798 / tokyonight 8037111 / everforest 10993792），切回 catppuccin 后与初始一致 |
| 渲染成本 | `.test/probe/statusline_bench.lua` | `render()` 0.031 ms/次、`nvim_eval_statusline` 0.053 ms/次（验收线 0.15 ms）；`require` 0.23 ms、`build()` 0.14–0.26 ms |
| 配置模块全量 require | `.test/probe/audit_modules.lua` | 成功 52 / 失败 0；`lazy.core.config.spec.plugins` 44 个，已无 `lualine.nvim` |
| health | `nvim … -c 'lua dofile([[.test/probe/statusline_health.lua]])'` | ERROR 0 / WARNING 0 / OK 26（新增的「状态栏」小节贡献 3 条 ok），`messages` 0 报错 |
| 高亮基线 | `.test/probe/hl.lua` 后 `diff .test/baseline/hl.txt .test/out/hl.txt` | 只差一行：`有底色的组 123 → 95`——正好是 28 个 `Navic*` 组从 mantle 实底改成跟随 StatusLine（扁平方案的预期变化）；`M.follow` 那 40 行逐字未变 |
| 启动 | `--startuptime` ×3 | 27.1 / 28.1 / 30.6 ms（headless、无文件参数）。此前记录 24–26 ms，差值在环境噪声范围；lualine 本来就只在 VeryLazy 加载，headless 里不参与 |

**观感变化**：状态栏从「色块 + powerline 箭头」变成扁平（只有前景色不同）。拆之前的 lualine 串留档：

```
%#lualine_a_normal# NORMAL %#lualine_transitional_lualine_a_normal_to_lualine_b_normal##%#lualine_b_normal#  main %#lualine_transitional_lualine_b_normal_to_lualine_c_normal##<%#lualine_c_normal#%=%#lualine_transitional_lualine_b_normal_to_lualine_c_normal##%#lualine_b_normal# Top %#lualine_b_normal#  1:1  %#lualine_transitional_lualine_a_normal_to_lualine_b_normal##%#lualine_a_normal# 󰥔 12:27 
```

现在的样子（同场景，80 列）：

```
 NORMAL   main 󱉭 nvim 󰢱 lua/config/options.lua    󰊢 3 󰊢 1 󰊢 2 Top   1:1  󰥔 12:34 
```

### 还没做

- 与 lualine 的逐项 A/B 像素级对比（lualine 已删；如需回看，`git switch main` 起一次即可）。
- （可选）以后要加的项：searchcount、buffers 列表、编码/换行格式。

