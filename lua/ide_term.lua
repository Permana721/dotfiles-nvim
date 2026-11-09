local M = {}

_G._ide_term_state = _G._ide_term_state or {
  terminals = {},
  active_idx = 1,
  term_win = nil,
  next_id = 1,
}

local S = _G._ide_term_state

local function is_managed_buf(buf)
  for i, t in ipairs(S.terminals) do
    if t.buf == buf then
      return true, i
    end
  end
  return false, nil
end

local function prune_terminals()
  for i = #S.terminals, 1, -1 do
    if not vim.api.nvim_buf_is_valid(S.terminals[i].buf) then
      table.remove(S.terminals, i)
    end
  end
  if S.active_idx > #S.terminals then
    S.active_idx = math.max(1, #S.terminals)
  end
end

local function enforce_single_term_win()
  local found_win = nil
  if S.term_win and vim.api.nvim_win_is_valid(S.term_win) then
    found_win = S.term_win
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local is_managed = is_managed_buf(buf)
    if is_managed or vim.bo[buf].buftype == "terminal" then
      if not found_win then
        found_win = win
      elseif win ~= found_win then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end

  S.term_win = found_win
  return found_win
end

local function focus_editor_window()
  local cur_win = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_win_get_buf(cur_win)
  if vim.bo[cur_buf].filetype ~= "NvimTree" and vim.bo[cur_buf].buftype == "" then
    return
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype ~= "NvimTree" and vim.bo[buf].buftype == "" then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
end

local function render_winbar()
  if not S.term_win or not vim.api.nvim_win_is_valid(S.term_win) then
    return
  end

  local parts = {}
  for i, t in ipairs(S.terminals) do
    _G["ide_term_tab_" .. i] = function(_, _, button)
      if button == "l" then
        M.select(i)
      elseif button == "m" then
        M.kill(i)
      end
    end

    _G["ide_term_close_" .. i] = function(_, _, button)
      if button == "l" then
        M.kill(i)
      end
    end

    local hl = (i == S.active_idx) and "%#TabLineSel#" or "%#TabLine#"
    local title = t.title or ("Terminal " .. t.id)
    parts[#parts + 1] = "%@v:lua.ide_term_tab_" .. i .. "@" .. hl .. " " .. title .. " %X"
      .. "%@v:lua.ide_term_close_" .. i .. "@" .. hl .. "x %X"
  end

  parts[#parts + 1] = "%#TabLineFill#%="
  parts[#parts + 1] = "%@v:lua.ide_term_new@%#TabLine# + New %X "
  parts[#parts + 1] = "%@v:lua.ide_term_hide@%#TabLine# _ Hide %X"

  vim.wo[S.term_win].winbar = table.concat(parts)
end

function M.open_window()
  enforce_single_term_win()

  if S.term_win and vim.api.nvim_win_is_valid(S.term_win) then
    vim.api.nvim_set_current_win(S.term_win)
    return
  end

  focus_editor_window()
  local height = math.max(10, math.floor(vim.o.lines * 0.28))
  vim.cmd("belowright " .. height .. "split")
  S.term_win = vim.api.nvim_get_current_win()

  vim.wo[S.term_win].number = false
  vim.wo[S.term_win].relativenumber = false
  vim.wo[S.term_win].signcolumn = "no"
  vim.wo[S.term_win].winfixheight = true
end

function M.on_term_exit(buf)
  local found, idx = is_managed_buf(buf)
  if not found then
    return
  end

  table.remove(S.terminals, idx)
  enforce_single_term_win()

  if #S.terminals == 0 then
    if S.term_win and vim.api.nvim_win_is_valid(S.term_win) then
      pcall(vim.api.nvim_win_close, S.term_win, true)
    end
    S.term_win = nil
    if vim.api.nvim_buf_is_valid(buf) then
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(vim.cmd, "silent! bwipeout! " .. buf)
        end
      end)
    end
    vim.cmd("redrawstatus")
    return
  end

  if idx < S.active_idx then
    S.active_idx = S.active_idx - 1
  elseif S.active_idx > #S.terminals then
    S.active_idx = #S.terminals
  end

  local next_buf = S.terminals[S.active_idx].buf

  if S.term_win and vim.api.nvim_win_is_valid(S.term_win) and vim.api.nvim_buf_is_valid(next_buf) then
    vim.api.nvim_win_set_buf(S.term_win, next_buf)
    render_winbar()
    if vim.api.nvim_get_current_win() == S.term_win then
      vim.cmd("startinsert")
    end
  end

  if vim.api.nvim_buf_is_valid(buf) then
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.cmd, "silent! bwipeout! " .. buf)
      end
    end)
  end

  vim.cmd("redrawstatus")
end

function M.new()
  prune_terminals()
  M.open_window()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buflisted = false
  vim.bo[buf].bufhidden = "hide"
  vim.api.nvim_win_set_buf(S.term_win, buf)

  local id = S.next_id
  S.next_id = S.next_id + 1

  local entry = { buf = buf, id = id, title = "Terminal " .. id, job = nil, is_runner = false }
  table.insert(S.terminals, entry)
  S.active_idx = #S.terminals

  local root = vim.fs.root(0, { "pom.xml", ".git" }) or vim.fn.getcwd()
  entry.job = vim.fn.jobstart({ vim.o.shell }, {
    cwd = root,
    term = true,
    on_exit = function()
      vim.schedule(function()
        M.on_term_exit(buf)
      end)
    end,
  })

  vim.bo[buf].buflisted = false
  render_winbar()
  vim.cmd("startinsert")
  vim.cmd("redrawstatus")
end

function M.run_java(runner_script, main_class, project_root)
  prune_terminals()
  M.open_window()

  local runner_idx = nil
  for i, t in ipairs(S.terminals) do
    if t.is_runner then
      runner_idx = i
      break
    end
  end

  local prev_buf = nil
  if runner_idx then
    local old = S.terminals[runner_idx]
    prev_buf = old.buf
    old.buf = -1
    if old.job then
      pcall(vim.fn.jobstop, old.job)
      old.job = nil
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buflisted = false
  vim.bo[buf].bufhidden = "hide"
  vim.api.nvim_win_set_buf(S.term_win, buf)

  if prev_buf and vim.api.nvim_buf_is_valid(prev_buf) then
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(prev_buf) then
        pcall(vim.cmd, "silent! bwipeout! " .. prev_buf)
      end
    end)
  end

  local short_name = main_class:match("([^%.]+)$") or main_class
  local entry = {
    buf = buf,
    id = 0,
    title = "Run: " .. short_name,
    job = nil,
    is_runner = true,
  }

  if runner_idx then
    S.terminals[runner_idx] = entry
    S.active_idx = runner_idx
  else
    table.insert(S.terminals, entry)
    S.active_idx = #S.terminals
  end

  entry.job = vim.fn.jobstart({ "bash", runner_script, main_class }, {
    cwd = project_root,
    term = true,
    on_exit = function()
      entry.job = nil
      vim.schedule(function()
        vim.cmd("redrawstatus")
      end)
    end,
  })

  vim.bo[buf].buflisted = false
  render_winbar()
  vim.cmd("startinsert")
  vim.cmd("redrawstatus")
end

function M.stop_java()
  prune_terminals()
  for i, t in ipairs(S.terminals) do
    if t.is_runner then
      M.kill(i)
      return true
    end
  end
  return false
end

function M.is_java_running()
  for _, t in ipairs(S.terminals) do
    if t.is_runner and t.job ~= nil then
      return true
    end
  end
  return false
end

function M.select(idx)
  prune_terminals()
  if not S.terminals[idx] then
    return
  end

  S.active_idx = idx
  M.open_window()
  vim.api.nvim_win_set_buf(S.term_win, S.terminals[S.active_idx].buf)
  vim.bo[S.terminals[S.active_idx].buf].buflisted = false
  render_winbar()
  vim.cmd("startinsert")
end

function M.next()
  prune_terminals()
  if #S.terminals <= 1 then
    return
  end
  local idx = (S.active_idx % #S.terminals) + 1
  M.select(idx)
end

function M.prev()
  prune_terminals()
  if #S.terminals <= 1 then
    return
  end
  local idx = ((S.active_idx - 2) % #S.terminals) + 1
  M.select(idx)
end

function M.kill(idx)
  prune_terminals()
  local target_idx = idx or S.active_idx
  local target = S.terminals[target_idx]
  if not target then
    return
  end

  local target_buf = target.buf
  local target_job = target.job
  target.job = nil

  M.on_term_exit(target_buf)

  if target_job then
    pcall(vim.fn.jobstop, target_job)
  end
end

function M.hide()
  enforce_single_term_win()
  if S.term_win and vim.api.nvim_win_is_valid(S.term_win) then
    pcall(vim.api.nvim_win_close, S.term_win, true)
    S.term_win = nil
    vim.cmd("redrawstatus")
  end
end

function M.toggle()
  prune_terminals()
  enforce_single_term_win()
  if S.term_win and vim.api.nvim_win_is_valid(S.term_win) then
    M.hide()
  elseif #S.terminals == 0 then
    M.new()
  else
    M.select(S.active_idx)
  end
end

_G.ide_term_new = function(_, _, button)
  if button == "l" then
    M.new()
  end
end

_G.ide_term_hide = function(_, _, button)
  if button == "l" then
    M.hide()
  end
end

_G.ide_term_toggle = function(_, _, button)
  if button == "l" then
    M.toggle()
  end
end

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  callback = function()
    local cur_buf = vim.api.nvim_get_current_buf()
    local managed, idx = is_managed_buf(cur_buf)
    if managed then
      S.active_idx = idx
      S.term_win = vim.api.nvim_get_current_win()
      enforce_single_term_win()
      render_winbar()
    end
  end,
})

return M
