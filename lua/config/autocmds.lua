-- 自动命令（随 config.lazy 最早加载，无插件依赖）

-- 文件类型识别统一放这里（原先还有一份散在 plugins/util.lua 里）
-- 1) .v/.vh/.sv/.svh：绕过内置 detect.v 的内容猜测
-- 2) EDA 约束：xdc/nxdc/sdc/upf 都是 Tcl 方言，统一当 xdc
-- 3) 若干工具配置文件的别名（hypr/kitty/waybar/mako/rofi/rasi/vifmrc/.env.*）
vim.filetype.add({
  extension = {
    v = "verilog",
    vh = "systemverilog",
    sv = "systemverilog",
    svh = "systemverilog",
    -- EDA 约束文件其实都是 Tcl 方言，统一当 xdc（高亮/lint 见 plugins/lang/tcl.lua）：
    -- xdc = Xilinx 约束，nxdc = NJU XDC（nvboard 用的，只是换了后缀），sdc = Synopsys，upf = 电源意图
    xdc = "xdc",
    nxdc = "xdc",
    sdc = "xdc",
    upf = "xdc",
    -- 工具配置文件
    rasi = "rasi",
    rofi = "rasi",
    wofi = "rasi",
  },
  filename = {
    ["vifmrc"] = "vim",
  },
  pattern = {
    [".*/waybar/config"] = "jsonc",
    [".*/mako/config"] = "dosini",
    [".*/kitty/.+%.conf"] = "kitty",
    [".*/hypr/.+%.conf"] = "hyprlang",
    ["%.env%.[%w_.-]+"] = "sh",
  },
})

-- 文件类型 → treesitter parser 的注册。放这里而不是插件 init 里：nvim-treesitter 是 lazy 加载的，
-- 写在它的 init 里要等插件真正加载（BufReadPost）才生效，不如启动时就注册稳妥（register 只是记表）。
vim.treesitter.language.register("systemverilog", "verilog") -- .v 也用 systemverilog 语法
vim.treesitter.language.register("tcl", "xdc") -- xdc/nxdc/sdc/upf 用 tcl 语法
vim.treesitter.language.register("bash", "kitty") -- kitty 配置文件当 shell 高亮

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

-- 文件尾部居中：只在本 buffer 进过 insert 之后才生效。
--   * 纯浏览（没进过 insert）-> 保持 Vim 默认，光标直接到底部
--   * 进过 insert 再 Esc      -> 保留居中（含之后在普通模式里移动）
-- 关键点：进入尾部区域时先把「本窗口」的 scrolloff 关掉。
-- 否则 scrolloff=999 会让 Vim 每次移动都把 topline 钳回 (末行-窗高+1)，
-- 表现成「先掉到底部、再被 zz 拉回」的双跳（反复横跳）。
-- （改 topline 本身也不行：winrestview 会被钳到同一个上限；只有 zz 能滚出尾部空白。）
vim.api.nvim_create_autocmd({ "InsertEnter", "CursorMovedI", "CursorMoved" }, {
  group = augroup("center_at_eof"),
  callback = function(args)
    -- 只处理普通文件缓冲区。picker 的输入框是 buftype=prompt、结果列表是 nofile，
    -- 在这些 buffer 里执行 :normal 会打断输入机制。
    if vim.bo.buftype ~= "" or not vim.bo.modifiable then
      return
    end
    if args.event == "InsertEnter" then
      vim.b.center_at_eof = true
    end
    if args.event == "CursorMoved" and not vim.b.center_at_eof then
      return
    end
    local wh = vim.fn.winheight(0)
    if vim.fn.line("$") <= wh then
      return -- 文件比窗口还短，本来就无法居中（也让 1 行的 prompt buffer 直接出局）
    end
    local half = math.max(1, math.floor(wh / 2))
    if vim.fn.line(".") + half > vim.fn.line("$") then
      if vim.wo.scrolloff ~= 0 then
        vim.wo.scrolloff = 0 -- 本窗口临时关掉，Vim 不再干预 topline
      end
      -- 关键：绝不在插入模式里跑 :normal —— 那会在插入中途切回普通模式、打断输入。
      -- 插入时只负责关掉 scrolloff，真正的 zz 留到 Esc 后的 CursorMoved。
      if vim.fn.mode() == "n" then
        vim.cmd("normal! zz")
      end
    elseif vim.wo.scrolloff == 0 then
      vim.cmd("setlocal scrolloff<") -- 离开尾部区域，恢复全局 scrolloff
    end
  end,
})
