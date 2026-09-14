
-- snacks 动画开关
vim.g.snacks_animate = true

-- animations

-- Animates cursor movement with a smear effect.

return {
-- This is what powers LazyVim's fancy-looking
  -- tabs, which include filetype icons and close buttons.
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
      { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non-Pinned Buffers" },
      { "<leader>br", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
      { "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "[B", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer prev" },
      { "]B", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer next" },
      { "<leader>bj", "<cmd>BufferLinePick<cr>", desc = "Pick Buffer" },
    },
    opts = {
      options = {
        -- stylua: ignore
        close_command = function(n) Snacks.bufdelete(n) end,
        -- stylua: ignore
        right_mouse_command = function(n) Snacks.bufdelete(n) end,
        diagnostics = "nvim_lsp",
        always_show_bufferline = false,
        diagnostics_indicator = function(_, _, diag)
          local icons = require("config.icons").icons.diagnostics
          local ret = (diag.error and icons.Error .. diag.error .. " " or "")
            .. (diag.warning and icons.Warn .. diag.warning or "")
          return vim.trim(ret)
        end,
        offsets = {
          {
            filetype = "neo-tree",
            text = "Neo-tree",
            highlight = "Directory",
            text_align = "left",
          },
          {
            filetype = "snacks_layout_box",
          },
        },
        ---@param opts bufferline.IconFetcherOpts
        get_element_icon = function(opts)
          return require("config.icons").icons.ft[opts.filetype]
        end,
      },
    },
    config = function(_, opts)
      require("bufferline").setup(opts)
      -- Fix bufferline when restoring a session
      vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
        callback = function()
          vim.schedule(function()
            pcall(nvim_bufferline)
          end)
        end,
      })
    end,
  },

  -- Highly experimental plugin that completely replaces the UI for messages, cmdline and the popupmenu.
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      routes = {
        {
          filter = {
            event = "msg_show",
            any = {
              { find = "%d+L, %d+B" },
              { find = "; after #%d+" },
              { find = "; before #%d+" },
            },
          },
          view = "mini",
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
      },
    },
    -- stylua: ignore
    keys = {
      { "<leader>sn", "", desc = "+noice"},
      { "<S-Enter>", function() require("noice").redirect(vim.fn.getcmdline()) end, mode = "c", desc = "Redirect Cmdline" },
      { "<leader>snl", function() require("noice").cmd("last") end, desc = "Noice Last Message" },
      { "<leader>snh", function() require("noice").cmd("history") end, desc = "Noice History" },
      { "<leader>sna", function() require("noice").cmd("all") end, desc = "Noice All" },
      { "<leader>snd", function() require("noice").cmd("dismiss") end, desc = "Dismiss All" },
      { "<leader>snt", function() require("noice").cmd("pick") end, desc = "Noice Picker (Telescope/FzfLua)" },
      { "<c-f>", function() if not require("noice.lsp").scroll(4) then return "<c-f>" end end, silent = true, expr = true, desc = "Scroll Forward", mode = {"i", "n", "s"} },
      { "<c-b>", function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end, silent = true, expr = true, desc = "Scroll Backward", mode = {"i", "n", "s"}},
    },
    config = function(_, opts)
      -- HACK: noice shows messages from before it was enabled,
      -- but this is not ideal when Lazy is installing plugins,
      -- so clear the messages in this case.
      if vim.o.filetype == "lazy" then
        vim.cmd([[messages clear]])
      end
      require("noice").setup(opts)
    end,
  },

  -- icons
  {
    "nvim-mini/mini.icons",
    lazy = true,
    opts = {
      file = {
        [".keep"] = { glyph = "󰊢", hl = "MiniIconsGrey" },
        ["devcontainer.json"] = { glyph = "", hl = "MiniIconsAzure" },
      },
      filetype = {
        dotenv = { glyph = "", hl = "MiniIconsYellow" },
      },
    },
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- ui components
  { "MunifTanjim/nui.nvim", lazy = true },

  {
    "snacks.nvim",
    opts = {
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = false }, -- we set this in options.lua
      toggle = { map = vim.keymap.set },
      words = { enabled = true },
    },
    -- stylua: ignore
    keys = {
      { "<leader>n", function()
        if Snacks.config.picker and Snacks.config.picker.enabled then
          Snacks.picker.notifications()
        else
          Snacks.notifier.show_history()
        end
      end, desc = "Notification History" },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications" },
    },
  },

  {
    "snacks.nvim",
    opts = function(_, opts)
      -- 只渲染按键列表：不含 header 区块（否则 snacks 默认的 ASCII 大字会露出来）
      -- stylua: ignore
      ---@type snacks.dashboard.Item[]
      local keys = {
        { key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
        { key = "n", desc = "New File", action = ":ene | startinsert" },
        { key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
        { key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
        { key = "l", desc = "Lazy", action = ":Lazy", hidden = true },
        { key = "q", desc = "Quit", action = ":qa", hidden = true },
        -- 全局的 s / S 被 flash 占着（Flash / Flash Treesitter），在启动页按到会跳出去乱闪；
        -- 用隐藏的空动作把它们吃掉。要再堵别的键，照抄一行改 key 即可。
        { key = "s", action = function() end, hidden = true },
        { key = "S", action = function() end, hidden = true },
      }

      -- 每行宽度 = 最长描述 + 描述与键位之间的空隙 + 1 个键位列。
      -- snacks 默认 width = 60：描述左对齐、键位右对齐，中间能空出 50 格。以前上方压着
      -- 55 宽的 ASCII header 还协调，header 去掉后就成了长条，所以收紧到贴着描述。
      local gap = 15
      local longest = 0
      for _, item in ipairs(keys) do
        if not item.hidden then
          longest = math.max(longest, vim.fn.strdisplaywidth(item.desc))
        end
      end

      opts.dashboard = {
        width = longest + gap + 1,
        sections = { { section = "keys", gap = 1, padding = 1 } },
        preset = {
          pick = function(cmd, pick_opts)
            local commands = { files = "files", live_grep = "grep", oldfiles = "recent" }
            return Snacks.picker.pick(commands[cmd] or cmd, pick_opts)
          end,
          -- 启动页不放 ASCII 大字（极简）。想恢复：删掉下面两行注释标记即可。
          --[==[
          header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
   ]],
          --]==]
          keys = keys,
        },
      }
      return opts
    end,
  },

-- disable snacks scroll when animate is enabled
  {
    "snacks.nvim",
    opts = {
      scroll = { enabled = false },
    },
  },

  -- Animates many common Neovim actions, like scrolling,
  -- moving the cursor, and resizing windows.
  {
    "nvim-mini/mini.animate",
    event = "VeryLazy",
    cond = vim.g.neovide == nil,
    opts = function(_, opts)
      -- don't use animate when scrolling with the mouse
      local mouse_scrolled = false
      for _, scroll in ipairs({ "Up", "Down" }) do
        local key = "<ScrollWheel" .. scroll .. ">"
        vim.keymap.set({ "", "i" }, key, function()
          mouse_scrolled = true
          return key
        end, { expr = true })
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "grug-far",
        callback = function()
          vim.b.minianimate_disable = true
        end,
      })

      -- <leader>ua = mini.animate 的开关；snacks 自己的动画开关在 keymaps.lua 里，占 <leader>uA。
      -- （原先这里要 vim.schedule 抢注册顺序，是因为 keymaps.lua 也映射了 ua；那边已让开，不再需要）
      Snacks.toggle({
        name = "Mini Animate",
        get = function()
          return not vim.g.minianimate_disable
        end,
        set = function(state)
          vim.g.minianimate_disable = not state
        end,
      }):map("<leader>ua")

      local animate = require("mini.animate")
      return vim.tbl_deep_extend("force", opts, {
        resize = {
          timing = animate.gen_timing.linear({ duration = 50, unit = "total" }),
        },
        scroll = {
          -- unit = "step"：每步固定时长，总时长随实际滚动量变化。原来 unit = "total" 是
          -- 不管滚 2 行还是 30 行都演满 150ms，所以贴边只能滚一点时看着很怪。
          timing = animate.gen_timing.linear({ duration = 12, unit = "step" }),
          subscroll = animate.gen_subscroll.equal({
            -- 默认最多 60 步，也就是 150ms 内最多 60 次重绘；半屏/全屏滚动时终端跟不上就掉帧。
            -- 压到 20 步（每次重绘约 7.5ms 余量）：动画仍然在，但不再一卡一卡。
            max_output_steps = 20,
            predicate = function(total_scroll)
              if mouse_scrolled then
                mouse_scrolled = false
                return false
              end
              return total_scroll > 1
            end,
          }),
        },
      })
    end,
  },

  -- smear-cursor 的拖尾动画已关闭（观感难受）。想恢复：删掉下面两行注释标记。
  --[==[
  {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    cond = vim.g.neovide == nil,
    opts = {
      hide_target_hack = true,
      cursor_color = "none",
    },
    specs = {
      -- disable mini.animate cursor
      {
        "nvim-mini/mini.animate",
        optional = true,
        opts = {
          cursor = { enable = false },
        },
      },
    },
  
    -- 顶部粘住当前函数/类的签名（读长函数时始终知道自己在哪）
  },
  --]==]

  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "LazyFile",
    opts = function()
      local tsc = require("treesitter-context")
      Snacks.toggle({
        name = "Treesitter Context",
        get = tsc.enabled,
        set = function(state)
          if state then
            tsc.enable()
          else
            tsc.disable()
          end
        end,
      }):map("<leader>ut")
      return { mode = "cursor", max_lines = 3 }
    end,
  },

  -- nvim-navic：把当前代码层级（函数/类面包屑）提供给状态栏显示
  {
    "SmiteshP/nvim-navic",
    lazy = true,
    init = function()
      vim.g.navic_silence = true
    end,
    opts = function()
      Snacks.util.lsp.on({ method = "textDocument/documentSymbol" }, function(buffer, client)
        require("nvim-navic").attach(client, buffer)
      end)
      return {
        separator = " ",
        highlight = true,
        -- safe_output：符号名里的字面 % 会被状态栏当成语法（%#组# / %l 之类），转义掉
        safe_output = true,
        depth_limit = 5,
        icons = require("config.icons").icons.kinds,
        lazy_update_context = true,
      }
    end,
  },
}
