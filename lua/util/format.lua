local U = require("util.init")

local M = setmetatable({}, {
  __call = function(m, ...)
    return m.format(...)
  end,
})

M.formatters = {}

-- 自动格式化的白名单：全局 vim.g.autoformat 留空时，只有命中的缓冲区才会在保存时自动格式化。
-- 两个表都留空（默认）= 一个都不自动格式化；<leader>uf 仍可强制全局 / 按缓冲区开关。
--   ft   —— 文件类型，例：{ "lua", "sh", "fish" }
--   dirs —— 目录前缀（支持 ~），例：{ "~/work/myproject", "~/.config/nvim" }
M.autoformat = { ft = {}, dirs = {} }

--- 缓冲区是否命中白名单；第二个返回值是命中的规则（:LazyFormatInfo 里显示用）
---@param buf integer
---@return boolean, string?
local function whitelisted(buf)
  local ft = vim.bo[buf].filetype
  if vim.tbl_contains(M.autoformat.ft, ft) then
    return true, "ft:" .. ft
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return false
  end
  local path = vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
  for _, dir in ipairs(M.autoformat.dirs) do
    local prefix = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(dir), ":p")) .. "/"
    if vim.startswith(path, prefix) then
      return true, "dir:" .. dir
    end
  end
  return false
end

function M.register(formatter)
  M.formatters[#M.formatters + 1] = formatter
  table.sort(M.formatters, function(a, b)
    return a.priority > b.priority
  end)
end

function M.formatexpr()
  if U.has("conform.nvim") then
    return require("conform").formatexpr()
  end
  return vim.lsp.formatexpr({ timeout_ms = 3000 })
end

function M.resolve(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local have_primary = false
  return vim.tbl_map(function(formatter)
    local sources = formatter.sources(buf)
    local active = #sources > 0 and (not formatter.primary or not have_primary)
    have_primary = have_primary or (active and formatter.primary) or false
    return setmetatable({
      active = active,
      resolved = sources,
    }, { __index = formatter })
  end, M.formatters)
end

function M.info(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local gaf = vim.g.autoformat
  local baf = vim.b[buf].autoformat
  local enabled, why = M.enabled(buf)
  local lines = {
    "# Status",
    ("- [%s] global **%s**"):format(
      gaf and "x" or " ",
      gaf == nil and "whitelist" or (gaf and "enabled" or "disabled")
    ),
    ("- [%s] whitelist **%s**"):format(why and "x" or " ", why or "no match"),
    ("- [%s] buffer **%s**"):format(
      enabled and "x" or " ",
      baf == nil and "inherit" or baf and "enabled" or "disabled"
    ),
  }
  local have = false
  for _, formatter in ipairs(M.resolve(buf)) do
    if #formatter.resolved > 0 then
      have = true
      lines[#lines + 1] = "\n# " .. formatter.name .. (formatter.active and " ***(active)***" or "")
      for _, line in ipairs(formatter.resolved) do
        lines[#lines + 1] = ("- [%s] **%s**"):format(formatter.active and "x" or " ", line)
      end
    end
  end
  if not have then
    lines[#lines + 1] = "\n***No formatters available for this buffer.***"
  end
  U[enabled and "info" or "warn"](table.concat(lines, "\n"), { title = "Format (" .. (enabled and "enabled" or "disabled") .. ")" })
end

-- 三级判定：缓冲区覆盖 > 全局显式值 > 白名单（白名单默认空 = 关）
function M.enabled(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  local baf = vim.b[buf].autoformat
  if baf ~= nil then
    return baf
  end
  local gaf = vim.g.autoformat
  if gaf ~= nil then
    return gaf
  end
  return (whitelisted(buf))
end

function M.toggle(buf)
  M.enable(not M.enabled(), buf)
end

function M.enable(enable, buf)
  if enable == nil then
    enable = true
  end
  if buf then
    vim.b.autoformat = enable
  else
    vim.g.autoformat = enable
    vim.b.autoformat = nil
  end
  M.info()
end

function M.format(opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  if not ((opts and opts.force) or M.enabled(buf)) then
    return
  end

  local done = false
  for _, formatter in ipairs(M.resolve(buf)) do
    if formatter.active then
      done = true
      U.try(function()
        return formatter.format(buf)
      end, { msg = "Formatter `" .. formatter.name .. "` failed" })
    end
  end

  if not done and opts and opts.force then
    U.warn("No formatter available", { title = "Format" })
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("config_format", {}),
    callback = function(event)
      M.format({ buf = event.buf })
    end,
  })

  vim.api.nvim_create_user_command("LazyFormat", function()
    M.format({ force = true })
  end, { desc = "Format selection or buffer" })

  vim.api.nvim_create_user_command("LazyFormatInfo", function()
    M.info()
  end, { desc = "Show info about the formatters for the current buffer" })
end

function M.snacks_toggle(buf)
  return Snacks.toggle({
    name = "Auto Format (" .. (buf and "Buffer" or "Global") .. ")",
    get = function()
      -- 全局值留空时显示白名单的判定结果，而不是一律显示成"开"
      return M.enabled()
    end,
    set = function(state)
      M.enable(state, buf)
    end,
  })
end

return M