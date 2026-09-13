-- 主题开关：切主题 / 换变体只改这一个文件（和 config/modules.lua 一个思路）。
--
--   active    —— 当前用哪个主题（决定加载哪个主题插件、:colorscheme 用哪个名字）
--   available —— 哪些主题"装上并可选"；不在这里的主题，lazy 既不会安装也不会加载
--   themes    —— 每个主题的全部事实：仓库、lazy 插件名、变体字段、允许取值、当前变体、透明选项片段
--
-- 换变体：<leader>uC 里每个主题的变体都能直接选（选中即生效并记住）；也可以改
--         M.themes.<主题>.variant 当默认值（取值见下面的"变体取值一览"）。
-- 换主题：<leader>uC（= M.pick()）选一个，会写进状态文件、下次启动沿用，不用改文件也不用提交；
--         想改的是"默认值"才动下面的 active 一行（状态文件不存在时用它）。
-- 兜底：active/变体写错、主题没装、setup 报错，load() 都会回退到 M.fallback（catppuccin + frappe）。

local M = {}

-- 默认主题：只在没有状态文件（<leader>uC 选过就会有）时生效，所以可以放心提交
M.active = "catppuccin"
-- M.active = "everforest"

-- 三个主题全部登记：这里只表示"允许被选中（并会被 lazy 安装、按需加载）"。
-- 没登记的主题 lazy 既不安装也不加载；真正用哪个由 <leader>uC 的状态文件决定，默认值看上面 active。
M.available = {
  "catppuccin",
  "tokyonight",
  "everforest",
}

-- 兜底主题：load() 一旦发现配置有问题、或加载失败就回退到它（它的 spec 永远 enabled）
M.fallback = { name = "catppuccin", variant = "frappe" }

-- 变体取值一览（只留自己在用的；想加回来把值写进对应主题的 valid 即可）：
--   catppuccin  frappe / macchiato / mocha
--   tokyonight  storm
--   everforest  soft
M._applied = {} -- 每个主题最近一次真正配下去的变体（供 load() 判断变体是否变了）

M.themes = {
  catppuccin = {
    repo = "catppuccin/nvim",
    plugin = "catppuccin", -- lazy 里的插件名（spec 的 name）
    var_field = "flavour",
    module = "catppuccin",
    valid = { "frappe", "macchiato", "mocha" },
    variant = "frappe",
    transparent = function(on)
      return { transparent_background = on }
    end,
  },
  tokyonight = {
    repo = "folke/tokyonight.nvim",
    plugin = "tokyonight.nvim",
    var_field = "style",
    module = "tokyonight",
    valid = { "storm" },
    variant = "storm",
    transparent = function(on)
      return { transparent = on }
    end,
  },
  everforest = {
    repo = "neanias/everforest-nvim",
    plugin = "everforest-nvim",
    -- module = Lua 模块名（插件目录叫 everforest-nvim，模块叫 everforest）。它同时充当
    -- lazy 隐式 setup 用的 spec.main，以及运行时补 setup() 时 require 的名字。
    module = "everforest",
    var_field = "background",
    valid = { "soft" },
    variant = "soft",
    transparent = function(on)
      return { transparent_background_level = on and 2 or 0 }
    end,
  },
}

-- ===== 运行时切换 + 记忆（<leader>uC）=====
-- 选中的主题/变体会写到 stdpath("state")/theme，下次启动优先用它；所以上面的 M.active 与
-- M.themes.<主题>.variant 只是"没有状态文件时的默认值"，可以安心提交。
M.state = vim.fn.stdpath("state") .. "/theme"

-- 记一份文件里的默认值，reset() 用（下面的 restore 会就地覆盖 active / variant）
M.defaults = { active = M.active, variants = {} }
for name, t in pairs(M.themes) do
  M.defaults.variants[name] = t.variant
end

--- 读状态文件：返回 (主题名, 变体或 nil)；文件不存在或内容非法时返回 nil
---@return string?, string?
function M.saved()
  local f = io.open(M.state, "r")
  if not f then
    return nil
  end
  local line = f:read("*l") or ""
  f:close()
  local name, variant = line:match("^(%S+)%s*(%S*)$")
  local t = name and M.themes[name]
  if not t or not vim.tbl_contains(M.available, name) then
    return nil
  end
  if variant == "" or not vim.tbl_contains(t.valid, variant) then
    variant = nil
  end
  return name, variant
end

-- 启动时套用记忆。必须在这里（模块加载时）执行：config/lazy.lua 里的 spec 求值更晚，
-- 各主题 spec 的 opts 才能拿到记住的那个变体。
do
  local name, variant = M.saved()
  if name then
    M.active = name
    if variant then
      M.themes[name].variant = variant
    end
  end
end

--- 运行时切换主题并记住（variant 省略则用该主题登记的变体）
---@param name string
---@param variant? string
function M.set(name, variant)
  local t = M.themes[name]
  if not t or not vim.tbl_contains(M.available, name) then
    vim.notify(("主题 %q 不在 available 里"):format(tostring(name)), vim.log.levels.WARN)
    return
  end
  if variant ~= nil then
    if not vim.tbl_contains(t.valid, variant) then
      vim.notify(("%s 没有变体 %q"):format(name, tostring(variant)), vim.log.levels.WARN)
      return
    end
    t.variant = variant
  end
  M.active = name
  vim.fn.mkdir(vim.fn.fnamemodify(M.state, ":h"), "p")
  vim.fn.writefile({ variant and ("%s %s"):format(name, variant) or name }, M.state)
  M.load()
end

-- 透明开关变化时重配当前主题（M.load 里会带着新的 transparent 选项重新 setup + :colorscheme）
vim.api.nvim_create_autocmd("User", {
  pattern = "TransparencyChanged",
  callback = function()
    M.load()
  end,
})

--- 清除记忆，回到文件里的默认主题/变体
function M.reset()
  vim.fn.delete(M.state)
  M.active = M.defaults.active
  for name, variant in pairs(M.defaults.variants) do
    M.themes[name].variant = variant
  end
  M.load()
end

--- 供 picker 用：三个主题 × 各自合法变体，每条一个候选
---@return { name: string, variant: string, current: boolean }[]
function M.items()
  local out = {}
  for _, name in ipairs(M.list()) do
    if vim.tbl_contains(M.available, name) then
      local t = M.themes[name]
      for _, variant in ipairs(t.valid) do
        out[#out + 1] = {
          name = name,
          variant = variant,
          current = M.is(name) and M.variant_of(name) == variant,
        }
      end
    end
  end
  return out
end

--- <leader>uC 的选择器
function M.pick()
  Snacks.picker.select(M.items(), {
    prompt = "主题（选中即记住；重置用 :lua require('config.theme').reset()）",
    format_item = function(item)
      return ("%-11s %-10s %s"):format(item.name, item.variant, item.current and "← 当前" or "")
    end,
  }, function(item)
    if item then
      M.set(item.name, item.variant)
    end
  end)
end

--- 有 spec 块的主题名（字母序，保证每次加载顺序一致）
---@return string[]
function M.list()
  local names = vim.tbl_keys(M.themes)
  table.sort(names)
  return names
end

--- 当前生效的是不是这个主题
---@param name string
---@return boolean
function M.is(name)
  return M.active == name
end

--- 这个主题要不要装上并可选（当前主题一定可用）
---@param name string
---@return boolean
function M.enabled(name)
  return M.is(name) or vim.tbl_contains(M.available, name)
end

--- 该主题**实际生效**的变体：写了非法值/没写，就用兜底变体（frappe）。
--- 这个值会直接进各主题的 opts，而 opts 在 spec 求值时就送给插件了 —— 必须在源头换成合法值。
---@param name string
---@return string
function M.variant_of(name)
  local t = M.themes[name]
  if not t then
    return M.fallback.variant
  end
  if t.variant == nil or not vim.tbl_contains(t.valid, t.variant) then
    return M.fallback.variant
  end
  return t.variant
end

--- 该主题用来切变体的 opts 片段（该主题没有变体字段时返回空表）
---@param name string
---@return table
function M.opts(name)
  local t = M.themes[name]
  if not (t and t.var_field) then
    return {}
  end
  local variant = M.variant_of(name)
  -- 记下"当前已经交给 spec / setup 过的配置"，load() 靠它判断要不要补 setup（见那里的注释）。
  -- 键里带上透明状态：透明同样是主题自己的选项（M.themes.<主题>.transparent(on)），
  -- 光改变体不够 —— 关掉透明时要让主题重新配一遍，否则那些组没有可恢复的实底颜色。
  M._applied[name] = variant .. "|" .. tostring(require("util.transparency").default())
  return { [t.var_field] = variant }
end

--- 主题名 → :colorscheme 用的名字。若以后加了"配色名 ≠ 主题名"的主题（nightfox 那种），
--- 就在这里做映射；目前留下的三个主题两者一致。
---@param name string
---@return string
function M.scheme(name)
  return name
end

--- 校验配置：返回 (主题名, 变体)，或 (nil, 出错原因)
local function pick()
  local name = M.active
  local t = M.themes[name]
  if not t then
    return nil, ("主题 %q 没有登记（M.themes 里没有它）"):format(tostring(name))
  end
  if t.variant == nil then
    return nil, ("没有给 %s 指定变体（M.themes.%s.variant 还是空的？）"):format(name, name)
  end
  if not vim.tbl_contains(t.valid, t.variant) then
    return nil, ("%s 的变体 %q 不在允许列表里：%s"):format(name, tostring(t.variant), table.concat(vim.tbl_map(tostring, t.valid), " / "))
  end
  -- available 是"装上并可选"的开关：active 必须也在里面（否则 lazy 不会加载/安装它，直接回退更安全）
  if not vim.tbl_contains(M.available, name) then
    return nil, ("主题 %q 不在 available 里（config/theme.lua 里那行还注释着？）"):format(name)
  end
  return name, t.variant
end

--- 加载当前主题。任何一步出问题（名字写错 / 变体写错 / 主题没装 / setup 报错）都回退到
--- catppuccin + frappe —— 保证编辑器永远有一个可用的配色。
function M.load()
  local name, variant = pick()
  if not name then
    vim.notify("主题配置有问题：" .. tostring(variant) .. "；已回退 catppuccin/frappe", vim.log.levels.WARN)
    name, variant = M.fallback.name, M.fallback.variant
  end

  -- ① 先把插件真正加载好（非当前主题时它是懒加载的，不等它跑完 setup 就 :colorscheme，
  --    变体和透明都会不生效 —— 实测）；② 再 :colorscheme，失败会抛 E185，pcall 接住。
  local function try(theme_name, scheme)
    pcall(require("lazy").load, { plugins = { M.themes[theme_name].plugin } })
    -- 变体（flavour / style / background）是启动时算进 spec opts 的，运行中改 variant 不会自动
    -- 生效 —— 实测切 frappe -> mocha 颜色不变。各主题的 setup 都是深合并，补一次只传变体不会
    -- 丢掉其它已设选项。但**必须只在变体真的变了时补**：启动时 lazy 已经拿完整 opts 配过一遍，
    -- 再 setup 一次会打乱编译好的配色（实测有底色的组数 123 -> 108、启动 27ms -> 42ms）。
    local t = M.themes[theme_name]
    local on = require("util.transparency").default()
    if M._applied[theme_name] ~= (M.variant_of(theme_name) .. "|" .. tostring(on)) then
      local ok, mod = pcall(require, t.module)
      if ok and type(mod) == "table" and type(mod.setup) == "function" then
        -- 变体 + 该主题自己的透明选项一起给（M.opts 内部会把新状态记进 _applied）
        pcall(mod.setup, vim.tbl_deep_extend("force", M.opts(theme_name), t.transparent(on)))
      end
    end
    return (pcall(vim.cmd.colorscheme, scheme))
  end

  if try(name, M.scheme(name)) then
    return
  end
  if name == M.fallback.name and variant == M.fallback.variant then
    vim.notify("catppuccin/frappe 都加载失败，请检查配色插件是否装好", vim.log.levels.ERROR)
    return
  end
  vim.notify(("%s 加载失败，已回退 catppuccin/%s"):format(name, M.fallback.variant), vim.log.levels.WARN)
  -- 兜底：① 先用 frappe 重新 setup 一次（问题可能就出在 flavour 上）；
  -- ② 再按基础名加载（catppuccin 只有 colors/catppuccin.lua，-frappe 那个名字不存在）。
  pcall(function()
    require("catppuccin").setup({ flavour = M.fallback.variant })
  end)
  if not try(M.fallback.name, M.scheme(M.fallback.name)) then
    vim.notify("回退 catppuccin 也失败了，请检查插件是否装好", vim.log.levels.ERROR)
  end
end

return M
