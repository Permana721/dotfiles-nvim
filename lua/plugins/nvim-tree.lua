return {
  {
    "nvim-tree/nvim-tree.lua",
    lazy = false,
    version = "*",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local conf = require("nvchad.configs.nvimtree")
      conf.renderer = vim.tbl_deep_extend("force", conf.renderer or {}, {
        group_empty = true,
        highlight_git = "name",
        icons = {
          git_placement = "after",
          glyphs = {
            git = {
              unstaged = "M",
              staged = "S",
              unmerged = "",
              renamed = "➜",
              untracked = "U",
              deleted = "",
              ignored = "◌",
            },
          },
        },
      })
      conf.diagnostics = {
        enable = true,
        show_on_dirs = true,
      }
      require("nvim-tree").setup(conf)

      local tree_hls = {
        NvimTreeGitDirty = { fg = "#e5c07b" },
        NvimTreeGitDirtyIcon = { fg = "#e5c07b" },
        NvimTreeFileDirty = { fg = "#e5c07b" },
        NvimTreeGitFileDirtyHL = { fg = "#e5c07b" },
        NvimTreeGitFolderDirtyHL = { fg = "#e5c07b" },
        NvimTreeGitNew = { fg = "#98c379" },
        NvimTreeGitNewIcon = { fg = "#98c379" },
        NvimTreeFileNew = { fg = "#98c379" },
        NvimTreeGitFileNewHL = { fg = "#98c379" },
        NvimTreeGitFolderNewHL = { fg = "#98c379" },
        NvimTreeGitStaged = { fg = "#56b6c2" },
        NvimTreeGitStagedIcon = { fg = "#56b6c2" },
        NvimTreeFileStaged = { fg = "#56b6c2" },
        NvimTreeGitFileStagedHL = { fg = "#56b6c2" },
        NvimTreeGitFolderStagedHL = { fg = "#56b6c2" },
        NvimTreeGitDeleted = { fg = "#c678dd" },
        NvimTreeGitDeletedIcon = { fg = "#c678dd" },
        NvimTreeFileDeleted = { fg = "#c678dd" },
        NvimTreeGitFileDeletedHL = { fg = "#c678dd" },
        NvimTreeGitFolderDeletedHL = { fg = "#c678dd" },
        NvimTreeGitRenamed = { fg = "#61afef" },
        NvimTreeGitRenamedIcon = { fg = "#61afef" },
        NvimTreeGitIgnored = { fg = "#5c6370" },
        NvimTreeGitIgnoredIcon = { fg = "#5c6370" },
        NvimTreeRootFolder = { fg = "#61afef", bold = true },
        DiagnosticError = { fg = "#e06c75" },
        NvimTreeLspDiagnosticsError = { fg = "#e06c75" },
        NvimTreeDiagnosticErrorFileHL = { fg = "#e06c75" },
        NvimTreeDiagnosticErrorFolderHL = { fg = "#e06c75" },
        NvimTreeDiagnosticErrorIcon = { fg = "#e06c75" },
      }
      for k, v in pairs(tree_hls) do
        vim.api.nvim_set_hl(0, k, v)
      end

      local function auto_open_nvim_tree(data)

        local buf = (data and data.buf) or vim.api.nvim_get_current_buf()
        local ft = (buf and vim.api.nvim_buf_is_valid(buf)) and vim.bo[buf].filetype or ""
        if ft == "gitcommit" or ft == "gitrebase" or ft == "man" or vim.opt.diff:get() then
          return
        end

        local ok, api = pcall(require, "nvim-tree.api")
        if not ok then
          return
        end

        vim.schedule(function()

          if not api.tree.is_visible() then
            api.tree.open({ focus = false })
          end

          local cur_win = vim.api.nvim_get_current_win()
          local cur_buf = vim.api.nvim_win_get_buf(cur_win)
          if vim.bo[cur_buf].filetype == "NvimTree" then
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local b = vim.api.nvim_win_get_buf(win)
              if vim.bo[b].filetype ~= "NvimTree" and vim.bo[b].buftype == "" then
                vim.api.nvim_set_current_win(win)
                break
              end
            end
          end
        end)
      end

      if vim.v.vim_did_enter == 1 then
        auto_open_nvim_tree()
      else
        vim.api.nvim_create_autocmd("VimEnter", {
          callback = auto_open_nvim_tree,
        })
      end

      vim.api.nvim_create_autocmd({ "User", "VimLeavePre" }, {
        pattern = { "PersistenceSavePre", "*" },
        callback = function(args)
          if args.event == "User" and args.match ~= "PersistenceSavePre" then
            return
          end
          local ok, api = pcall(require, "nvim-tree.api")
          if ok and api.tree.is_visible() then
            api.tree.close()
          end
        end,
      })

      local function on_session_loaded()
        local ok, api = pcall(require, "nvim-tree.api")
        if not ok then
          return
        end

        local ok_view, view = pcall(require, "nvim-tree.view")
        local real_tree_win = ok_view and view.get_winnr()
        local real_tree_buf = ok_view and view.get_bufnr()

        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if win ~= real_tree_win and vim.api.nvim_win_is_valid(win) then
            local b = vim.api.nvim_win_get_buf(win)
            local name = vim.api.nvim_buf_get_name(b)
            local ft = vim.bo[b].filetype
            if ft == "NvimTree" or name:match("NvimTree_") then
              local wins = vim.api.nvim_tabpage_list_wins(0)
              if #wins > 1 then
                pcall(vim.api.nvim_win_close, win, true)
              end
              pcall(vim.api.nvim_buf_delete, b, { force = true })
            end
          end
        end

        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if b ~= real_tree_buf and vim.api.nvim_buf_is_valid(b) then
            local name = vim.api.nvim_buf_get_name(b)
            local ft = vim.bo[b].filetype
            if (ft == "NvimTree" or name:match("NvimTree_")) and vim.bo[b].buftype ~= "nofile" then
              pcall(vim.api.nvim_buf_delete, b, { force = true })
            end
          end
        end

        vim.schedule(function()
          if not api.tree.is_visible() then
            api.tree.open({ focus = false })
          end

          local cur_win = vim.api.nvim_get_current_win()
          local cur_buf = vim.api.nvim_win_get_buf(cur_win)
          if vim.bo[cur_buf].filetype == "NvimTree" then
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local b = vim.api.nvim_win_get_buf(win)
              if vim.bo[b].filetype ~= "NvimTree" and vim.bo[b].buftype == "" then
                vim.api.nvim_set_current_win(win)
                break
              end
            end
          end
        end)
      end

      vim.api.nvim_create_autocmd({ "SessionLoadPost", "User" }, {
        pattern = { "*", "PersistenceLoadPost" },
        callback = function(args)
          if args.event == "User" and args.match ~= "PersistenceLoadPost" then
            return
          end
          on_session_loaded()
        end,
      })
    end,
  },
}
