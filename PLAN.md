# 将 LazyVim 默认配置“去包装”为独立 Neovim 配置

> **状态：已完成（历史文档）** —— 这是当年"去 LazyVim 化"的计划原文，保留作决策记录。
> 当前结构与约定请看 `TRANSPARENCY.md`、`CHEATS.md`、`TODO.md`，以及 `:checkhealth config`。

## 1. 目标

把 LazyVim 在**默认状态（用户未启用任何 extra）**下提供的全部行为，抽取为一份**自包含**的 Neovim 配置，放进 `~/.config/nvim`：

- `options`、`keymaps`、`autocmds` 提取为纯 `vim.opt` / `vim.keymap.set` / `vim.api.nvim_create_autocmd`。
- 所有默认插件及其配置抽取为普通 lazy.nvim spec，**不再依赖 LazyVim/LazyVim 仓库**。
- 剥离 `LazyVim.*`、`lazyvim.config`、`lazyvim.plugins` 导入魔法、lazyvim.json extras 机制等封装/抽象层。
- 只考虑 **Linux**，以当前 **Neovim v0.12.5** 为准。

## 2. 约束与范围

- **仅参考**：lazyvim.org 文档、LazyVim/LazyVim 仓库、LazyVim/starter 仓库、Neovim 官方仓库/issue/help。**不参考**任何第三方博客/文章/论坛。
- 参考源已克隆在 `~/.config/nvim/.research/lazyvim-src`（LazyVim，commit `459a4c3`，v16.0.0）与 `~/.config/nvim/.research/starter`，只读使用。
- 目标目录当前只有 `nvim.log` 与 `.research/`，等于干净起点；成品不依赖 `.research`。
- Linux-only：删除 Windows 分支（`is_win`、`win_find_cl`、`vim.fn.has("win32")`、`clipboard` 的 ssh 判断保留但去掉 pbcopy/xsel 分支逻辑等）。
- nvim 0.12.5：把 `vim.fn.has("nvim-0.12"/"nvim-0.13")` 分支**固定**到 0.12.x 路径（如 `vim.hl.hl_op()` vs `on_yank`、nvim-treesitter 的 `commit` 锁定、`vim.lsp.config()` API）。

## 3. 关键决策（请确认，均可改）

1. **保留 lazy.nvim 作为插件管理器**。lazy.nvim 是底层依赖而非 LazyVim 抽象；本任务剥离的是 LazyVim 发行版层。备选：完全展平为手写 rtp/packadd（不推荐，工作量大且无收益）。
2. **包含 3 个“默认自动启用的 extra”**：snacks picker（`extras/editor/snacks_picker.lua`）、blink.cmp（`extras/coding/blink.lua`）、snacks explorer（`extras/editor/snacks_explorer.lua`）。它们虽然位于 extras/ 下，但**无用户操作即默认启用**，属于默认体验；其余 extras 一律不引入。
3. **保留 `Snacks.*` 全局 API**（snacks.nvim 自身的公开接口，非 LazyVim 封装），如 `Snacks.toggle`/`Snacks.picker`/`Snacks.terminal`/`Snacks.bufdelete` 等。
4. **去掉**：lazyvim.json、`:LazyExtras`/`:LazyHealth`、import 顺序检查、重命名/弃用 extra 的兼容层、`LazyVim.news`（changelog 弹窗）、`LazyVim.terminal`、`LazyVim.deprecated`、deprecation 警告。
5. **`event = "LazyFile"` 机制**：这是 lazy.nvim 的事件映射（`LazyVim.plugin.lazy_file()` 里 3 行注册），由 gitsigns/todo-comments/nvim-lint/nvim-ts-autotag/nvim-treesitter 使用。做法：在本地 util 里保留这 3 行注册，而非逐个改写事件（等价且改动最小）。
6. **icons 与 kind_filter**：从 `LazyVim.config.icons` / `.kind_filter` 抽到本地 `lua/config/icons.lua`，供各插件直接引用。
7. 保留仍具功能的命令 `:LazyFormat`/`:LazyFormatInfo`/`:LazyRoot`（由本地 util 实现），删除纯发行版管理类的 `:LazyExtras`/`:LazyHealth`。

8. **剥离 DAP（本次新增需求）**：不引入 `dap/core`、`dap/nlua` extras；并清除核心默认配置中的 DAP 残留——`icons.dap` 表、lualine 的 dap 状态组件、autocmds 的 `dap-float`、which-key 的 `<leader>d` debug 组。

## 4. 目标目录结构

```
~/.config/nvim/
├── init.lua                    # bootstrap lazy.nvim + require("config.lazy")
└── lua/
    ├── config/
    │   ├── lazy.lua            # lazy.nvim setup（spec 显式列出全部插件 + defaults/performance/install）
    │   ├── options.lua         # 去包装后的 options
    │   ├── keymaps.lua         # 去包装后的 keymaps
    │   ├── autocmds.lua        # 去包装后的 autocmds
    │   └── icons.lua           # icons + kind_filter
    ├── util/                   # 替换 LazyVim.* 的本地最小工具库
    │   ├── init.lua            # notify/try/error/warn/info/set_default/dedup/on_load/on_very_lazy/lazy_notify/LazyFile 注册
    │   ├── root.lua            # 根目录探测（detect/get/git）
    │   ├── format.lua          # formatter 注册表 + autoformat + formatexpr
    │   ├── treesitter.lua      # have/indentexpr/foldexpr/build
    │   ├── statuscolumn.lua    # statuscolumn fn（转调 snacks.statuscolumn.get）
    │   ├── cmp.lua             # snippet_stop/expand/map
    │   ├── lsp.lua             # formatter/action.source/code_actions/on_attach
    │   ├── mini.lua            # mini.pairs 配置 + mini.ai 的 ai_buffer/ai_whichkey
    │   └── lualine.lua         # root_dir/pretty_path
    └── plugins/                # 一个文件一个模块，全部显式 import
        ├── core.lua            # lazy.nvim + snacks 核心 bootstrap（原 plugins/init.lua 去掉 LazyVim 自身）
        ├── ui.lua              # bufferline/lualine/noice/mini.icons/nui/snacks(UI+dashboard)
        ├── editor.lua          # grug-far/flash/which-key/gitsigns/trouble/todo-comments
        ├── coding.lua          # mini.pairs/ts-comments/mini.ai/lazydev
        ├── colorscheme.lua     # tokyonight/catppuccin
        ├── treesitter.lua      # nvim-treesitter/textobjects/ts-autotag
        ├── util.lua            # snacks(bigfile/quickfile/terminal/scratch/profiler)/persistence/plenary
        ├── linting.lua         # nvim-lint
        ├── formatting.lua      # conform.nvim
        ├── lsp.lua             # nvim-lspconfig/mason(+mason-lspconfig)
        ├── picker.lua          # snacks picker（默认 extra）
        ├── completion.lua      # blink.cmp + friendly-snippets + blink.compat（默认 extra）
        └── explorer.lua        # snacks explorer（默认 extra）
```

## 5. 需去包装的封装函数清单（映射到本地实现）

| 原封装 | 去包装为 |
|---|---|
| `lazyvim.config`（setup/load/defaults/json/init/register_defaults/get_defaults） | 删除；icons/kind_filter 落本地，VeryLazy 编排改为显式 require |
| `LazyVim.safe_keymap_set` | `vim.keymap.set`（需要 lazy-key 互斥处用 `Snacks.keymap.set`） |
| `LazyVim.format.formatexpr()` | `require("conform").formatexpr()` |
| `LazyVim.statuscolumn()` | `snacks.statuscolumn.get()` |
| `LazyVim.root()/.git()` | 本地 `util/root.lua` |
| `LazyVim.treesitter.*` | 本地 `util/treesitter.lua` |
| `LazyVim.mini.*` | 本地 `util/mini.lua`（内联原 mini 辅助逻辑） |
| `LazyVim.lualine.*` | 本地 `util/lualine.lua` |
| `LazyVim.cmp.*` | 本地 `util/cmp.lua` |
| `LazyVim.lsp.*` | 本地 `util/lsp.lua` |
| `LazyVim.pick(...)` | 直接 `Snacks.picker.pick(...)` |
| `LazyVim.config.icons` / `.kind_filter` | 本地 `config/icons.lua` |
| `LazyVim.has/opts/try/error/warn/info/set_default/dedup/on_load/on_very_lazy/lazy_notify` | 本地 `util/init.lua` |
| `LazyVim.plugin.*`（fix_imports/fix_renames/save_core/renames/deprecated） | 删除；仅保留 LazyFile 事件注册 |
| `LazyVim.news/extras/json/terminal/deprecated` | 删除 |

## 6. 执行阶段

**Phase 0 — 骨架与 bootstrap**
- 写 `init.lua`（starter 同款 bootstrap）与 `lua/config/lazy.lua`（lazy.nvim setup；spec 用 `import = "plugins"` 显式列出本地的 plugins 目录；defaults/install/performance 沿用 starter 的 lazy=false / version=false / disabled_plugins）。
- 验收：`nvim --headless "+qa"` 无报错，lazy.nvim 能加载。

**Phase 1 — config 层去包装**
- `config/icons.lua`：迁 icons 与 kind_filter。
- `config/options.lua`：迁全部 `vim.opt/vim.g`，替换 `formatexpr`/`statuscolumn` 引用。
- `config/autocmds.lua`：基本原样迁（已是原生 API）。
- `config/keymaps.lua`：逐条迁为 `vim.keymap.set`，替换 `LazyVim.format.snacks_toggle`、`LazyVim.cmp.actions.snippet_stop`、`LazyVim.root.git`、`LazyVim.news.changelog`（后者删除）。
- 验收：`nvim --headless "+qa"` 中 require 三个 config 文件无报错。

**Phase 2 — 本地 util 工具库**
- 按第 5 节清单逐个实现 `util/init|root|format|treesitter|statuscolumn|cmp|lsp|mini|lualine.lua`，去 Windows 分支、去 `LazyVim` 依赖、去 deprecation。
- 验收：各 util 模块可独立 `require` 无报错；`LazyFile` 事件已注册。

**Phase 3 — 默认插件 spec 迁移**
- 按第 4 节 `plugins/*` 逐文件迁移，插件内引用 `LazyVim.config.icons`→本地 icons、`LazyVim.root/format/treesitter/mini/lualine/cmp/lsp/pick`→本地 util、`LazyVim.has/opts/...`→本地 util。
- `core.lua` 删除 `{ "LazyVim/LazyVim", ... }`，仅保留 lazy.nvim 与 snacks 核心 bootstrap（含 noice 的 `vim.notify` HACK）。
- 固定 nvim 0.12 分支（treesitter `commit` 置 `nil`、`vim.hl.hl_op()`）。
- 验收：全部插件 spec 被 lazy.nvim 正确解析（headless 下 `:Lazy` 或 `require("lazy").stats()`）。

**Phase 4 — 3 个默认 extra 内联**
- `picker.lua`：迁 snacks_picker（去 `LazyVim.pick.register` 注册表，直接内联 picker 命令映射；去 alpha/mini.starter/dashboard 的 optional 兼容块）。
- `completion.lua`：迁 blink.cmp（去 `LazyVim.cmp.expand/map`→本地 cmp、icons→本地；`nvim-cmp` 禁用块可删）。
- `explorer.lua`：迁 snacks_explorer（`LazyVim.root()`→本地 root）。
- 验收：三份 spec 加载无报错；picker/cmp/explorer 快捷键存在。

**Phase 5 — 联调与验证（见第 7 节）**
- 安装插件、跑 checkhealth、修到干净启动。

## 7. 验证方案

- `nvim --headless "+lua require('lazy').sync({show=false})" +qa`：安装/同步插件（首次需网络 + Linux 系统依赖：ripgrep、C 编译器用于 nvim-treesitter、git）。
- `nvim --headless "+Lazy! load all" "+checkhealth" +qa` 抓错误与告警。
- `nvim --headless -c "lua require('lazy').stats()" +qa` 核对插件数量/加载状态与 LazyVim 默认一致（约 30 个插件）。
- 交互抽查：启动后 colorscheme=Tokyo Night、状态栏/缓冲栏/完成/文件树/搜索可用，`<leader>` 系列快捷键、自动格式化、LSP 可用。
- 对照 LazyVim 默认行为，记录仍存在的差异并说明原因（应主要是发行版管理类命令与 news/updates 提示的缺失）。

## 8. 风险与说明

- **行为等价性**：`LazyVim.set_default`/懒加载编排等“精确时序”可能产生微小差异（如启动时 foldmethod/indentexpr 的默认值保护）；本地 util 会保留 `set_default` 语义以尽量一致。
- **图标字体**：icons 表原样迁移，仍需 Nerd Font 才能正常显示（与 LazyVim 相同，非本任务问题）。
- **`.research/` 保留**：作为只读参考，不进入成品；完成后可按需删除。
- **Linux-only 简化**：剪掉 Windows 分支后，未来跨平台需自行补回，属预期取舍。
