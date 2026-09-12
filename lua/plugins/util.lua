-- Terminal Mappings
local function term_nav(dir)
  ---@param self snacks.terminal
  return function(self)
    return self:is_floating() and "<c-" .. dir .. ">" or vim.schedule(function()
      vim.cmd.wincmd(dir)
    end)
  end
end

---@type string
local xdg_config = vim.env.XDG_CONFIG_HOME or vim.env.HOME .. "/.config"

---@param path string
local function have(path)
  return vim.uv.fs_stat(xdg_config .. "/" .. path) ~= nil
end

return {
-- Snacks utils
  {
    "snacks.nvim",
    opts = {
      bigfile = { enabled = true },
      -- 性能剖析：<leader>dpp 开始/停止；停止时用 picker 展示调用链
      profiler = { enabled = true },
      quickfile = { enabled = true },
      terminal = {
        win = {
          -- 以屏幕中央的浮动窗口打开（与 snacks scratch 同风格；原来默认是底部横条）
          position = "float",
          width = 0.9,
          height = 0.9,
          border = "rounded",
          keys = {
            nav_h = { "<C-h>", term_nav("h"), desc = "Go to Left Window", expr = true, mode = "t" },
            nav_j = { "<C-j>", term_nav("j"), desc = "Go to Lower Window", expr = true, mode = "t" },
            nav_k = { "<C-k>", term_nav("k"), desc = "Go to Upper Window", expr = true, mode = "t" },
            nav_l = { "<C-l>", term_nav("l"), desc = "Go to Right Window", expr = true, mode = "t" },
            hide_slash = { "<C-/>", "hide", desc = "Hide Terminal", mode = "t" },
            hide_underscore = { "<c-_>", "hide", desc = "which_key_ignore", mode = "t" },
          },
        },
      },
    },
    -- stylua: ignore
    keys = {
      { "<leader>.",  function() Snacks.scratch() end, desc = "Toggle Scratch Buffer" },
      { "<leader>S",  function() Snacks.scratch.select() end, desc = "Select Scratch Buffer" },
      { "<leader>dps", function() Snacks.profiler.scratch() end, desc = "Profiler Scratch Buffer" },
    },
  },

  -- 会话：手动保存 + 选择性打开。
  -- 关掉了两个默认行为：退出时自动保存、下次进同一目录直接恢复上一个。
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    -- stylua: ignore
    keys = {
      {
        "<leader>qs",
        function()
          local dir = require("persistence.config").options.dir
          vim.ui.input({ prompt = "保存会话为（留空 = 默认槽位，会覆盖）: " }, function(name)
            if name == nil then
              return
            end
            if name == "" then
              require("persistence").save()
              vim.notify("已保存到默认槽位（按目录，覆盖）", vim.log.levels.INFO)
              return
            end
            vim.fn.mkdir(dir, "p")
            local file = dir .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t") .. "@" .. name .. ".vim"
            vim.cmd("mks! " .. vim.fn.fnameescape(file))
            vim.notify("会话已保存: " .. vim.fn.fnamemodify(file, ":t"), vim.log.levels.INFO)
          end)
        end,
        desc = "Save Session（可命名）",
      },
      {
        "<leader>qS",
        function()
          local dir = require("persistence.config").options.dir
          local files = vim.fn.glob(dir .. "*.vim", false, true)
          if #files == 0 then
            vim.notify("还没有保存过的会话（先 <leader>qs）", vim.log.levels.WARN)
            return
          end
          table.sort(files, function(a, b)
            return vim.fn.getftime(a) > vim.fn.getftime(b)
          end)
          vim.ui.select(files, {
            prompt = "打开哪个会话",
            format_item = function(f)
              return ("%s   (%s)"):format(
                vim.fn.fnamemodify(f, ":t:r"),
                os.date("%m-%d %H:%M", vim.fn.getftime(f))
              )
            end,
          }, function(choice)
            if not choice then
              return
            end
            vim.cmd("silent! source " .. vim.fn.fnameescape(choice))
            vim.notify("已打开: " .. vim.fn.fnamemodify(choice, ":t:r"), vim.log.levels.INFO)
          end)
        end,
        desc = "Open Session（选择）",
      },
    },
    config = function(_, opts)
      require("persistence").setup(opts)
      require("persistence").stop() -- 撤销 VimLeavePre 自动保存
    end,
  },

  -- library used by other plugins
  { "nvim-lua/plenary.nvim", lazy = true },

{
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {},
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "shellcheck" } },
  },
  -- add some stuff to treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      local function add(lang)
        if type(opts.ensure_installed) == "table" then
          table.insert(opts.ensure_installed, lang)
        end
      end

      vim.filetype.add({
        extension = { rasi = "rasi", rofi = "rasi", wofi = "rasi" },
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
      vim.treesitter.language.register("bash", "kitty")

      add("git_config")

      if have("hypr") then
        add("hyprlang")
      end

      if have("fish") then
        add("fish")
      end

      if have("rofi") or have("wofi") then
        add("rasi")
      end
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "bash-language-server" } },
  },

  -- direnv：目录切换/启动时自动加载 .envrc 环境（让 LSP/终端继承）
  {
    "NotAShelf/direnv.nvim",
    lazy = false,
    opts = {
      autoload_direnv = true, -- 启动/目录切换时自动加载 .envrc
      auto_restart_lsp = true, -- 环境加载后重启 LSP（解决 venv 竞态）
    },
  },
}