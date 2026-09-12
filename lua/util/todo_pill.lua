-- todo-comments 的外观定制集中在这里，免得 plugins/editor.lua 里的 spec 越堆越长：
--   1. 配色 —— 插件默认是"语义色实底 + 反色字"，太扎眼；改成灰面底（surface1）+ 语义色字
--   2. 圆角 —— 终端画不出圆角，但可以用 Nerd Font 的 powerline 圆角字符在胶囊两端各盖半个圆
--
-- 两件事都挂在插件自己的函数上，所以插件什么时候加载、什么时候重画，我们都跟着走，
-- 不需要自己写 autocmd / 定时器。

local M = {}

local CAP_LEFT = "\u{e0b6}" -- 左半圆（powerline round 的左端）
local CAP_RIGHT = "\u{e0b4}" -- 右半圆
local CAP_HL = "TodoPillCap"

--- 胶囊底色：低饱和灰面（catppuccin surface1）；非 catppuccin 配色退回浮动窗底色
local function fill()
  local pal = require("util.transparency").palette()
  return (pal and pal.surface1) or vim.api.nvim_get_hl(0, { name = "NormalFloat" }).bg
end

--- 1) 配色：插件算完默认色之后再改 TodoBg<KW>。语义色直接从它自己算好的 TodoFg<KW> 里拿，
--- 不用手工维护"关键词 → 颜色"映射。
local function patch_colors()
  local C = require("todo-comments.config")
  local orig = C.colors
  C.colors = function(...)
    orig(...)
    local bg = fill()
    for kw in pairs(C.options.keywords or {}) do
      local fg = vim.api.nvim_get_hl(0, { name = "TodoFg" .. kw }).fg
      if bg and fg then
        vim.api.nvim_set_hl(0, "TodoBg" .. kw, { bg = bg, fg = fg })
      end
    end
    if bg then
      -- 圆角字符只上颜色不铺底：它的形状要和胶囊拼在一起，底色得留给背景
      vim.api.nvim_set_hl(0, CAP_HL, { fg = bg })
    end
  end
end

--- 2) 圆角：插件每画完一批胶囊都会走 Highlight.highlight()，我们从同一个命名空间里读出每条的
--- 范围，把两端那一格留白腾出来画圆角字符，胶囊本体缩成"关键词 + 冒号"。
--- 两端不是空白（比如 TODO: 正好顶到行尾）就跳过，保持原样，绝不动正文。
local function round_caps(buf, first, last)
  local C = require("todo-comments.config")
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local marks = vim.api.nvim_buf_get_extmarks(buf, C.ns, { first, 0 }, { last + 1, 0 }, { details = true })
  for _, m in ipairs(marks) do
    local d = m[4] or {}
    local hl, end_col = tostring(d.hl_group or ""), d.end_col
    if hl:match("^TodoBg") and end_col and end_col - m[3] >= 3 then
      local line = vim.api.nvim_buf_get_lines(buf, m[2], m[2] + 1, false)[1] or ""
      if line:sub(m[3] + 1, m[3] + 1) == " " and line:sub(end_col, end_col) == " " then
        vim.api.nvim_buf_del_extmark(buf, C.ns, m[1])
        vim.api.nvim_buf_set_extmark(buf, C.ns, m[2], m[3] + 1, { end_col = end_col - 1, hl_group = hl })
        vim.api.nvim_buf_set_extmark(buf, C.ns, m[2], m[3], {
          virt_text = { { CAP_LEFT, CAP_HL } },
          virt_text_pos = "overlay",
        })
        vim.api.nvim_buf_set_extmark(buf, C.ns, m[2], end_col - 1, {
          virt_text = { { CAP_RIGHT, CAP_HL } },
          virt_text_pos = "overlay",
        })
      end
    end
  end
end

local function patch_highlight()
  local H = require("todo-comments.highlight")
  local orig = H.highlight
  H.highlight = function(buf, first, last, ...)
    orig(buf, first, last, ...)
    round_caps(buf, first, last)
  end
end

--- 装好上面两件事，然后 setup 插件；opts 就是 spec 里的那份配置。
---@param opts table
function M.setup(opts)
  patch_colors()
  patch_highlight()
  require("todo-comments").setup(opts)
end

return M
