-- 个人配置的健康检查：:checkhealth config
-- 只做「跨插件的、这份配置特有的」检查；各插件自带的 :checkhealth <插件> 不重复。
--   1. 基础（版本 / leader）
--   2. 环境工具是否可用
--   3. 键位是否自洽（冲突 / 缺 desc）
--   4. 各语言就绪度（LSP / treesitter / 格式化 / lint）
--   5. mason 已装包一览
-- 注：第 4 节的期望表与 lua/plugins/lang/*.lua 对应，改语言支持时同步改这里。

local M = {}

local data = vim.fn.stdpath("data")
local mason_bin = data .. "/mason/bin/"
local parser_dir = data .. "/site/parser/"

-- 找二进制：既查 PATH，也查 mason 的 bin（mason 未加载时 PATH 里可能没有）
local function have(bin)
  return vim.fn.executable(bin) == 1 or vim.fn.executable(mason_bin .. bin) == 1
end

-- 直接读 parser 目录，避免依赖 nvim-treesitter 是否已加载
local installed_ts = {}
for _, f in ipairs(vim.fn.globpath(parser_dir, "*.so", false, true)) do
  installed_ts[vim.fn.fnamemodify(f, ":t:r")] = true
end

---@type {name:string, lsp?:string[], ts?:string[], fmt?:string[], lint?:string[]}[]
local langs = {
  { name = "lua",       lsp = { "lua-language-server" }, ts = { "lua" },  fmt = { "stylua" } },
  { name = "c / cpp",   lsp = { "clangd" },              ts = { "c", "cpp" } },
  { name = "cmake",     lsp = { "neocmakelsp" },         ts = { "cmake" }, fmt = { "cmake-format" }, lint = { "cmake-lint" } },
  { name = "bash / sh", lsp = { "bash-language-server" }, ts = { "bash" }, fmt = { "shfmt" },        lint = { "shellcheck" } },
  { name = "json",      lsp = { "vscode-json-language-server" }, ts = { "json" } },
  { name = "yaml",      lsp = { "yaml-language-server" }, ts = { "yaml" } },
  { name = "toml",      lsp = { "taplo" },               ts = { "toml" },  fmt = { "taplo" } },
  { name = "python",    lsp = { "pyright" },             ts = { "python" }, fmt = { "ruff" },       lint = { "ruff" } },
  { name = "rust",      lsp = { "rust-analyzer" },       ts = { "rust" } },
  { name = "scala",     ts = { "scala" } }, -- metals 由 coursier 自行下载，不在 mason
  { name = "sql",       ts = { "sql" },                  fmt = { "sqlfluff" }, lint = { "sqlfluff" } },
  { name = "verilog",   lsp = { "verible-verilog-ls" },  ts = { "systemverilog" }, fmt = { "verible-verilog-format" }, lint = { "verilator" } },
  { name = "nix",       lsp = { "nil" },                 ts = { "nix" } },
  { name = "docker",    lsp = { "docker-langserver" },   ts = { "dockerfile" }, lint = { "hadolint" } },
}

-- 供 :checkhealth config 与审计脚本复用
M.langs = langs

function M.check()
  local h = vim.health

  h.start("config: 基础")
  if vim.fn.has("nvim-0.11") == 1 then
    h.ok(("Neovim %s（>= 0.11，原生 vim.lsp.config/enable 可用）"):format(vim.version()))
  else
    h.error(("Neovim %s 过旧：配置依赖 >= 0.11"):format(vim.version()))
  end
  if vim.g.mapleader == " " then
    h.ok("mapleader = <Space>")
  else
    h.warn("mapleader 不是空格：" .. vim.inspect(vim.g.mapleader))
  end

  h.start("config: 环境工具")
  local tools = {
    rg = "ripgrep — picker 搜索",
    git = "git — 仓库/懒加载更新",
    direnv = "direnv — .envrc 自动加载",
    lazygit = "lazygit — <leader>gg",
  }
  for bin, why in pairs(tools) do
    if have(bin) then h.ok(("%s（%s）"):format(bin, why)) else h.warn(("%s 未找到 — %s"):format(bin, why)) end
  end

  h.start("config: 键位")
  local L = vim.g.mapleader
  local all = {}
  for _, mode in ipairs({ "n", "x" }) do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      if m.lhs:sub(1, #L) == L then
        -- desc 以 "+" 开头、或 rhs 为空 => which-key 的「组名占位」，不是真动作
        local is_group = (m.desc or ""):sub(1, 1) == "+" or (m.rhs or "") == ""
        all[m.lhs] = { desc = m.desc, group = is_group }
      end
    end
  end
  local total, conflicts, nodesc = 0, {}, {}
  for lhs, info in pairs(all) do
    total = total + 1
    if not info.group then
      if not info.desc or info.desc == "" then
        nodesc[#nodesc + 1] = lhs
      end
      for other in pairs(all) do
        if other ~= lhs and other:sub(1, #lhs) == lhs then
          conflicts[#conflicts + 1] = lhs
          break
        end
      end
    end
  end
  table.sort(conflicts)
  table.sort(nodesc)
  h.info(("已注册 <leader> 映射 %d 个"):format(total))
  if #conflicts == 0 then
    h.ok("没有「既是直接动作、又是前缀」的键位（这类会延迟触发/显示成组）")
  else
    h.warn("既是直接动作又是前缀：" .. table.concat(conflicts, " "))
  end
  if #nodesc == 0 then
    h.ok("所有 <leader> 映射都有 desc（能在 which-key 里显示）")
  else
    h.warn("缺少 desc 的映射：" .. table.concat(nodesc, " "))
  end

  h.start("config: 插件规格结构")
  -- 静态扫描（不执行文件）：lua/plugins/**/*.lua 里若出现「第 0 列的仓库名字符串」，
  -- 说明该规格很可能没被 { } 包住 —— 后果是这个插件的 opts/keys/event/config
  -- 全部静默失效（不报错！）。本项目已在 yanky / dial / smear-cursor 上踩过 3 次。
  local proot = vim.fn.stdpath("config") .. "/lua/plugins"
  local suspects = {}
  for _, f in ipairs(vim.fn.globpath(proot, "**/*.lua", false, true)) do
    local n = 0
    for _, line in ipairs(vim.fn.readfile(f)) do
      n = n + 1
      if line:match('^"[^"]+",%s*$') then
        suspects[#suspects + 1] = ("%s:%d"):format(f:gsub(vim.fn.stdpath("config") .. "/", ""), n)
      end
    end
  end
  if #suspects == 0 then
    h.ok("没有「顶层裸规格」的插件文件")
  else
    h.error("疑似规格未包裹（会让 opts/keys/event/config 静默失效）：" .. table.concat(suspects, "  "))
  end

  h.start("config: 语言就绪度")
  for _, l in ipairs(langs) do
    local missing = {}
    for _, b in ipairs(l.lsp or {}) do
      if not have(b) then missing[#missing + 1] = "LSP:" .. b end
    end
    for _, p in ipairs(l.ts or {}) do
      if not installed_ts[p] then missing[#missing + 1] = "parser:" .. p end
    end
    for _, f in ipairs(l.fmt or {}) do
      if not have(f) then missing[#missing + 1] = "fmt:" .. f end
    end
    for _, f in ipairs(l.lint or {}) do
      if not have(f) then missing[#missing + 1] = "lint:" .. f end
    end
    if #missing == 0 then
      h.ok(l.name)
    else
      h.warn(("%s — 缺 %s"):format(l.name, table.concat(missing, ", ")))
    end
  end

  h.start("config: mason 已装包")
  local pkgs = {}
  for _, p in ipairs(vim.fn.globpath(data .. "/mason/packages", "*", false, true)) do
    pkgs[#pkgs + 1] = vim.fn.fnamemodify(p, ":t")
  end
  table.sort(pkgs)
  h.info(("共 %d 个：%s"):format(#pkgs, table.concat(pkgs, " ")))
end

return M
