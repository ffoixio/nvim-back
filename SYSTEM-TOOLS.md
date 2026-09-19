# 用系统工具链取代 mason（Arch + 本机）

> 决策记录见 `TODO.md` §4；这里放**对照表**和验证方法。
> 判定代码：`lua/util/init.lua` 的 `M.system_toolchain()`；mason 的开关：`lua/plugins/lsp.lua`。

## 判定逻辑

```lua
M.is_arch()          -- /etc/arch-release 存在
M.my_hosts = { ["Windows-phont"] = true }   -- 我自己的机器（hostname 白名单）
M.is_my_machine()    -- vim.uv.os_gethostname() 命中白名单
M.system_toolchain() -- 两者都为真 => 不启用、不下载 mason.nvim
```

`mason-org/mason.nvim` 的 spec 上写 `enabled = not U.system_toolchain()`：lazy 对 disabled 插件
既不加载也不安装（所以新机器上不会拉 mason），`<leader>cm` 的 Mason 面板也一并消失。
不在白名单/非 Arch 的机器上行为完全不变（继续用 mason）。

## 工具 → 包名对照表

| 可执行文件 | 用在哪 | 包（仓库） |
|---|---|---|
| `clangd` | C/C++ LSP | `clang`（extra）**已装** |
| `tree-sitter` | nvim-treesitter 构建 | `tree-sitter-cli`（extra）**已装** |
| `lua-language-server` | Lua LSP | `lua-language-server`（extra） |
| `stylua` | Lua 格式化 | `stylua`（extra） |
| `bash-language-server` | shell LSP | `bash-language-server`（extra） |
| `shfmt` | shell 格式化 | `shfmt`（extra） |
| `shellcheck` | shell lint | `shellcheck`（extra） |
| `vscode-json-language-server` | JSON LSP | `vscode-json-languageserver`（extra） |
| `yaml-language-server` | YAML LSP | `yaml-language-server`（extra） |
| `taplo` | TOML LSP / 格式化 | `taplo-cli`（extra） |
| `pyright` / `pyright-langserver` | Python LSP | `pyright`（extra） |
| `ruff` | Python 格式化 + lint | `ruff`（extra） |
| `gopls` | Go LSP | `gopls`（extra） |
| `golangci-lint` | Go lint | `golangci-lint`（extra） |
| `zls` | Zig LSP | `zls`（extra） |
| `rust-analyzer` | Rust LSP | `rust-analyzer`（extra） |
| `sqlfluff` | SQL 格式化 + lint | `sqlfluff`（extra） |
| `verible-verilog-ls` / `verible-verilog-format` | Verilog LSP / 格式化 | `verible`（archlinuxcn） |
| `verilator` | Verilog lint | `verilator`（extra） |
| `docker-langserver` | Dockerfile LSP | `dockerfile-language-server`（extra） |
| `neocmakelsp` | CMake LSP | AUR `neocmakelsp` |
| `cmake-format` / `cmake-lint` | CMake 格式化 / lint | AUR `cmakelang` |
| `hadolint` | Dockerfile lint | AUR `hadolint` |
| `checkmake` | Makefile lint | AUR `checkmake` |
| `nil` | Nix LSP | AUR `nil` |
| `goimports` | Go 格式化 | AUR `goimports`（或 `go` 工具链自建） |
| `julia-lsp` | Julia LSP | Julia 生态（`LanguageServer.jl`；该模块默认关） |
| `perlnavigator` | Perl LSP | AUR（该模块默认关） |
| `tclint` | Tcl lint | AUR / pip（该模块默认关） |

（仓库归属用 `pacman -Si <包名>` 逐个核对过，2026-09-13。）

## 待办 / 迁移步骤

1. `sudo pacman -S`（extra）：`lua-language-server stylua bash-language-server shfmt shellcheck
   vscode-json-languageserver yaml-language-server taplo-cli pyright ruff gopls golangci-lint
   zls rust-analyzer sqlfluff verilator dockerfile-language-server go`
2. archlinuxcn：`cmake-language-server verible`
3. AUR：`neocmakelsp cmakelang hadolint checkmake nil goimports`
4. 装完跑 `:checkhealth config`：**「语言就绪度」全部 OK** 才算迁移完成；
   确认完就可以删掉 `~/.local/share/nvim/mason`（旧文件不删也不影响，只是白占磁盘）。
5. `lazy-lock.json` 里 `mason.nvim` 那条：disabled 插件的 pin 会被 lazy 的 install/clean 剪掉，
   和之前 6 个禁用模块的命运一样 —— 属预期，不用手工维护。

## 验证

```vim
:lua print(require("util.init").system_toolchain())      " => true
:lua print(vim.uv.os_gethostname())                        " => Windows-phont
:lua print(package.loaded["mason"] ~= nil)                " => false（没加载）
:checkhealth config                                        " 看「工具链」「语言就绪度」两节
```

health 的 `have()` 在系统工具链模式下**只认 PATH**（不再回退到 mason 的 bin），这样残留的
mason 包不会把「就绪」状态伪造成绿的 —— 缺什么就老老实实报缺。
