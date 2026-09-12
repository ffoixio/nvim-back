-- 主题开关：切主题只改这一个文件（和 config/modules.lua 一个思路）。
--
--   active    —— 当前用哪个主题（决定加载哪个主题插件、:colorscheme 用哪个名字）
--   available —— 同时"装上并可选"的主题（<leader>uC / :colorscheme 里能看到、能临时预览）
--   variant   —— 每个主题的变体；各主题字段名不同，映射见 var_field
--
-- 切主题：只改 active 一行 —— variant 里每个主题的值都一直留着，不用注释/反注释。
-- 加主题：available 里加名字 + variant 里写它的值 + plugins/colorscheme.lua 里补一个 spec 块。
--
-- 注意：换到非 catppuccin 主题时，透明那块还要确认两件事（见 TRANSPARENCY.md 的"换主题"一节）：
--   ① 该主题的透明选项名（下面 extra 里各写了一个，第一次用要确认是否生效）；
--   ② util/transparency.lua 的 palette() 目前只认 catppuccin，关闭透明时会用错颜色。

local M = {}

M.active = "catppuccin"

M.available = {
  "catppuccin",
  "tokyonight",
}

--- 各主题"变体"在 opts 里的字段名（nightfox 没有：它的变体是独立的 colorscheme 名）
M.var_field = {
  catppuccin = "flavour", -- latte / frappe / macchiato / mocha
  tokyonight = "style", -- night / storm / day / moon
  ["rose-pine"] = "variant", -- main / moon / dawn
  gruvbox = "contrast", -- hard / soft / ""（深浅看 vim.o.background）
  everforest = "background", -- hard / medium / soft
}

M.variant = {
  catppuccin = "frappe",
  tokyonight = "storm",
  ["rose-pine"] = "main",
  gruvbox = "hard",
  everforest = "medium",
  nightfox = "duskfox", -- nightfox / dayfox / dawnfox / duskfox / nordfox / terafox / carbonfox
}

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

--- 该主题用来切变体的 opts 片段（该主题没有变体字段时返回空表）
---@param name string
---@return table
function M.opts(name)
  local field = M.var_field[name]
  return field and { [field] = M.variant[name] } or {}
end

--- 主题名 → :colorscheme 用的名字（nightfox 的变体本身就是主题名）
---@param name string
---@return string
function M.scheme(name)
  if name == "nightfox" then
    return M.variant[name] or "nightfox"
  end
  return name
end

return M
