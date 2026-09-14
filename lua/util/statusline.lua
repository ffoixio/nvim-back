-- 原生状态栏（v1）。
--
-- 入口在 lua/config/options.lua：opt.statusline = [[%!v:lua.require('util.statusline').render()]]
-- 为什么能用 %!：实测 %!expr 的返回值会被**当成状态栏重新解析**（%= 右对齐、%#组# 变色、%< 截断都生效），
-- 而 %{} 只做字面替换；%{%expr%} 与 %! 等效但不能铺满整条。
--
-- 观感（已确认走「扁平」）：所有强调组**只写 fg**，底色一律继承 StatusLine。
--   实测依据：nvim_eval_statusline(..., { highlights = true }) 给的分段是「组栈」——
--   %#SLBranch# 得到 groups = { "StatusLine", "SLBranch" }，自定义组只覆盖自己写了的属性。
--   而 StatusLine 已经在 util/transparency.lua 的 M.follow 里跟着透明开关走（透明 = bg NONE），
--   所以这里没有任何透明/主题特判：换主题、切 <leader>uT 都自动跟随。
--
-- 加一项：在 M.left / M.right 里加一个 id，再在 M.items 里写同名函数。
--   返回 "" = 这一项不显示（拼接时自动跳过）；返回的文本里若含字面 % 必须过 esc()。
local M = {}

local icons = require("config.icons").icons

--- 这些 filetype 不显示状态栏（等价于原 lualine 的 disabled_filetypes）
M.disabled = {
  dashboard = true,
  alpha = true,
  ministarter = true,
  snacks_dashboard = true,
}

--- 左半（模式/分支/根目录/诊断/文件类型/路径/navic）与右半（profiler/noice/更新数/diff/进度/行:列/时钟）
M.left = { "mode", "branch", "root", "diagnostics", "filetype", "path", "navic" }
M.right = { "profiler", "cmd", "rec", "updates", "diff", "progress", "location", "clock" }

--- 状态栏表达式（setup 时若发现选项还是空的，用它兜底；真正生效的那份写在 config/options.lua）
M.expression = [[%!v:lua.require('util.statusline').render()]]

--- 模式：nvim_get_mode().mode 的首字符 -> { 显示名, 取色来源（语义组） }
M.modes = {
  n = { "NORMAL", "Function" },
  i = { "INSERT", "String" },
  v = { "VISUAL", "Constant" },
  V = { "V-LINE", "Constant" },
  ["\22"] = { "V-BLOCK", "Constant" }, -- <C-v> 块选择
  s = { "SELECT", "Constant" },
  S = { "S-LINE", "Constant" },
  R = { "REPLACE", "DiagnosticError" },
  c = { "COMMAND", "Statement" },
  t = { "TERMINAL", "Identifier" },
  ["!"] = { "SHELL", "Special" },
  o = { "OP-PENDING", "Identifier" },
}

--- 强调组 -> fg 来源（语义组名，与主题无关）。模式组由 M.modes 生成（组名 = "SLMode" + 显示名去掉 "-"）
M.fg = {
  SLBranch = "Special",
  SLRoot = "Special",
  SLFiletype = "Special",
  SLUpdates = "Special",
  SLProfiler = "DiagnosticError",
  SLCmd = "Statement",
  SLRec = "Constant",
  SLModified = "MatchParen",
  SLDiagError = "DiagnosticError",
  SLDiagWarn = "DiagnosticWarn",
  SLDiagInfo = "DiagnosticInfo",
  SLDiagHint = "DiagnosticHint",
  -- 只加粗、颜色继承 StatusLine（显式 false = 不查来源组）
  SLFile = false,
  SLDiffAdded = "DiffAdd",
  SLDiffChanged = "DiffChange",
  SLDiffRemoved = "DiffDelete",
}

--- 只加样式、不加颜色的组（文件名加粗；颜色继承 StatusLine 的 fg）
M.bold = { SLFile = true }

--- 字面 % 转义（状态栏语法里 %% 显示成一个 %）
---@param text any
---@return string
local function esc(text)
  return (tostring(text or ""):gsub("%%", "%%%%"))
end

--- 包一个高亮组：%#组#文本%*（%* = 回到基础组 StatusLine）
local function hl(name, text)
  return "%#" .. name .. "#" .. text .. "%*"
end

--- 模式名 -> 组名（"V-BLOCK" -> "SLModeVBLOCK"）
local function mode_group(name)
  return "SLMode" .. name:gsub("%-", "")
end

--- 建/刷高亮组。时机：ColorScheme、VeryLazy，以及 setup()。只写 fg，底色留给 StatusLine。
function M.build()
  local sl = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
  local function source_fg(src)
    if not src then
      return sl.fg
    end
    return vim.api.nvim_get_hl(0, { name = src, link = false }).fg or sl.fg
  end
  for name, src in pairs(M.fg) do
    vim.api.nvim_set_hl(0, name, { fg = source_fg(src), bold = M.bold[name] or nil })
  end
  for _, spec in pairs(M.modes) do
    vim.api.nvim_set_hl(0, mode_group(spec[1]), { fg = source_fg(spec[2]), bold = true })
  end
  -- navic 自己的 Navic* 组：去掉底色。catppuccin 那边已经把 custom_bg 改成 NONE，
  -- 这里再兜一层，换到别的主题也不会在状态栏里留一块实底。
  for _, name in ipairs(vim.fn.getcompletion("Navic", "highlight")) do
    local h = vim.api.nvim_get_hl(0, { name = name, link = false })
    if h.bg ~= nil then
      h.bg = "NONE"
      vim.api.nvim_set_hl(0, name, h --[[@as vim.api.keyset.highlight]])
    end
  end
end

-- ===== 各项 =====
-- 约定：返回 "" 表示不显示；返回值是状态栏语法片段。

M.items = {}

---@param ctx { mode: string }
function M.items.mode(ctx)
  local spec = M.modes[ctx.mode:sub(1, 1)] or { ctx.mode:upper(), "Special" }
  return hl(mode_group(spec[1]), spec[1])
end

function M.items.branch()
  local head = vim.b.gitsigns_head
  if type(head) ~= "string" or head == "" then
    return ""
  end
  return hl("SLBranch", " " .. esc(head))
end

function M.items.root()
  if vim.bo.buftype ~= "" or vim.fn.expand("%:p") == "" then
    return ""
  end
  local ok, root = pcall(function()
    return require("util.root").get({ normalize = true })
  end)
  local name = ok and root and vim.fs.basename(root) or ""
  if name == "" then
    return ""
  end
  return hl("SLRoot", "󱉭 " .. esc(name))
end

--- 诊断计数：icon + 数字，为 0 的级别不显示
local DIAG = {
  { 1, "SLDiagError", icons.diagnostics.Error },
  { 2, "SLDiagWarn", icons.diagnostics.Warn },
  { 3, "SLDiagInfo", icons.diagnostics.Info },
  { 4, "SLDiagHint", icons.diagnostics.Hint },
}

function M.items.diagnostics()
  local counts = vim.diagnostic.count(0)
  if type(counts) ~= "table" or vim.tbl_isempty(counts) then
    return ""
  end
  local out = {}
  for _, d in ipairs(DIAG) do
    local n = counts[d[1]] or 0
    if n > 0 then
      out[#out + 1] = hl(d[2], d[3] .. n)
    end
  end
  return table.concat(out, " ")
end

function M.items.filetype()
  local ft = vim.bo.filetype
  if ft == "" then
    return ""
  end
  local icon
  if package.loaded["snacks"] and Snacks.util then
    local ok, ic = pcall(Snacks.util.icon, ft, "filetype")
    icon = ok and ic or nil
  end
  if type(icon) ~= "string" or icon == "" then
    return hl("SLFiletype", esc(ft))
  end
  return hl("SLFiletype", icon)
end

--- 短路径的分解：相对 root（否则 cwd），最多 3 段，超出用 … 顶掉中间
---@return string[]?
local function path_parts()
  local path = vim.fn.expand("%:p")
  if path == "" then
    return nil
  end
  local U = require("util.init")
  local root_mod = require("util.root")
  path = U.norm(path)
  local cwd = root_mod.cwd()
  local root = root_mod.get({ normalize = true })
  if cwd ~= "" and path:find(cwd, 1, true) == 1 then
    path = path:sub(#cwd + 2)
  elseif root and path:find(root, 1, true) == 1 then
    path = path:sub(#root + 2)
  end
  local parts = vim.split(path, "[\\/]")
  if #parts > 3 then
    parts = { parts[1], "…", unpack(parts, #parts - 1, #parts) }
  end
  return parts
end

--- 路径。%< 放在这一项的开头：窗口太窄时从左边先截掉（和原 lualine 把 %< 放在 c 段起点一致）
function M.items.path()
  if vim.bo.buftype ~= "" then
    return ""
  end
  local parts = path_parts()
  if not parts or parts[#parts] == "" then
    return ""
  end
  local name = parts[#parts]
  local dir = ""
  if #parts > 1 then
    dir = table.concat({ unpack(parts, 1, #parts - 1) }, "/") .. "/"
  end
  local name_hl = vim.bo.modified and "SLModified" or "SLFile"
  local out = "%<" .. esc(dir) .. hl(name_hl, esc(name))
  if vim.bo.readonly then
    out = out .. hl("SLModified", " 󰌾 ")
  end
  return out
end

--- navic 面包屑：它自己就产出 %#NavicIconsX#…#%* 片段（配置里 highlight = true）
function M.items.navic()
  if not package.loaded["nvim-navic"] then
    return ""
  end
  local navic = require("nvim-navic")
  local ok, available = pcall(navic.is_available, 0)
  if not ok or not available then
    return ""
  end
  local ok2, loc = pcall(navic.get_location)
  if not ok2 or type(loc) ~= "string" or loc == "" then
    return ""
  end
  return loc
end

--- snacks 的剖析器：只在运行时出现（文本沿用 snacks 自己那一份）
function M.items.profiler()
  if not package.loaded["snacks"] or not Snacks.profiler then
    return ""
  end
  if not Snacks.profiler.running() then
    return ""
  end
  local ok, component = pcall(Snacks.profiler.status)
  local text = ok and type(component) == "table" and component[1] and component[1]() or nil
  if type(text) ~= "string" or text == "" then
    return ""
  end
  return hl("SLProfiler", esc(text))
end

--- noice 的两项（命令 / 模式如 recording）。noice 的 get() 已经自己转义过 %
local function noice_item(key, group_name)
  if not package.loaded["noice"] then
    return ""
  end
  local ok, api = pcall(function()
    return require("noice").api.status[key]
  end)
  if not ok or type(api) ~= "table" then
    return ""
  end
  local ok_has, has = pcall(api.has)
  if not ok_has or not has then
    return ""
  end
  local ok_get, text = pcall(api.get)
  if not ok_get or type(text) ~= "string" or text == "" then
    return ""
  end
  return hl(group_name, text)
end

function M.items.cmd()
  return noice_item("command", "SLCmd")
end

function M.items.rec()
  return noice_item("mode", "SLRec")
end

--- lazy.nvim 的可用更新数（没有更新时 updates() 返回 false，必须兜底）
function M.items.updates()
  if not package.loaded["lazy"] then
    return ""
  end
  local ok, upd = pcall(function()
    return require("lazy.status").updates()
  end)
  if not ok or type(upd) ~= "string" or upd == "" then
    return ""
  end
  return hl("SLUpdates", esc(upd))
end

--- gitsigns 的增/改/删行数
function M.items.diff()
  local g = vim.b.gitsigns_status_dict
  if type(g) ~= "table" then
    return ""
  end
  local out = {}
  if (g.added or 0) > 0 then
    out[#out + 1] = hl("SLDiffAdded", icons.git.added .. g.added)
  end
  if (g.changed or 0) > 0 then
    out[#out + 1] = hl("SLDiffChanged", icons.git.modified .. g.changed)
  end
  if (g.removed or 0) > 0 then
    out[#out + 1] = hl("SLDiffRemoved", icons.git.removed .. g.removed)
  end
  return table.concat(out, " ")
end

--- 进度：首行 Top、末行 Bot、其余按百分比（和原 lualine 的 progress 一致，含 %2d 对齐）
function M.items.progress()
  local cur, total = vim.fn.line("."), vim.fn.line("$")
  if total <= 0 then
    return ""
  end
  if cur == 1 then
    return "Top"
  end
  if cur == total then
    return "Bot"
  end
  return ("%2d%%%%"):format(math.floor(cur / total * 100))
end

--- 行:列。用 line()/charcol() 而不是原生 %l:%c：空 buffer 时原生给 "0:0"，而这里是 1:1，
--- 且 charcol 按字符（多字节）计数——都和原 lualine 的 location 组件一致（格式 %3d:%-2d）
function M.items.location()
  return ("%3d:%-2d"):format(vim.fn.line("."), vim.fn.charcol("."))
end

function M.items.clock()
  return "󰥔 " .. os.date("%R")
end

-- ===== 组装 =====

---@param ids string[]
---@param ctx table
---@return string
local function side(ids, ctx)
  local out = {}
  for _, id in ipairs(ids) do
    local fn = M.items[id]
    if fn then
      local ok, text = pcall(fn, ctx)
      if ok and type(text) == "string" and text ~= "" then
        out[#out + 1] = text
      end
    end
  end
  return table.concat(out, " ")
end

--- 状态栏渲染入口。每帧都会跑：只做便宜的事；以后哪个项贵了，单独给它加缓存。
---@return string
function M.render()
  local ok, ret = pcall(function()
    if M.disabled[vim.bo.filetype] then
      return ""
    end
    local ctx = {
      buf = vim.api.nvim_get_current_buf(),
      win = vim.api.nvim_get_current_win(),
      mode = vim.api.nvim_get_mode().mode,
    }
    local left, right = side(M.left, ctx), side(M.right, ctx)
    if left == "" and right == "" then
      return ""
    end
    return " " .. left .. "%=" .. right .. " "
  end)
  return ok and ret or ""
end

--- 挂上 ColorScheme / VeryLazy 的刷新；若 statusline 选项还是空的就补上表达式。
function M.setup()
  local aug = vim.api.nvim_create_augroup("config_statusline", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = aug,
    callback = function()
      M.build()
    end,
  })
  -- 插件可能在 ColorScheme 之后才建自己的组（navic 的 Navic* 等），VeryLazy 再刷一遍
  vim.api.nvim_create_autocmd("User", {
    group = aug,
    pattern = "VeryLazy",
    once = true,
    callback = function()
      M.build()
    end,
  })
  if vim.o.statusline == "" or vim.o.statusline == " " then
    vim.o.statusline = M.expression
  end
  M.build()
end

return M
