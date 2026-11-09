return {
  {
    "lewis6991/gitsigns.nvim",
    opts = function(_, conf)
      conf = conf or {}
      conf.current_line_blame = true
      conf.current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 80,
        ignore_whitespace = false,
        virt_text_priority = 100,
      }
      conf.current_line_blame_formatter = "   󰊤 <author>, <author_time:%R> • <summary>"
      return conf
    end,
    config = function(_, opts)
      require("gitsigns").setup(opts)

      local gs_hls = {
        GitSignsChange = { fg = "#e5c07b" },
        GitSignsChangedelete = { fg = "#e5c07b" },
        GitSignsAdd = { fg = "#98c379" },
        GitSignsUntracked = { fg = "#98c379" },
        GitSignsDelete = { fg = "#c678dd" },
        GitSignsTopdelete = { fg = "#c678dd" },
      }
      for k, v in pairs(gs_hls) do
        vim.api.nvim_set_hl(0, k, v)
      end

      local ok, clb = pcall(require, "gitsigns.current_line_blame")
      if ok and clb then

        local _, fn = debug.getupvalue(clb.update, 5)
        if fn then
          local _, ut = debug.getupvalue(fn, 2)
          if ut then
            local _, upd = debug.getupvalue(ut, 6)
            if upd then
              for i = 1, 15 do
                local n = debug.getupvalue(upd, i)
                if n == "insert_mode" then
                  debug.setupvalue(upd, i, function()
                    return false
                  end)
                  break
                end
              end
            end
          end
        end

        local reset_fn = nil
        for i = 1, 10 do
          local n, v = debug.getupvalue(clb.refresh, i)
          if n == "reset" then
            reset_fn = v
            break
          end
        end

        local blame_ns = vim.api.nvim_create_namespace("gitsigns_blame")

        local function has_line_diagnostics(buf, lnum)
          if not vim.api.nvim_buf_is_valid(buf) then
            return false
          end
          local diags = vim.diagnostic.get(buf, { lnum = lnum - 1 })
          return diags and #diags > 0
        end

        local function clear_blame(buf)
          if buf and vim.api.nvim_buf_is_valid(buf) then
            if reset_fn then
              pcall(reset_fn, buf)
            end
            pcall(vim.api.nvim_buf_clear_namespace, buf, blame_ns, 0, -1)
          end
        end

        local orig_clb_update = clb.update
        clb.update = function(buf)
          buf = buf or vim.api.nvim_get_current_buf()
          if vim.api.nvim_buf_is_valid(buf) then
            local win = vim.api.nvim_get_current_win()
            if vim.api.nvim_win_get_buf(win) == buf then
              local lnum = vim.api.nvim_win_get_cursor(win)[1]
              if has_line_diagnostics(buf, lnum) then
                clear_blame(buf)
                return
              end
            end
          end
          return orig_clb_update(buf)
        end

        local group = vim.api.nvim_create_augroup("gitsigns.current_line_blame", { clear = true })
        local last_buf = nil
        local last_lnum = nil

        vim.api.nvim_create_autocmd({ "BufEnter", "CursorMoved", "CursorMovedI", "CursorHold", "CursorHoldI", "WinResized" }, {
          group = group,
          callback = function(args)
            local buf = args.buf
            if not vim.api.nvim_buf_is_valid(buf) then
              return
            end
            local win = vim.api.nvim_get_current_win()
            if vim.api.nvim_win_get_buf(win) ~= buf then
              return
            end
            local lnum = vim.api.nvim_win_get_cursor(win)[1]

            if has_line_diagnostics(buf, lnum) then
              clear_blame(buf)
              if reset_fn and last_buf and vim.api.nvim_buf_is_valid(last_buf) and last_buf ~= buf then
                pcall(reset_fn, last_buf)
              end
              last_buf = buf
              last_lnum = lnum
              return
            end

            if buf ~= last_buf or lnum ~= last_lnum then
              if reset_fn and last_buf and vim.api.nvim_buf_is_valid(last_buf) then
                pcall(reset_fn, last_buf)
              end
              last_buf = buf
              last_lnum = lnum
            end
            clb.update(buf)
          end,
        })

        vim.api.nvim_create_autocmd("InsertEnter", {
          group = group,
          callback = function(args)
            local buf = args.buf
            if not vim.api.nvim_buf_is_valid(buf) then
              return
            end
            local win = vim.api.nvim_get_current_win()
            if vim.api.nvim_win_get_buf(win) ~= buf then
              return
            end
            local lnum = vim.api.nvim_win_get_cursor(win)[1]
            if has_line_diagnostics(buf, lnum) then
              clear_blame(buf)
              return
            end
            clb.update(args.buf)
          end,
        })

        vim.api.nvim_create_autocmd("DiagnosticChanged", {
          group = group,
          callback = function(args)
            local buf = args.buf
            if not vim.api.nvim_buf_is_valid(buf) then
              return
            end
            local win = vim.api.nvim_get_current_win()
            if vim.api.nvim_win_get_buf(win) ~= buf then
              return
            end
            local lnum = vim.api.nvim_win_get_cursor(win)[1]
            if has_line_diagnostics(buf, lnum) then
              clear_blame(buf)
            else
              clb.update(buf)
            end
          end,
        })

        vim.api.nvim_create_autocmd("BufLeave", {
          group = group,
          callback = function(args)
            clear_blame(args.buf)
            last_buf = nil
            last_lnum = nil
          end,
        })

        vim.api.nvim_create_autocmd("OptionSet", {
          group = group,
          pattern = { "fileformat", "bomb", "eol" },
          callback = function(args)
            clear_blame(args.buf)
          end,
        })
      end
    end,
  },
}
