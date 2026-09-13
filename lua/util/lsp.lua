local U = require("util.init")

---@class config.util.lsp
local M = {}

---@param opts? LazyFormatter| {filter?: (string|vim.lsp.get_clients.Filter)}
function M.formatter(opts)
  opts = opts or {}
  local filter = opts.filter or {}
  filter = type(filter) == "string" and { name = filter } or filter
  ---@cast filter vim.lsp.get_clients.Filter
  ---@type LazyFormatter
  local ret = {
    name = "LSP",
    primary = true,
    priority = 1,
    format = function(buf)
      M.format(U.merge({}, filter, { bufnr = buf }))
    end,
    sources = function(buf)
      local clients = vim.lsp.get_clients(U.merge({}, filter, { bufnr = buf }))
      ---@param client vim.lsp.Client
      local ret = vim.tbl_filter(function(client)
        return client:supports_method("textDocument/formatting")
          or client:supports_method("textDocument/rangeFormatting")
      end, clients)
      ---@param client vim.lsp.Client
      return vim.tbl_map(function(client)
        return client.name
      end, ret)
    end,
  }
  return U.merge(ret, opts) --[[@as LazyFormatter]]
end

---@alias lsp.Client.format {timeout_ms?: number, format_options?: table} | vim.lsp.get_clients.Filter

---@param opts? lsp.Client.format
function M.format(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {}, U.opts("nvim-lspconfig").format or {})
  local ok, conform = pcall(require, "conform")
  -- use conform for formatting with LSP when available,
  -- since it has better format diffing
  if ok then
    -- It should be `nil`, otherwise it doesn't fetch options from `formatters_by_ft`,
    -- see https://github.com/stevearc/conform.nvim/blob/5420c4b5ea0aeb99c09cfbd4fd0b70d257b44f25/lua/conform/init.lua#L417-L418
    opts.formatters = nil
    conform.format(opts)
  else
    vim.lsp.buf.format(opts)
  end
end

M.action = setmetatable({}, {
  __index = function(_, action)
    return function()
      vim.lsp.buf.code_action({
        apply = true,
        context = {
          only = { action },
          diagnostics = {},
        },
      })
    end
  end,
})

---@class LspCommand: lsp.ExecuteCommandParams
---@field open? boolean
---@field handler? lsp.Handler
---@field filter? string|vim.lsp.get_clients.Filter
---@field title? string

---@param filter? vim.lsp.get_clients.Filter
function M.code_actions(filter)
  filter = filter or {}
  local ret = {} ---@type string[]
  local clients = vim.lsp.get_clients(filter)
  for _, client in ipairs(clients) do
    -- check server cababilities first
    vim.list_extend(ret, vim.tbl_get(client, "server_capabilities", "codeActionProvider", "codeActionKinds") or {})
    -- check dynamic capabilities
    local regs = client.dynamic_capabilities:get("codeActionProvider", filter)
    for _, reg in ipairs(regs or {}) do
      vim.list_extend(ret, vim.tbl_get(reg, "registerOptions", "codeActionKinds") or {})
    end
  end
  return U.dedup(ret)
end

return M