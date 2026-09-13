# 配置审计报告 — 2026-09-13

> **状态：某日快照** —— 其中的行号 / 数量 / 清单只代表当天，之后不再维护；
> 需要最新状态请跑 `:checkhealth config`（语言就绪度、模块登记、终端/复用器都在那里）。

> 每项都写了可复现的检查方式；结论分「必修 / 建议 / 记 TODO」。

## 1. 总览

| # | 检查项 | 方式 | 结论 |
|---|---|---|---|
| C1 | 自带健康检查 | `:checkhealth config` | ✅ 全绿 |
| C2 | 插件规格结构 | health 的静态扫描 | ✅ 无顶层裸规格 |
| C3 | 键位自洽 | health | ✅ 101 个 leader 映射：无冲突、无缺 desc、无「既是动作又是前缀」 |
| C4 | 语言就绪度 | health（14 个语言） | ✅ 全 OK |
| C5 | mason 声明 vs 实装 | 脚本对账 | ⚠️ 1 个孤儿 → 记 TODO |
| C6 | treesitter 声明 vs 实装 | 脚本对账 | ⚠️ 5 个孤儿 → 记 TODO |
| C7 | 运行时错误扫描 | `~/.local/state/nvim/{nvim,lsp}.log` | ✅ 无错误模式；dadbod 那条已修（§4） |
| C8 | 快捷键清单 | 运行时 dump | ⏳ 数据已取，文档见 `CHEATS.md`（单独进行） |

## 2. `:checkhealth config` 实测要点

- 基础：Neovim 0.12.5+v0.12.5、`mapleader = <Space>` ✅
- 环境工具：lazygit / direnv / rg / git ✅
- 键位：**已注册 <leader> 映射 101 个**；无「既是直接动作、又是前缀」；全部有 desc ✅
- 插件规格结构：没有「顶层裸规格」的插件文件 ✅
- 语言就绪度 14 个全 OK：lua、c/cpp、cmake、bash/sh、json、yaml、toml、python、rust、scala、sql、verilog、nix、docker ✅
- mason 已装 24 个包 ✅

## 3. 声明 vs 实装（脚本对账）

对账逻辑（临时脚本，跑完即弃）：扫 `lua/plugins/**/*.lua` 里所有 `ensure_installed` 的字符串，
分别与 `~/.local/share/nvim/mason/packages`、`~/.local/share/nvim/site/parser/*.so` 求差集。

- 声明 **65** 项；mason 实装 **24**；parser 实装 **48**
- **声明了但两边都没实装：无** ✅
- mason 孤儿：`golangci-lint` → 配置里没有 Go 语言支持，属遗留，无害 → **记 TODO**
- parser 孤儿：`go`、`gomod`、`gosum`、`gowork`、`haskell` → 旧配置遗留，无害 → **记 TODO**
- 已排除的误报：`dtd` 不是孤儿，它是声明里 `xml` 的 `requires`（`nvim-treesitter/parsers.lua:2284`）✅

## 4. 本轮修掉的报错

| 报错 | 根因 | 修法 | 验证证据 |
|---|---|---|---|
| `vim-dadbod-completion` 的 `attempt to call field 'addCompletionSource' (a nil value)` | 插件自带的 `after/plugin` 里有个面向老引擎 `completion-nvim` 的分支：`pcall(require,'completion')` 成功就调 `completion.addCompletionSource` | `lua/plugins/lang/sql.lua` 的 spec 加 `init`：检测到该模块缺失/残缺时塞一个空的 `package.preload` | 打开 `.sql` 进 insert 后 `v:errmsg` 为空、`:messages` 无该字样、`vim_dadbod_completion.blink` 仍可加载（无回归）✅ |

说明：本机任何阶段 `package.searchpath('completion', …)` 都是 nil，报错**复现不出来**（你也说它自己消失过），
所以按防御性处理，并把理由写进代码注释。commit `565c34d`。

## 5. 本轮同时完成

- `:Lazy` 窗口改圆角（lazy 默认 `ui.border = "none"`）→ `lua/config/lazy.lua`，commit `64ac93e`

## 6. 未纳入本次（说明为什么）

- **启动耗时剖析**（`--startuptime`）：与「报错 / 冲突」目标无关，而且需要多次对比才有意义 → 记 TODO
- **插件重复功能审查**（例如两套补全源）：本次没有任何症状暴露，没有证据就不动
- **`golangci-lint` / parser 孤儿清理**：无害，且清理属于系统层（mason / parser 目录）而非配置 → 记 TODO

## 3. 全量冲突扫描（2026-09-13，分支 `audit/full-scan`）

方法：注册期追踪（`vim.keymap.set` / `nvim_set_keymap` / snacks toggle）+ 全模式 dump（n/x/o/i/t/c/s）
+ 与 `nvim -u NONE` 的默认映射对照 + 规格 `keys` 静态收集 + 自动命令按 (事件, pattern) 分组。
扫描夹具在 `.test/audit/`（gitignored，可重跑）；自带对已知案例的断言，跑不出结果就报错。

| # | 发现 | 结论 |
|---|---|---|
| K1 | 配置期重复注册 1095 条记录中，desc 不同的 **0 条** | ✅ 无真覆盖（`<leader>uT` 那类已修） |
| K2 | 覆盖 nvim 自带映射 17 条（`an/in`、`<C-S>`、`[b/]b`、`[q/]q`、`[d/]d`、`[t/]t`、`[B/]B`、`<C-L>`） | 设计如此；已在 CHEATS §1 补记语义变化 |
| K3 | LSP 的 `gr` 带 `nowait` 会挡住 nvim 0.11+ 内置的 `grn/gra/grr/gri` | ✅ 已去掉 `nowait` |
| K4 | LSP 键位重复声明 5 个（`gd/gr/gI/gy/<leader>cr`，来自 `lsp.lua` 与 `picker.lua`）。实测合并后 **29 条一条没丢**（lazy 对列表是追加而非按下标覆盖 —— 用 `tbl_deep_extend` 模拟会误判成丢 21 条）。但 `<leader>cr` 两条同时存在：editor.lua 的 inc-rename 先装、lsp.lua 的 `vim.lsp.buf.rename` 后装 → inc-rename 是死键 | OK 已把 inc-rename 挪到 `<leader>ci`（`<leader>cr` 保持 plain rename，行为不变） |
| K5 | 缓冲局部覆盖全局 4 处：`[a/]a/[A/]A`（treesitter-textobjects 的参数 textobject；全局同名键是 `:previous/:next` 等） | 设计如此（buffer-local 只在有 parser 的缓冲生效） |
| A1 | 同一 (事件, pattern) 多 handler：`ColorScheme` 13、`FileType` 12（含 2 个匿名）、`CursorMoved` 9、`BufWritePre` 3 | 顺序已核对；"切主题 vs 启动即该主题"的全量高亮 dump 无真实差异 |
| A2 | 匿名自动命令 18 条，其中 `User TransparencyChanged` 是我们自己写的 | ✅ 已归入 `config_theme` 组 |
| S1 | 状态文件健壮性：未知/已删主题、非法变体、垃圾内容、空文件、多行 都能安全回退 | ✅ |
| S2 | 状态文件带 CRLF 或前后空格时会被**静默忽略** | ✅ 已 trim；解析失败时给 WARN |
| D1 | 文档漂移：`<leader>d` 组名的"待修"备注已过期（实际已是 direnv / profiler）；CHEATS §1 漏了 `<C-S>`（i/s）、`[t/]t`、`[B/]B` 等被占用的内置键 | ✅ 已修 |
| D2 | 死代码：`util/lsp.lua` 的 `M.execute`、`util/lualine.lua` 的 `M.cmp_source` 全仓无引用 | ✅ 已删 |
| P1 | `(vim.uv or vim.loop)` 兼容兜底 2 处（nvim 0.12 必带 `vim.uv`） | ✅ 已改 `vim.uv` |

新增能力：`:checkhealth config` 的「键位」小节现在会报「同键重复注册」与「覆盖了 nvim 自带映射」
（靠新增的 `lua/util/keytrace.lua` 做注册追踪；以前只用 `nvim_get_keymap`，看不见被覆盖的键）。
