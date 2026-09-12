local M = {}

-- capture global option defaults at startup, used by set_default
M._options = {}
function M.setup()
  M._options.indentexpr = vim.o.indentexpr
  M._options.foldmethod = vim.o.foldmethod
  M._options.foldexpr = vim.o.foldexpr
end

--- normalize a path (expand ~, use forward slashes, collapse duplicates, trim trailing slash)
--- $XDG_CONFIG_HOME（或 ~/.config）下是否存在某个相对路径
---@param rel string
---@return boolean
function M.config_exists(rel)
  local root = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")
  return vim.uv.fs_stat(root .. "/" .. rel) ~= nil
end

function M.norm(path)
  if path:sub(1, 1) == "~" then
    local home = vim.uv.os_homedir()
    if home:sub(-1) == "/" then
      home = home:sub(1, -2)
    end
    path = home .. path:sub(2)
  end
  path = path:gsub("\\", "/"):gsub("/+", "/")
  return path:sub(-1) == "/" and path:sub(1, -2) or path
end

-- fast check whether a table is a list
function M.is_list(t)
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then
      return false
    end
  end
  return true
end

local function can_merge(v)
  return type(v) == "table" and (vim.tbl_isempty(v) or not M.is_list(v))
end

--- deep merge with force behavior (in-place, supports non-table values)
function M.merge(...)
  local ret = select(1, ...)
  if ret == vim.NIL then
    ret = nil
  end
  for i = 2, select("#", ...) do
    local value = select(i, ...)
    if can_merge(ret) and can_merge(value) then
      for k, v in pairs(value) do
        ret[k] = M.merge(ret[k], v)
      end
    elseif value == vim.NIL then
      ret = nil
    elseif value ~= nil then
      ret = value
    end
  end
  return ret
end

--- run fn and report errors via notify
function M.try(fn, opts)
  opts = type(opts) == "string" and { msg = opts } or opts or {}
  local ok, result = xpcall(fn, function(err)
    local msg = (opts.msg and (opts.msg .. "\n\n") or "") .. tostring(err)
    if opts.on_error then
      opts.on_error(msg)
    else
      vim.schedule(function()
        M.error(msg, { title = opts.title })
      end)
    end
    return msg
  end)
  return ok and result or nil
end

function M.notify(msg, opts)
  if vim.in_fast_event() then
    return vim.schedule(function()
      M.notify(msg, opts)
    end)
  end
  opts = opts or {}
  if type(msg) == "table" then
    msg = table.concat(
      vim.tbl_filter(function(line)
        return line or false
      end, msg),
      "\n"
    )
  end
  local n = opts.once and vim.notify_once or vim.notify
  n(msg, opts.level or vim.log.levels.INFO, {
    ft = opts.lang or "markdown",
    title = opts.title,
  })
end

function M.error(msg, opts)
  opts = opts or {}
  opts.level = vim.log.levels.ERROR
  M.notify(msg, opts)
end

function M.info(msg, opts)
  opts = opts or {}
  opts.level = vim.log.levels.INFO
  M.notify(msg, opts)
end

function M.warn(msg, opts)
  opts = opts or {}
  opts.level = vim.log.levels.WARN
  M.notify(msg, opts)
end

---@generic T
function M.dedup(list)
  local ret = {}
  local seen = {}
  for _, v in ipairs(list) do
    if not seen[v] then
      table.insert(ret, v)
      seen[v] = true
    end
  end
  return ret
end

M.CREATE_UNDO = vim.api.nvim_replace_termcodes("<c-G>u", true, true, true)
function M.create_undo()
  if vim.api.nvim_get_mode().mode == "i" then
    vim.api.nvim_feedkeys(M.CREATE_UNDO, "n", false)
  end
end

local _defaults = {}

--- Only set an option to a default value when it hasn't been changed locally.
function M.set_default(option, value)
  local l = vim.api.nvim_get_option_value(option, { scope = "local" })
  local g = M._options[option] or vim.api.nvim_get_option_value(option, { scope = "global" })

  _defaults[option .. "=" .. tostring(value)] = true
  local key = option .. "=" .. tostring(l)
  if l ~= g and not _defaults[key] then
    return false
  end

  vim.api.nvim_set_option_value(option, value, { scope = "local" })
  return true
end

function M.is_loaded(name)
  local Config = require("lazy.core.config")
  return Config.plugins[name] and Config.plugins[name]._.loaded
end

function M.on_load(name, fn)
  if M.is_loaded(name) then
    fn(name)
  else
    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyLoad",
      callback = function(event)
        if event.data == name then
          fn(name)
          return true
        end
      end,
    })
  end
end

function M.on_very_lazy(fn)
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    callback = fn,
  })
end

function M.get_plugin(name)
  return require("lazy.core.config").spec.plugins[name]
end

function M.has(plugin)
  return M.get_plugin(plugin) ~= nil
end

function M.opts(name)
  local plugin = M.get_plugin(name)
  if not plugin then
    return {}
  end
  local Plugin = require("lazy.core.plugin")
  return Plugin.values(plugin, "opts", false)
end

return M
