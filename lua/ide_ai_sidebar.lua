local M = {}

_G._ide_ai_state = _G._ide_ai_state or {
  win = nil,
  buf = nil,
  job_id = nil,
}

local S = _G._ide_ai_state

local function setup_highlights()
  local tree_hl = vim.api.nvim_get_hl(0, { name = "NvimTreeNormal" })
  local bg = tree_hl.bg and string.format("#%06x", tree_hl.bg) or "#1e222a"

  local hl = {
    VSCodeAIHeaderTitle = { fg = "#61afef", bg = bg, bold = true },
    VSCodeAIHeaderFill = { fg = "#abb2bf", bg = bg },
    VSCodeAIHeaderBtn = { fg = "#abb2bf", bg = bg, bold = true },
    VSCodeAIHeaderClose = { fg = "#e06c75", bg = bg, bold = true },
  }

  for name, opts in pairs(hl) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

setup_highlights()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = setup_highlights,
})

local function setup_protection()
  if _G._ide_ai_protection_active then
    return
  end
  _G._ide_ai_protection_active = true

  local orig_tabpage_list_wins = vim.api.nvim_tabpage_list_wins
  vim.api.nvim_tabpage_list_wins = function(tabpage)
    local wins = orig_tabpage_list_wins(tabpage)
    if S.win and vim.api.nvim_win_is_valid(S.win) then
      for depth = 2, 6 do
        local info = debug.getinfo(depth, "S")
        if info and info.source and info.source:match("ide_term%.lua") then
          local filtered = {}
          for _, w in ipairs(wins) do
            if w ~= S.win then
              table.insert(filtered, w)
            end
          end
          return filtered
        end
      end
    end
    return wins
  end

  local orig_win_close = vim.api.nvim_win_close
  vim.api.nvim_win_close = function(win, force)
    if S.win and win == S.win then
      for depth = 2, 6 do
        local info = debug.getinfo(depth, "S")
        if info and info.source and info.source:match("ide_term%.lua") then
          return
        end
      end
    end
    return orig_win_close(win, force)
  end
end

setup_protection()

local function get_sidebar_width()
  local cols = vim.o.columns
  local target = math.floor(cols * 0.28)
  if target < 45 then
    target = math.min(cols, 45)
  elseif target > 65 then
    target = 65
  end
  return target
end

local function get_project_root()
  local cur_buf = vim.api.nvim_get_current_buf()
  local root = vim.fs.root(cur_buf, { "pom.xml", ".git", "package.json", "build.gradle" })
  if not root or root == "" then
    local cwd = vim.fn.getcwd()
    root = vim.fs.root(cwd, { "pom.xml", ".git", "package.json", "build.gradle" }) or cwd
  end
  return root
end

local function focus_editor_window()
  local cur_win = vim.api.nvim_get_current_win()
  if cur_win ~= S.win and vim.api.nvim_win_is_valid(cur_win) then
    local cur_buf = vim.api.nvim_win_get_buf(cur_win)
    if vim.bo[cur_buf].filetype ~= "NvimTree" and vim.bo[cur_buf].buftype == "" then
      return
    end
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= S.win and vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype ~= "NvimTree" and vim.bo[buf].buftype == "" then
        pcall(vim.api.nvim_set_current_win, win)
        return
      end
    end
  end
end

local function get_command()
  if vim.fn.executable("agy") == 1 then
    return { "agy" }, nil
  end

  local shell = vim.o.shell
  if not shell or shell == "" then
    shell = os.getenv("SHELL") or "bash"
  end
  return { shell }, "[Antigravity AI] 'agy' CLI binary not found on PATH. Falling back to default shell: " .. shell
end

function M.render_winbar()
  local width = (S.win and vim.api.nvim_win_is_valid(S.win)) and vim.api.nvim_win_get_width(S.win) or 45

  local title_icon = "󰚩"
  local restart_icon = "󰑐"
  local close_icon = "󰅖"

  local title
  local restart_btn
  local hide_btn
  local close_btn

  if width >= 44 then
    title = "%#VSCodeAIHeaderTitle# " .. title_icon .. " Antigravity CLI %#VSCodeAIHeaderFill#%="
    restart_btn = "%@v:lua.ide_ai_sidebar_restart@%#VSCodeAIHeaderBtn# " .. restart_icon .. " Restart %X"
    hide_btn = "%@v:lua.ide_ai_sidebar_hide@%#VSCodeAIHeaderBtn# _ Hide %X"
    close_btn = "%@v:lua.ide_ai_sidebar_close@%#VSCodeAIHeaderClose# " .. close_icon .. " Close %X "
  elseif width >= 34 then
    title = "%#VSCodeAIHeaderTitle# " .. title_icon .. " AGY %#VSCodeAIHeaderFill#%="
    restart_btn = "%@v:lua.ide_ai_sidebar_restart@%#VSCodeAIHeaderBtn# " .. restart_icon .. " Restart %X"
    hide_btn = "%@v:lua.ide_ai_sidebar_hide@%#VSCodeAIHeaderBtn# _ Hide %X"
    close_btn = "%@v:lua.ide_ai_sidebar_close@%#VSCodeAIHeaderClose# " .. close_icon .. " %X "
  else
    title = "%#VSCodeAIHeaderTitle# " .. title_icon .. " %#VSCodeAIHeaderFill#%="
    restart_btn = "%@v:lua.ide_ai_sidebar_restart@%#VSCodeAIHeaderBtn# " .. restart_icon .. " %X"
    hide_btn = "%@v:lua.ide_ai_sidebar_hide@%#VSCodeAIHeaderBtn# _ %X"
    close_btn = "%@v:lua.ide_ai_sidebar_close@%#VSCodeAIHeaderClose# " .. close_icon .. " %X "
  end

  return title .. restart_btn .. "  " .. hide_btn .. "  " .. close_btn
end

function M.update_winbar()
  if S.win and vim.api.nvim_win_is_valid(S.win) then
    vim.wo[S.win].winbar = "%!v:lua.require('ide_ai_sidebar').render_winbar()"
  end
end

_G.ide_ai_sidebar_restart = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      M.restart()
    end)
  end
end

_G.ide_ai_sidebar_hide = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      M.hide()
    end)
  end
end

_G.ide_ai_sidebar_close = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      M.close()
    end)
  end
end

function M.spawn()
  if not (S.win and vim.api.nvim_win_is_valid(S.win)) then
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buflisted = false
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "ide_ai_sidebar"
  S.buf = buf

  vim.api.nvim_set_current_win(S.win)
  vim.api.nvim_win_set_buf(S.win, buf)

  local cmd, note = get_command()
  local root = get_project_root()

  if note then
    vim.notify(note, vim.log.levels.WARN)
  end

  S.job_id = vim.fn.jobstart(cmd, {
    cwd = root,
    term = true,
    on_exit = function(_, _, _)
      S.job_id = nil
      vim.schedule(function()
        if M.is_open() then
          M.update_winbar()
        end
      end)
    end,
  })

  vim.bo[buf].buflisted = false
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "ide_ai_sidebar"

  M.update_winbar()
  pcall(vim.cmd, "startinsert")
end

function M.open()
  if S.win and vim.api.nvim_win_is_valid(S.win) then
    vim.api.nvim_set_current_win(S.win)
    pcall(vim.cmd, "startinsert")
    return
  end

  focus_editor_window()

  local width = get_sidebar_width()
  vim.cmd("noautocmd botright vertical " .. width .. "split")
  S.win = vim.api.nvim_get_current_win()

  vim.wo[S.win].winfixwidth = true
  vim.wo[S.win].number = false
  vim.wo[S.win].relativenumber = false
  vim.wo[S.win].signcolumn = "no"
  vim.wo[S.win].foldcolumn = "0"
  vim.wo[S.win].list = false
  vim.wo[S.win].spell = false

  if S.buf and vim.api.nvim_buf_is_valid(S.buf) then
    vim.api.nvim_win_set_buf(S.win, S.buf)
    M.update_winbar()
    pcall(vim.cmd, "startinsert")
  else
    M.spawn()
  end

  pcall(vim.cmd, "redrawtabline")
end

function M.hide()
  if S.win and vim.api.nvim_win_is_valid(S.win) then
    local win = S.win
    S.win = nil
    pcall(vim.api.nvim_win_close, win, true)
  end
  S.win = nil
  focus_editor_window()
  pcall(vim.cmd, "redrawtabline")
end

function M.close()
  if S.job_id then
    pcall(vim.fn.jobstop, S.job_id)
    S.job_id = nil
  end

  if S.win and vim.api.nvim_win_is_valid(S.win) then
    local win = S.win
    S.win = nil
    pcall(vim.api.nvim_win_close, win, true)
  end
  S.win = nil

  if S.buf and vim.api.nvim_buf_is_valid(S.buf) then
    local buf = S.buf
    S.buf = nil
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.cmd, "silent! bwipeout! " .. buf)
      end
    end)
  end
  S.buf = nil

  focus_editor_window()
  pcall(vim.cmd, "redrawtabline")
end

function M.restart()
  if S.job_id then
    pcall(vim.fn.jobstop, S.job_id)
    S.job_id = nil
  end

  local old_buf = S.buf
  S.buf = nil

  if not M.is_open() then
    M.open()
  else
    M.spawn()
  end

  if old_buf and vim.api.nvim_buf_is_valid(old_buf) then
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(old_buf) then
        pcall(vim.cmd, "silent! bwipeout! " .. old_buf)
      end
    end)
  end
end

function M.is_open()
  return S.win ~= nil and vim.api.nvim_win_is_valid(S.win)
end

function M.toggle()
  if M.is_open() then
    M.hide()
  else
    M.open()
  end
end

function M.get_buf()
  return S.buf
end

function M.get_win()
  return S.win
end

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  callback = function()
    local cur_win = vim.api.nvim_get_current_win()
    if S.win and cur_win == S.win then
      M.update_winbar()
      pcall(vim.cmd, "startinsert")
    end
  end,
})

vim.api.nvim_create_autocmd("WinClosed", {
  callback = function(args)
    local closed_win = tonumber(args.match)
    if S.win and closed_win == S.win then
      S.win = nil
      pcall(vim.cmd, "redrawtabline")
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
  callback = function(args)
    local closed_buf = tonumber(args.match)
    if S.buf and closed_buf == S.buf then
      if S.job_id then
        pcall(vim.fn.jobstop, S.job_id)
        S.job_id = nil
      end
      S.buf = nil
    end
  end,
})

return M
