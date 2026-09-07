-- 自动命令（随 config.lazy 最早加载，无插件依赖）

-- 强制 .v/.vh/.sv/.svh 文件类型（绕过内置 detect.v 的内容猜测）
vim.filetype.add({
  extension = {
    v = "verilog",
    vh = "systemverilog",
    sv = "systemverilog",
    svh = "systemverilog",
  },
})

local function augroup(name)
  return vim.api.nvim_create_augroup("config_" .. name, { clear = true })
end

-- 窗口获得焦点 / 终端退出时，检查文件是否被外部修改
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup("checktime"),
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

-- 复制(yank)时高亮被复制的区域
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    (vim.hl or vim.highlight).on_yank()
  end,
})

-- 窗口尺寸变化时重新均分分窗
vim.api.nvim_create_autocmd({ "VimResized" }, {
  group = augroup("resize_splits"),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- 打开 buffer 时回到上次光标位置
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("last_loc"),
  callback = function(event)
    local exclude = { "gitcommit" }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].config_last_loc then
      return
    end
    vim.b[buf].config_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- 某些文件类型用 <q> 关闭
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = {
    "PlenaryTestPopup",
    "checkhealth",
    "dbout",
    "gitsigns-blame",
    "grug-far",
    "help",
    "lspinfo",
    "neotest-output",
    "neotest-output-panel",
    "neotest-summary",
    "notify",
    "qf",
    "spectre_panel",
    "startuptime",
    "tsplayground",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.schedule(function()
      vim.keymap.set("n", "q", function()
        vim.cmd("close")
        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
      end, {
        buffer = event.buf,
        silent = true,
        desc = "关闭窗口",
      })
    end)
  end,
})

-- man 文件内联打开时不列入 buffer 列表
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("man_unlisted"),
  pattern = { "man" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
  end,
})

-- 文本类文件类型自动折行 + 拼写检查
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("wrap_spell"),
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- json 文件不隐藏引号（conceallevel 置 0）
vim.api.nvim_create_autocmd({ "FileType" }, {
  group = augroup("json_conceal"),
  pattern = { "json", "jsonc", "json5" },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

-- 保存时自动创建缺失的父目录
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  group = augroup("auto_create_dir"),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- 插入时保持光标距底部至少 scrolloff 行（避免光标贴底）
vim.api.nvim_create_autocmd({ "InsertEnter", "CursorMovedI" }, {
  group = augroup("insert_bottom_margin"),
  callback = function()
    local soff = vim.o.scrolloff
    if soff == 0 then
      return
    end
    local cursor = vim.fn.line(".")
    local lc = vim.fn.line("$")
    if cursor + soff > lc then
      local wh = vim.fn.winheight(0)
      local new_top = cursor - wh + soff + 1
      new_top = math.max(1, math.min(new_top, lc))
      if new_top > vim.fn.line("w0") then
        local view = vim.fn.winsaveview()
        view.topline = new_top
        vim.fn.winrestview(view)
      end
    end
  end,
})
