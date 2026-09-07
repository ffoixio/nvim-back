local M = {}

---@param filter vim.lsp.get_clients.Filter
---@param spec LazyKeysSpec[]
function M.set(filter, spec)
  local Keys = require("lazy.core.handler.keys")
  for _, keys in pairs(Keys.resolve(spec)) do
    local filters = {}
    if keys.has then
      local methods = type(keys.has) == "string" and { keys.has } or keys.has
      for _, method in ipairs(methods) do
        method = method:find("/") and method or ("textDocument/" .. method)
        filters[#filters + 1] = vim.tbl_extend("force", vim.deepcopy(filter), { method = method })
      end
    else
      filters[#filters + 1] = filter
    end

    for _, f in ipairs(filters) do
      local opts = Keys.opts(keys)
      opts.lsp = f
      opts.enabled = keys.enabled
      Snacks.keymap.set(keys.mode or "n", keys.lhs, keys.rhs, opts)
    end
  end
end

return M
