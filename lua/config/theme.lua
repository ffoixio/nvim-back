-- 主题开关：切主题 / 换变体只改这一个文件（和 config/modules.lua 一个思路）。
--
--   active    —— 当前用哪个主题（决定加载哪个主题插件、:colorscheme 用哪个名字）
--   available —— 哪些主题"装上并可选"；不在这里的主题，lazy 既不会安装也不会加载
--   variant   —— 每个主题用哪个变体。下面把每个主题的**全部取值**都列了出来，
--                除了当前在用的那行，其余都注释着。
--
-- 换变体两种写法等价，随便挑：
--   ① 直接改当前生效那行的字符串（只改一处，推荐）；
--   ② 把目标那行取消注释、把当前那行注释掉。
--
-- 每个主题"变体"字段名不同，映射见 var_field；nightfox 例外 —— 它的变体本身就是 colorscheme 名，
-- 由 scheme() 处理。
--
-- 换到非 catppuccin 主题时还要确认两件事（详见 TRANSPARENCY.md 的"换主题"）：
--   ① 该主题的透明选项名 —— plugins/colorscheme.lua 里每个主题块的 extra 都写了，首次用要确认是否生效；
--   ② util/transparency.lua 的 palette() 目前只认 catppuccin，关掉透明时面板底色会用错颜色。

local M = {}

M.active = "catppuccin"

M.available = {
  "catppuccin",
  -- 想用哪个就取消注释（tokyonight 之前已经装过，其余几个会在下次启动时自动装）
  -- "tokyonight",
  -- "rose-pine",
  -- "nightfox",
  -- "gruvbox",
  -- "everforest",
}

--- 各主题"变体"在 opts 里的字段名（nightfox 没有：它的变体是独立的 colorscheme 名）
M.var_field = {
  catppuccin = "flavour",
  tokyonight = "style",
  ["rose-pine"] = "variant",
  gruvbox = "contrast",
  everforest = "background",
}

M.variant = {
  -- ── catppuccin（当前使用）────────────────────────────
  catppuccin = "frappe",
  -- catppuccin = "latte"        -- 浅色
  -- catppuccin = "macchiato"
  -- catppuccin = "mocha"

  -- ── tokyonight（需先在 available 里取消注释）──────────
  -- tokyonight = "storm"
  -- tokyonight = "night"
  -- tokyonight = "moon"
  -- tokyonight = "day"          -- 浅色

  -- ── rose-pine ────────────────────────────────────────
  -- ["rose-pine"] = "main"
  -- ["rose-pine"] = "moon"
  -- ["rose-pine"] = "dawn"      -- 浅色

  -- ── gruvbox（深浅由 vim.o.background 决定）────────────
  -- gruvbox = "hard"
  -- gruvbox = "soft"
  -- gruvbox = ""                -- 默认对比度

  -- ── everforest（深浅由 vim.o.background 决定）─────────
  -- everforest = "hard"
  -- everforest = "medium"
  -- everforest = "soft"

  -- ── nightfox（变体是独立主题名，由 scheme() 取用）─────
  -- nightfox = "duskfox"        -- 深色（偏紫）
  -- nightfox = "nightfox"       -- 深色（默认）
  -- nightfox = "nordfox"
  -- nightfox = "terafox"
  -- nightfox = "carbonfox"
  -- nightfox = "dayfox"         -- 浅色
  -- nightfox = "dawnfox"        -- 浅色
}

-- 兜底主题：config/lazy.lua 的 load() 一旦发现配置有问题就回退到它，
-- 所以 catppuccin 的 spec 块永远 enabled（见 plugins/colorscheme.lua）。
M.fallback = { name = "catppuccin", variant = "frappe" }

--- 有对应 spec 块的主题（新增主题时这里也要加，否则会被当成非法配置而回退）
M.known = { "catppuccin", "tokyonight", "rose-pine", "nightfox", "gruvbox", "everforest" }

--- 主题名 → lazy 里的插件名（加载前先把它 lazy.load 进来：非当前主题时它是懒加载的，
--- 直接 :colorscheme 会在插件还没跑完 setup 时执行，实测会导致变体和透明都没生效）
M.plugin = {
  catppuccin = "catppuccin", -- spec 里写了 name = "catppuccin"
  tokyonight = "tokyonight.nvim",
  ["rose-pine"] = "rose-pine",
  nightfox = "nightfox.nvim",
  gruvbox = "gruvbox.nvim",
  everforest = "everforest-nvim",
}

--- 每个主题允许的变体取值（写错时不必等主题报错，这里就能拦住并回退）
M.valid = {
  catppuccin = { "latte", "frappe", "macchiato", "mocha" },
  tokyonight = { "night", "storm", "day", "moon" },
  ["rose-pine"] = { "main", "moon", "dawn" },
  gruvbox = { "hard", "soft", "" },
  everforest = { "hard", "medium", "soft" },
  nightfox = { "nightfox", "dayfox", "dawnfox", "duskfox", "nordfox", "terafox", "carbonfox" },
}

--- 校验配置：返回 (主题名, 变体)，或 (nil, 出错原因)
local function pick()
  local name = M.active
  if not vim.tbl_contains(M.known, name) then
    return nil, ("主题 %q 没有对应的 spec 块（config/theme.lua 的 known 里没有它）"):format(tostring(name))
  end
  local valid = M.valid[name]
  local variant = M.variant[name]
  if variant == nil then
    return nil, ("没有给 %s 指定变体（config/theme.lua 里那一行还注释着？）"):format(name)
  end
  if valid and not vim.tbl_contains(valid, variant) then
    return nil, ("%s 的变体 %q 不在允许列表里：%s"):format(name, tostring(variant), table.concat(vim.tbl_map(tostring, valid), " / "))
  end
  if not M.enabled(name) then
    return nil, ("主题 %q 不在 available 里，lazy 不会加载它"):format(name)
  end
  return name, variant
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
    local key = M.plugin[theme_name]
    if key then
      pcall(require("lazy").load, { plugins = { key } })
    end
    return (pcall(vim.cmd.colorscheme, scheme))
  end

  if try(name, M.scheme(name)) then
    return
  end
  -- 目标主题加载失败（插件没装、名字错、setup 报错）→ 兜底
  if name == M.fallback.name and variant == M.fallback.variant then
    vim.notify("catppuccin/frappe 都加载失败，请检查配色插件是否装好", vim.log.levels.ERROR)
    return
  end
  vim.notify(("%s 加载失败，已回退 catppuccin/%s"):format(name, M.fallback.variant), vim.log.levels.WARN)
  -- 兜底：① 先用 frappe 重新 setup 一次（问题可能就出在 flavour 写错，catppuccin 会记住它）；
  -- ② 再按基础名加载（catppuccin 只有 colors/catppuccin.lua，-frappe 那个名字是不存在的，
  --    带后缀的 colors_name 是它自己在加载后写的）。
  pcall(function()
    require("catppuccin").setup({ flavour = M.fallback.variant })
  end)
  if not try(M.fallback.name, M.scheme(M.fallback.name)) then
    vim.notify("回退 catppuccin 也失败了，请检查插件是否装好", vim.log.levels.ERROR)
  end
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
--- 关键点：这个值会直接进各主题的 opts，而 opts 在 spec 求值时就送给插件了 ——
--- 所以必须在源头就换成合法值，否则主题已经带着错值 setup 过，事后回退也救不回来。
---@param name string
---@return string
function M.variant_of(name)
  local v = M.variant[name]
  local valid = M.valid[name]
  if v == nil or (valid and not vim.tbl_contains(valid, v)) then
    return M.fallback.variant -- 硬编码的 frappe，不能从 M.variant 取（那里可能正是错值）
  end
  return v
end

--- 该主题用来切变体的 opts 片段（该主题没有变体字段时返回空表）
---@param name string
---@return table
function M.opts(name)
  local field = M.var_field[name]
  return field and { [field] = M.variant_of(name) } or {}
end

--- 主题名 → :colorscheme 用的名字（nightfox 的变体本身就是主题名）
---@param name string
---@return string
function M.scheme(name)
  if name == "nightfox" then
    return M.variant_of(name)
  end
  return name
end

return M
