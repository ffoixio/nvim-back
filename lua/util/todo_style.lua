-- todo-comments 的观感修正。缓冲区那边它只负责给关键词染字（见 plugins/editor.lua 的 opts），
-- 这里管 picker：插件把关键词渲染成 { 居中(kw, 6), "TodoBg"..kw } —— 一条 6 格宽的色块条，
-- 而且会被 picker 自己的命中高亮（SnacksPickerMatch → Special）把字盖成发白的颜色。
-- 改成只染字（列宽对齐不动），和缓冲区里的观感一致。

local M = {}

--- 必须在 config._setup 之后再包：插件是在 _setup 末尾才把 source 挂到 Snacks.picker.sources 上的，
--- 而 _setup 在启动早期会被 defer 到 timer 里（todo-comments/config.lua:90）。
local function patch_picker()
  local C = require("todo-comments.config")
  local orig = C._setup
  C._setup = function(...)
    orig(...)
    local src = Snacks and Snacks.picker and Snacks.picker.sources and Snacks.picker.sources.todo_comments
    if src and src.format and not src._patched then
      src._patched = true
      local format = src.format
      src.format = function(item, picker)
        local chunks = format(item, picker)
        for _, chunk in ipairs(chunks or {}) do
          if type(chunk[2]) == "string" then
            chunk[2] = chunk[2]:gsub("^TodoBg", "TodoFg")
          end
        end
        return chunks
      end
    end
  end
end

---@param opts table spec 里那份配置
function M.setup(opts)
  patch_picker()
  require("todo-comments").setup(opts)
end

return M
