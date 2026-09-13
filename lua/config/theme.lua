-- 主题开关：切主题 / 换变体只改这一个文件（和 config/modules.lua 一个思路）。
--
--   active    —— 当前用哪个主题（决定加载哪个主题插件、:colorscheme 用哪个名字）
--   available —— 哪些主题"装上并可选"；不在这里的主题，lazy 既不会安装也不会加载
--   themes    —— 每个主题的全部事实：仓库、lazy 插件名、变体字段、允许取值、当前变体、透明选项片段
--
-- 换变体：改 M.themes.<主题>.variant 的字符串即可（取值见下面的"变体取值一览"）。
-- 换主题：改 active 一行（四个主题都在 available 里，直接改就行；想"只留一个"，把其余行注释掉）。
-- 兜底：active/变体写错、主题没装、setup 报错，load() 都会回退到 M.fallback（catppuccin + frappe）。

local M = {}

-- M.active = "catppuccin"
M.active = "everforest"

-- 四个主题全部登记：这里只表示"允许被 active 选中（并会被 lazy 安装、按需加载）"，
-- 真正用哪个仍然只看上面 active 一行。没登记的主题 lazy 既不安装也不加载。
M.available = {
  "catppuccin",
  "tokyonight",
  "rose-pine",
  "everforest",
}

-- 兜底主题：load() 一旦发现配置有问题、或加载失败就回退到它（它的 spec 永远 enabled）
M.fallback = { name = "catppuccin", variant = "frappe" }

-- 变体取值一览：
--   catppuccin  latte / frappe / macchiato / mocha    （latte 是浅色）
--   tokyonight  night / storm / day / moon            （day 是浅色）
--   rose-pine   main / moon / dawn                    （dawn 是浅色）
--   everforest  hard / medium / soft                  （深浅看 vim.o.background）
M.themes = {
  catppuccin = {
    repo = "catppuccin/nvim",
    plugin = "catppuccin", -- lazy 里的插件名（spec 的 name）
    var_field = "flavour",
    valid = { "latte", "frappe", "macchiato", "mocha" },
    variant = "frappe",
    transparent = function(on)
      return { transparent_background = on }
    end,
  },
  tokyonight = {
    repo = "folke/tokyonight.nvim",
    plugin = "tokyonight.nvim",
    var_field = "style",
    valid = { "night", "storm", "day", "moon" },
    variant = "storm",
    transparent = function(on)
      return { transparent = on }
    end,
  },
  ["rose-pine"] = {
    repo = "rose-pine/neovim",
    plugin = "rose-pine",
    var_field = "variant",
    valid = { "main", "moon", "dawn" },
    variant = "main",
    transparent = function(on)
      return { styles = { transparency = on } }
    end,
  },
  everforest = {
    repo = "neanias/everforest-nvim",
    plugin = "everforest-nvim",
    -- 插件目录叫 everforest-nvim，Lua 模块却叫 everforest。lazy 的隐式 setup(opts) 是
    -- require(main or 插件名).setup(opts)，不写 main 就找不到模块、opts 整个被丢掉（实测：
    -- 报 "Lua module not found for config"，透明设置没生效、Normal 还是实底）。
    main = "everforest",
    var_field = "background",
    valid = { "hard", "medium", "soft" },
    variant = "medium",
    transparent = function(on)
      return { transparent_background_level = on and 2 or 0 }
    end,
  },
}

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
  return (t and t.var_field) and { [t.var_field] = M.variant_of(name) } or {}
end

--- 主题名 → :colorscheme 用的名字。若以后加了"配色名 ≠ 主题名"的主题（nightfox 那种），
--- 就在这里做映射；目前留下的四个主题两者一致。
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
