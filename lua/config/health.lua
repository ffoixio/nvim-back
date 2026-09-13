-- 个人配置的健康检查：:checkhealth config
-- 只做「跨插件的、这份配置特有的」检查；各插件自带的 :checkhealth <插件> 不重复。
--   1. 基础（版本 / leader）
--   2. 环境工具是否可用
--   3. 终端 / 复用器（是否在 zellij / tmux 里、对 nvim 有影响的设置、剪贴板与焦点事件、波浪线自测）
--   4. 键位是否自洽（冲突 / 缺 desc）
--   5. 模块登记（config/modules.lua 与 plugins/ 下实际文件是否对得上）
--   6. 各语言就绪度（LSP / treesitter / 格式化 / lint；数据来自各语言模块自己的 register_lang）
--   7. mason 已装包一览
-- 注：第 4 节的数据由各语言模块自己登记（plugins/lang/*.lua 里的 register_lang），这里不再维护副本。

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


-- 语言就绪度的数据源：config.modules.lang_meta（各语言模块自报），不再在这里留副本
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

  h.start("config: 终端 / 复用器")
  -- 目的：把"渲染/键位/剪贴板到底受不受终端与复用器影响"变成可读的事实，而不是靠猜。
  -- 全部只读探测；外部命令都用 executable() 守卫，失败一律降级成 info。
  local prog = vim.env.TERM_PROGRAM
  local colorterm = vim.env.COLORTERM
  local remote = (vim.env.SSH_CONNECTION or vim.env.SSH_TTY) and "是" or "否"
  h.info(("终端：TERM=%s%s%s，truecolor=%s，background=%s，远程=%s"):format(
    vim.env.TERM or "?",
    prog and ("  TERM_PROGRAM=" .. prog) or "",
    colorterm and ("  COLORTERM=" .. colorterm) or "",
    tostring(vim.o.termguicolors),
    vim.o.background,
    remote
  ))

  if vim.env.ZELLIJ then
    h.info("复用器：zellij（会话 " .. vim.env.ZELLIJ .. "）")
    if vim.fn.executable("zellij") == 1 then
      h.info("  " .. (vim.fn.system({ "zellij", "--version" }):gsub("%s+$", "")))
    end
    local zcfg = (vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")) .. "/zellij/config.kdl"
    local f = io.open(zcfg, "r")
    if f then
      local txt = f:read("*a") or ""
      f:close()
      -- 只看没被注释掉的行
      local function zopt(name, default)
        for line in txt:gmatch("[^\n]+") do
          if not line:match("^%s*//") then
            local v = line:match("^%s*" .. name .. "%s+([%w%-_\"]+)")
            if v then
              return v
            end
          end
        end
        return default
      end
      local mode = zopt("default_mode", "normal")
      local styled = zopt("styled_underlines", "(默认)")
      local kkp = zopt("support_kitty_keyboard_protocol", "(默认 false)")
      h.info(("  default_mode=%s  styled_underlines=%s  support_kitty_keyboard_protocol=%s"):format(mode, styled, kkp))
      if mode ~= "locked" then
        h.info("  ⓘ default_mode 不是 locked：zellij 会抢键。设 locked 后按 Ctrl-b 进 tmux 模式，等于前缀键")
      end
    else
      h.info("  没找到 " .. zcfg .. "（走 zellij 默认配置）")
    end
  elseif vim.env.TMUX then
    h.info("复用器：tmux")
    if vim.fn.executable("tmux") == 1 then
      h.info("  " .. (vim.fn.system({ "tmux", "-V" }):gsub("%s+$", "")))
      local function topt(name)
        local out = vim.fn.system({ "tmux", "show", "-g", name })
        if vim.v.shell_error ~= 0 then
          return nil
        end
        return (out:gsub("^%s*" .. vim.pesc(name) .. "%s*", ""):gsub("%s+$", ""))
      end
      local et = tonumber(topt("escape-time") or "")
      if et and et > 50 then
        h.warn(("  escape-time=%d（大于 50 会让 Esc 系列键发粘，建议设成 10）"):format(et))
      else
        h.info("  escape-time=" .. tostring(et))
      end
      local fe = topt("focus-events")
      if fe == "off" then
        h.warn("  focus-events=off（本配置有 FocusGained autocmd，建议设为 on）")
      else
        h.info("  focus-events=" .. tostring(fe))
      end
      h.info("  set-clipboard=" .. tostring(topt("set-clipboard")) .. "（nvim 的 + 走 OSC52 时需要 on）")
      local feat = (topt("terminal-features") or "") .. (topt("terminal-overrides") or "")
      if feat:find("RGB") or feat:find(":Tc") then
        h.info("  terminal-features/overrides 里已声明真彩")
      else
        h.info("  没看到 RGB/Tc 声明：真彩可能没开（旧 tmux 需要往 terminal-overrides 里加 ,*:Tc）")
      end
    else
      h.info("  当前 PATH 里没有 tmux，无法查询它的设置")
    end
  else
    h.info("复用器：无（直接跑在终端里）")
  end

  -- nvim 侧与终端能力相关的几项
  local osc52 = vim.ui and vim.ui.clipboard and vim.ui.clipboard.osc52 and "可用" or "无"
  h.info(("剪贴板：has(clipboard)=%s，g:clipboard=%s，OSC52=%s"):format(
    tostring(vim.fn.has("clipboard") == 1),
    vim.g.clipboard ~= nil and "已自定义" or "未设置",
    osc52
  ))
  local focus = vim.api.nvim_get_autocmds({ event = "FocusGained" })
  if #focus > 0 then
    h.info(("焦点事件：注册了 %d 个 FocusGained autocmd —— 需要终端/复用器转发焦点事件才会触发"):format(#focus))
  end
  h.info("鼠标：" .. (vim.o.mouse == "" and "(未开启)" or vim.o.mouse))
  -- 波浪线自测：给一行挂上诊断下划线的高亮，肉眼确认终端/复用器是否真的画出波浪线
  pcall(function()
    local buf = vim.api.nvim_get_current_buf()
    local lnum = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, lnum, lnum, false, { "  [undercurl 自测] 这行若有波浪线 = 终端/复用器支持（不支持时诊断的波浪线会降级或不显示）" })
    vim.api.nvim_buf_add_highlight(buf, -1, "DiagnosticUnderlineError", lnum, 0, -1)
  end)

  h.start("config: 键位")
  local L = vim.g.mapleader
  local all = {}
  for _, mode in ipairs({ "n", "x", "o", "i", "c", "t", "s" }) do
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

  -- 覆盖检测：nvim_get_keymap 只能看到最终生效的那个键，被覆盖的要靠 util/keytrace.lua 的注册
  -- 记录。分两类：① 同键注册两次且 desc 不同（含 lazy 的「占位 -> 真实映射」，属正常，所以只
  -- 列出来供扫一眼，不报警）② 覆盖了 nvim 自带映射（info）。
  local rep = require("util.keytrace").report()
  local function fmt(items)
    local t = {}
    for _, it in ipairs(items) do
      t[#t + 1] = it.key .. "[" .. tostring(it.old) .. " -> " .. tostring(it.new) .. "]"
    end
    return table.concat(t, "；")
  end
  if #rep.duplicated == 0 then
    h.ok("没有同键重复注册")
  else
    h.info(("同键重复注册 %d 条（占位->真实映射属正常，重点看 desc 不同的）：%s"):format(#rep.duplicated, fmt(rep.duplicated)))
  end
  if #rep.overwritten == 0 then
    h.ok("没有覆盖 nvim 自带映射")
  else
    h.info(("覆盖了 nvim 自带映射 %d 条：%s"):format(#rep.overwritten, fmt(rep.overwritten)))
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

  h.start("config: 模块登记（config/modules.lua）")
  -- 语言/功能模块现在是"按开关逐个导入文件"，没登记的模块文件等于静默不加载，所以这里点名。
  local modules = require("config.modules")
  local function unregistered(dir, registered)
    local missing = {}
    for _, f in ipairs(vim.fn.globpath(dir, "*.lua", false, true)) do
      local name = vim.fn.fnamemodify(f, ":t:r")
      if registered[name] == nil then
        missing[#missing + 1] = name
      end
    end
    table.sort(missing)
    return missing
  end
  local miss_feat = unregistered(proot, modules.feature) -- plugins/*.lua（lang/ 是子目录，不递归）
  local miss_lang = unregistered(proot .. "/lang", modules.lang)
  if #miss_feat == 0 and #miss_lang == 0 then
    h.ok(("开关登记齐全（功能 %d 开 / 语言 %d 开）"):format(#modules.list("feature"), #modules.list("lang")))
  else
    if #miss_feat > 0 then
      h.warn("功能模块未登记、不会加载：" .. table.concat(miss_feat, ", ") .. "  → 去 config/modules.lua 的 M.feature 补一行")
    end
    if #miss_lang > 0 then
      h.warn("语言模块未登记、不会加载：" .. table.concat(miss_lang, ", ") .. "  → 去 config/modules.lua 的 M.lang 补一行")
    end
  end

  h.start("config: 语言就绪度")
  -- 每个语言模块在 plugins/lang/<name>.lua 顶部自己登记"需要哪些工具"（register_lang）；
  -- 关掉的模块根本不会被 import，因此自然不登记、不报告 —— 不再需要在两处维护同一张表。
  local function check_lang(l)
    local missing = {}
    for _, bin in ipairs(l.lsp or {}) do
      if not have(bin) then missing[#missing + 1] = "LSP:" .. bin end
    end
    for _, p in ipairs(l.ts or {}) do
      if not installed_ts[p] then missing[#missing + 1] = "parser:" .. p end
    end
    for _, bin in ipairs(l.fmt or {}) do
      if not have(bin) then missing[#missing + 1] = "fmt:" .. bin end
    end
    for _, bin in ipairs(l.lint or {}) do
      if not have(bin) then missing[#missing + 1] = "lint:" .. bin end
    end
    if #missing == 0 then
      h.ok(l.name)
    else
      h.warn(("%s — 缺 %s"):format(l.name, table.concat(missing, ", ")))
    end
  end
  -- 不随语言模块走的两个：lua 本体；shell 归 plugins/shell.lua（feature 模块）
  check_lang({ name = "lua", lsp = { "lua-language-server" }, ts = { "lua" }, fmt = { "stylua" } })
  check_lang({
    name = "bash / zsh",
    lsp = { "bash-language-server" },
    ts = { "bash", "zsh" },
    fmt = { "shfmt" },
    lint = { "shellcheck" },
  })
  for _, mod in ipairs(modules.list("lang")) do
    local meta = modules.lang_meta[mod]
    if meta then
      check_lang(meta)
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
