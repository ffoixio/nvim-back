-- Tcl，以及"其实是 Tcl 方言"的 EDA 约束文件：
--   .xdc  Xilinx 约束        .nxdc  NJU XDC（nvboard 用的，只是换了个后缀）
--   .sdc  Synopsys 约束      .upf   电源意图
-- 后缀 → 文件类型 xdc 的映射写在 config/autocmds.lua（跟 .v/.sv 那批放一起，启动最早加载）。
require("config.modules").register_lang("tcl", { name = "tcl / xdc", ts = { "tcl" }, lint = { "tclint" } })
return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- parser 注册在 config/autocmds.lua（启动即生效）
    opts = { ensure_installed = { "tcl" } },
  },

  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "tclint" } },
  },

  -- lint：tclint（nvim-lint 自带定义）。xdc 里常出现厂商/板卡专用命令，
  -- 想让它别报未知命令就在工程里放 .tclint.toml 配 allowed-commands。
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      for _, ft in ipairs({ "tcl", "xdc" }) do
        opts.linters_by_ft[ft] = vim.list_extend(opts.linters_by_ft[ft] or {}, { "tclint" })
      end
    end,
  },
}
