-- 键位注册追踪：记录每一次 keymap.set，并保留「钩子安装前」的映射快照。
--
-- 存在的理由：nvim_get_keymap 只返回每个 lhs **最终生效**的那一个，看不见被覆盖的键位 ——
-- <leader>uT 撞键那次就是这么漏掉的。health 的键位小节靠这里的记录报出「同键被覆盖」。
-- 装得越早越好（config/lazy.lua 里在 lazy.setup 之前调用），这样 before 快照里只有 nvim
-- 自带/更早的映射。开销：每次 keymap.set 多一次表插入，实测无感。
local M = {}

M.before = {} ---@type table<string, string>  钩子安装前已有的映射 ["mode|lhs"] = desc
M.log = {} ---@type { mode: string, lhs: string, desc: string }[]
M.enabled = false

local MODES = { "n", "x", "o", "i", "t", "c", "s", "l" }

--- 装上追踪钩子（幂等）
function M.setup()
  if M.enabled then
    return
  end
  M.enabled = true
  for _, m in ipairs(MODES) do
    for _, k in ipairs(vim.api.nvim_get_keymap(m)) do
      M.before[m .. "|" .. k.lhs] = k.desc or ""
    end
  end

  local function rec(mode, lhs, desc)
    local ms = type(mode) == "table" and mode or { mode }
    for _, m in ipairs(ms) do
      M.log[#M.log + 1] = { mode = m, lhs = lhs, desc = desc or "" }
    end
  end

  local set = vim.keymap.set
  local in_wrapper = false
  vim.keymap.set = function(mode, lhs, rhs, opts)
    rec(mode, lhs, opts and opts.desc)
    in_wrapper = true
    local ok, res = pcall(set, mode, lhs, rhs, opts)
    in_wrapper = false
    if not ok then
      error(res)
    end
    return res
  end

  local nsk = vim.api.nvim_set_keymap
  vim.api.nvim_set_keymap = function(mode, lhs, rhs, opts)
    if not in_wrapper then -- vim.keymap.set 内部会调它，别重复记
      rec(mode, lhs, opts and opts.desc)
    end
    return nsk(mode, lhs, rhs, opts)
  end
end

--- 汇总
---@return { duplicated: table[], overwritten: table[] }
function M.report()
  local seen = {}
  local duplicated = {}
  for _, e in ipairs(M.log) do
    local key = e.mode .. "|" .. e.lhs
    if seen[key] ~= nil and seen[key] ~= e.desc then
      duplicated[#duplicated + 1] = { key = key, old = seen[key], new = e.desc }
    end
    seen[key] = e.desc
  end
  local overwritten = {}
  for _, e in ipairs(M.log) do
    local key = e.mode .. "|" .. e.lhs
    local old = M.before[key]
    if old ~= nil and old ~= e.desc then
      overwritten[#overwritten + 1] = { key = key, old = old, new = e.desc }
    end
  end
  return { duplicated = duplicated, overwritten = overwritten }
end

return M