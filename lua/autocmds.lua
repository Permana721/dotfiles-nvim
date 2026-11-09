require "nvchad.autocmds"
require("workspace_manager").setup()
pcall(require, "vscode_header")

_G.close_diagnostic_window = function(minwid, clicks, button, modifiers)
  if button and button ~= "l" then
    return
  end
  local function do_close()
    pcall(vim.cmd, "cclose")
    pcall(vim.cmd, "lclose")
    if type(minwid) == "number" and minwid > 0 and vim.api.nvim_win_is_valid(minwid) then
      local b = vim.api.nvim_win_get_buf(minwid)
      if vim.bo[b].filetype == "qf" or vim.bo[b].buftype == "quickfix" then
        pcall(vim.api.nvim_win_close, minwid, true)
      end
    end
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_is_valid(w) then
        local b = vim.api.nvim_win_get_buf(w)
        if vim.bo[b].filetype == "qf" or vim.bo[b].buftype == "quickfix" then
          pcall(vim.api.nvim_win_close, w, true)
        end
      end
    end
  end

  if vim.in_fast_event() then
    vim.schedule(do_close)
  else
    do_close()
  end
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function(args)
    local win = vim.fn.bufwinid(args.buf)
    local winbar_str = "%#TabLine#  Problems & Diagnostics %=%@v:lua.close_diagnostic_window@ %#TabLine#  Close %X "
    if win and win > 0 and vim.api.nvim_win_is_valid(win) then
      vim.wo[win].winbar = winbar_str
    else
      vim.wo.winbar = winbar_str
    end

    vim.keymap.set("n", "q", function()
      _G.close_diagnostic_window()
    end, { buffer = args.buf, silent = true, desc = "Close problems & diagnostics window" })

    vim.keymap.set("n", "<Esc>", function()
      _G.close_diagnostic_window()
    end, { buffer = args.buf, silent = true, desc = "Close problems & diagnostics window" })
  end,
})

local sql_comment_group = vim.api.nvim_create_augroup("SqlCommentString", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = sql_comment_group,
  pattern = { "sql", "pgsql", "mysql" },
  callback = function()
    vim.bo.commentstring = "-- %s"
  end,
})
