require "nvchad.mappings"

pcall(vim.keymap.del, "t", "<C-x>")
pcall(require, "var_suggest")

local map = vim.keymap.set

_G._leaving_term_by_mouse = false
_G._scrolling_term = false

local function get_escape_prefix(mode)
  local prefix = mode:sub(1, 1)
  if prefix == "t" then
    return "<C-\\><C-n>"
  elseif mode == "v" or mode == "V" or mode == "\22" or prefix == "s" or prefix == "i" then
    return "<Esc>"
  end
  return ""
end

local function is_cmp_menu_win(winid)
  if not winid or winid == 0 or not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(winid)
  if vim.bo[buf].filetype == "cmp_menu" then
    local ok, cmp = pcall(require, "cmp")
    if ok and cmp.visible() then
      return true, cmp
    end
  end
  return false
end

map({ "n", "i", "v", "x", "s", "t" }, "<LeftMouse>", function()
  local pos = vim.fn.getmousepos()
  local mode = vim.api.nvim_get_mode().mode
  local esc = get_escape_prefix(mode)

  local is_cmp, cmp = is_cmp_menu_win(pos.winid)
  if is_cmp then
    vim.schedule(function()
      local target_line = pos.line
      local entries_view = cmp.core.view and cmp.core.view:_get_entries_view()
      if entries_view and entries_view.entries then
        local cur_idx = 0
        local selected = cmp.get_selected_entry()
        if selected then
          for i, e in ipairs(entries_view.entries) do
            if e == selected then
              cur_idx = i
              break
            end
          end
        end
        local delta = target_line - cur_idx
        if delta > 0 then
          for _ = 1, delta do
            cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
          end
        elseif delta < 0 then
          for _ = 1, -delta do
            cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
          end
        end
      end
      cmp.confirm({ select = true })
    end)
    return ""
  end

  if pos.winid > 0 and pos.line == 0 then
    local buf = vim.api.nvim_win_is_valid(pos.winid) and vim.api.nvim_win_get_buf(pos.winid) or 0
    local ft = buf > 0 and vim.bo[buf].filetype or ""
    local bt = buf > 0 and vim.bo[buf].buftype or ""
    if ft == "qf" or bt == "quickfix" then
      local width = vim.api.nvim_win_get_width(pos.winid)
      if pos.wincol >= math.max(1, width - 14) then
        vim.schedule(function()
          if _G.close_diagnostic_window then
            _G.close_diagnostic_window(pos.winid, 1, "l", "")
          else
            pcall(vim.cmd, "cclose")
            pcall(vim.cmd, "lclose")
          end
        end)
        return ""
      end
      return ""
    end
  end

  if pos.winid == 0 or pos.line == 0 then
    _G._leaving_term_by_mouse = true
    vim.schedule(function()
      _G._leaving_term_by_mouse = false
      if vim.bo.buftype == "terminal" and vim.api.nvim_get_mode().mode:sub(1, 1) ~= "t" then
        _G._scrolling_term = false
        pcall(vim.cmd, "startinsert")
      end
    end)
    return esc .. "<LeftMouse>"
  end

  local buf = vim.api.nvim_win_get_buf(pos.winid)
  local bt = vim.bo[buf].buftype
  local ft = vim.bo[buf].filetype

  if bt == "terminal" then
    _G._scrolling_term = false
    if vim.api.nvim_get_current_win() == pos.winid and mode:sub(1, 1) == "t" then
      return ""
    end
    _G._leaving_term_by_mouse = true
    vim.schedule(function()
      _G._leaving_term_by_mouse = false
      if vim.api.nvim_win_is_valid(pos.winid) then
        vim.api.nvim_set_current_win(pos.winid)
        pcall(vim.cmd, "startinsert")
      end
    end)
    return esc
  end

  if ft == "NvimTree" or bt ~= "" or not vim.bo[buf].modifiable then
    _G._leaving_term_by_mouse = true
    vim.schedule(function()
      _G._leaving_term_by_mouse = false
    end)
    return esc .. "<LeftMouse>"
  end

  _G._leaving_term_by_mouse = true
  vim.schedule(function()
    _G._leaving_term_by_mouse = false
    if vim.bo.buftype == "" and vim.bo.modifiable and vim.bo.filetype ~= "NvimTree" then
      pcall(vim.cmd, "startinsert")
    end
  end)

  if mode:sub(1, 1) == "i" then
    return "<LeftMouse>"
  end
  return esc .. "<LeftMouse>"
end, { expr = true, desc = "Smart IDE mouse click handler" })

map("i", "<Down>", function()
  local ok, cmp = pcall(require, "cmp")
  if ok and cmp.visible() then
    cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
  else
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Down>", true, false, true), "n", false)
  end
end, { desc = "Next item in completion menu or move down" })

map("i", "<Up>", function()
  local ok, cmp = pcall(require, "cmp")
  if ok and cmp.visible() then
    cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
  else
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Up>", true, false, true), "n", false)
  end
end, { desc = "Previous item in completion menu or move up" })

map({ "n", "i", "v", "x", "s", "t" }, "<LeftDrag>", function()
  local pos = vim.fn.getmousepos()
  if pos.winid == 0 then
    return ""
  end
  local buf = vim.api.nvim_win_get_buf(pos.winid)
  if vim.bo[buf].buftype == "terminal" or vim.bo[buf].filetype == "NvimTree" or not vim.bo[buf].modifiable then
    return ""
  end
  return "<LeftDrag>"
end, { expr = true, desc = "Prevent accidental visual drag in UI panels and terminal" })

local locked_term_events = {
  "<2-LeftMouse>",
  "<3-LeftMouse>",
  "<4-LeftMouse>",
  "<MiddleMouse>",
}

for _, key in ipairs(locked_term_events) do
  map("t", key, function()
    local pos = vim.fn.getmousepos()
    if pos.winid > 0 and vim.bo[vim.api.nvim_win_get_buf(pos.winid)].buftype == "terminal" then
      return ""
    end
    return key
  end, { expr = true, desc = "Lock terminal mouse click events" })
end

map({ "n", "i", "v", "x", "s", "t" }, "<ScrollWheelUp>", function()
  local pos = vim.fn.getmousepos()
  if pos.winid == 0 then
    return "<ScrollWheelUp>"
  end

  local is_cmp, cmp = is_cmp_menu_win(pos.winid)
  if is_cmp then
    vim.schedule(function()
      cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
    end)
    return ""
  end

  local buf = vim.api.nvim_win_get_buf(pos.winid)
  if vim.bo[buf].buftype == "terminal" then
    _G._scrolling_term = true
    _G._leaving_term_by_mouse = true
    local mode = vim.api.nvim_get_mode().mode
    local esc = get_escape_prefix(mode)

    vim.schedule(function()
      _G._leaving_term_by_mouse = false
      if vim.api.nvim_win_is_valid(pos.winid) then
        vim.api.nvim_set_current_win(pos.winid)
        vim.cmd("normal! 3\25")
      end
    end)
    return esc
  end

  return "<ScrollWheelUp>"
end, { expr = true, desc = "Smooth scroll up in terminal and completion menu" })

map({ "n", "i", "v", "x", "s", "t" }, "<ScrollWheelDown>", function()
  local pos = vim.fn.getmousepos()
  if pos.winid == 0 then
    return "<ScrollWheelDown>"
  end

  local is_cmp, cmp = is_cmp_menu_win(pos.winid)
  if is_cmp then
    vim.schedule(function()
      cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
    end)
    return ""
  end

  local buf = vim.api.nvim_win_get_buf(pos.winid)
  if vim.bo[buf].buftype == "terminal" then
    local mode = vim.api.nvim_get_mode().mode
    if mode:sub(1, 1) == "t" then
      return ""
    end

    vim.schedule(function()
      if vim.api.nvim_win_is_valid(pos.winid) then
        vim.api.nvim_set_current_win(pos.winid)
        vim.cmd("normal! 3\5")
        local info = vim.fn.getwininfo(pos.winid)[1]
        local total = vim.api.nvim_buf_line_count(buf)
        if info and (info.botline >= total) then
          _G._scrolling_term = false
          pcall(vim.cmd, "startinsert")
        end
      end
    end)
    return ""
  end

  return "<ScrollWheelDown>"
end, { expr = true, desc = "Smooth scroll down in terminal and completion menu" })

map("t", "<C-\\><C-n>", "<Nop>", { desc = "Disable terminal normal mode escape" })
map("t", "<C-\\><C-o>", "<Nop>", { desc = "Disable terminal single normal command" })

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(args)
    vim.bo[args.buf].scrollback = 100000
    vim.keymap.set("n", "<LeftMouse>", function()
      _G._scrolling_term = false
      pcall(vim.cmd, "startinsert")
    end, { buffer = args.buf, silent = true })

    vim.keymap.set("n", "<CR>", function()
      _G._scrolling_term = false
      pcall(vim.cmd, "startinsert")
    end, { buffer = args.buf, silent = true })
  end,
})

vim.api.nvim_create_autocmd({ "ModeChanged", "BufEnter", "WinEnter", "TermOpen" }, {
  callback = function()
    if _G._leaving_term_by_mouse or _G._scrolling_term then
      return
    end
    if vim.bo.buftype == "terminal" and vim.api.nvim_get_mode().mode:sub(1, 1) ~= "t" then
      vim.schedule(function()
        if
          not _G._leaving_term_by_mouse
          and not _G._scrolling_term
          and vim.bo.buftype == "terminal"
          and vim.api.nvim_get_mode().mode:sub(1, 1) ~= "t"
        then
          pcall(vim.cmd, "startinsert")
        end
      end)
    end
  end,
})

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map({ "n", "i" }, "<C-LeftMouse>", function()
  local mouse_pos = vim.fn.getmousepos()
  if mouse_pos.winid == 0 or mouse_pos.line == 0 then
    return
  end
  vim.cmd("stopinsert")
  vim.api.nvim_set_current_win(mouse_pos.winid)
  vim.api.nvim_win_set_cursor(mouse_pos.winid, { mouse_pos.line, math.max(0, mouse_pos.column - 1) })

  local params = vim.lsp.util.make_position_params(0, "utf-16")
  local cur_uri = vim.uri_from_bufnr(0)
  local cur_line = mouse_pos.line - 1

  vim.lsp.buf_request(0, "textDocument/definition", params, function(_, result)
    if not result or vim.tbl_isempty(result) then
      vim.lsp.buf.implementation()
      return
    end

    local def = vim.islist(result) and result[1] or result
    local target_uri = def.uri or def.targetUri
    local target_range = def.range or def.targetSelectionRange

    if target_uri == cur_uri and target_range.start.line == cur_line then
      vim.lsp.buf.implementation()
    else
      vim.lsp.buf.definition()
    end
  end)
end, { desc = "Smart Go to Definition / Implementation / JDK Source" })

map({ "n", "i" }, "<M-LeftMouse>", "<Esc><C-o>", { desc = "Jump Back (Mouse)" })

map({ "n", "i", "v", "t" }, "<RightMouse>", function()
  local pos = vim.fn.getmousepos()
  if pos.winid == 0 or pos.line == 0 then
    return
  end
  local buf = vim.api.nvim_win_get_buf(pos.winid)
  if vim.bo[buf].buftype == "terminal" then
    _G._scrolling_term = false
    _G._leaving_term_by_mouse = true
    vim.cmd("stopinsert")
    vim.api.nvim_set_current_win(pos.winid)
    _G._leaving_term_by_mouse = false
    pcall(vim.cmd, "startinsert")
    return
  end
  if vim.bo[buf].buftype == "" and vim.bo[buf].modifiable and vim.bo[buf].filetype ~= "NvimTree" then
    _G._leaving_term_by_mouse = true
    vim.cmd("stopinsert")
    vim.api.nvim_set_current_win(pos.winid)
    local line_count = vim.api.nvim_buf_line_count(buf)
    local target_line = math.min(math.max(1, pos.line), line_count)
    local line_str = vim.api.nvim_buf_get_lines(buf, target_line - 1, target_line, false)[1] or ""
    local target_col = math.min(math.max(0, pos.column - 1), #line_str)
    vim.api.nvim_win_set_cursor(pos.winid, { target_line, target_col })
    _G._leaving_term_by_mouse = false
    vim.lsp.buf.code_action()
  end
end, { desc = "LSP Code Action (Mouse)" })

map({ "n", "i" }, "<M-CR>", vim.lsp.buf.code_action, { desc = "LSP Quick Fix / Code Action" })
map({ "n", "i" }, "<C-M-LeftMouse>", "<Esc><LeftMouse><cmd>lua vim.lsp.buf.implementation()<CR>", { desc = "LSP Go to Implementation (Mouse)" })
map("n", "gi", vim.lsp.buf.implementation, { desc = "LSP Go to Implementation" })

map("n", "<C-z>", "u", { desc = "Undo" })
map("i", "<C-z>", "<C-o>u", { desc = "Undo in insert mode" })
map("v", "<C-z>", "<Esc>u", { desc = "Undo in visual mode" })

map("n", "<C-y>", "<C-r>", { desc = "Redo" })
map("i", "<C-y>", "<C-o><C-r>", { desc = "Redo in insert mode" })

map("n", "<C-a>", "ggVG", { desc = "Select all" })
map("i", "<C-a>", "<Esc>ggVG", { desc = "Select all in insert mode" })

map("v", "<C-c>", '"+y', { desc = "Copy selection to system clipboard" })
map("n", "<C-c>", '"+yy', { desc = "Copy current line to system clipboard" })

map("n", "<C-x>", '"+dd', { desc = "Cut current line to system clipboard" })
map("i", "<C-x>", '<Esc>"+ddi', { desc = "Cut current line in insert mode" })
map("v", "<C-x>", '"+d', { desc = "Cut selection to system clipboard" })

map("i", "<C-v>", "<C-r>+", { desc = "Paste from system clipboard in insert mode" })
map("n", "<C-v>", '"+p', { desc = "Paste from system clipboard" })

map("x", "<BS>", '"_d', { desc = "Delete selected text with Backspace" })
map("x", "<Del>", '"_d', { desc = "Delete selected text with Delete" })

map({ "n", "i", "v" }, "<C-s>", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<C-q>", "<cmd>q<CR>", { desc = "Quit current window" })

map("i", "<C-BS>", "<C-w>", { desc = "Delete word backwards" })
map("i", "<C-H>", "<C-w>", { desc = "Delete word backwards" })

map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center cursor" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center cursor" })

map("n", "<M-j>", ":m .+1<CR>==", { desc = "Move line down" })
map("n", "<M-k>", ":m .-2<CR>==", { desc = "Move line up" })
map("i", "<M-j>", "<Esc>:m .+1<CR>==gi", { desc = "Move line down in insert mode" })
map("i", "<M-k>", "<Esc>:m .-2<CR>==gi", { desc = "Move line up in insert mode" })
map("v", "<M-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "<M-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "BufLeave" }, {
  callback = function()
    if vim.bo.modified and vim.fn.expand("%") ~= "" and vim.bo.buftype == "" then
      vim.cmd("silent! update")
    end
  end,
})

map("i", "<C-space>", function()
  local ok, vs = pcall(require, "var_suggest")
  if ok then
    vs.suggest_variable_names()
  end
end, { desc = "Generate smart variable name suggestions" })

local ok_term, ide_term = pcall(require, "ide_term")
if ok_term then
  map({ "n", "i", "t" }, "<C-\\>", ide_term.toggle, { desc = "Toggle stacked terminal panel" })
  map({ "n", "i", "t" }, "<M-t>", ide_term.toggle, { desc = "Toggle stacked terminal panel" })
  map({ "n", "t" }, "<M-n>", ide_term.new, { desc = "New stacked terminal session" })
  map({ "n", "t" }, "<M-]>", ide_term.next, { desc = "Next terminal tab" })
  map({ "n", "t" }, "<M-[>", ide_term.prev, { desc = "Previous terminal tab" })
end

local function toggle_ai_sidebar()
  local ok, ai = pcall(require, "ide_ai_sidebar")
  if ok and ai.toggle then
    ai.toggle()
  end
end

map({ "n", "i", "t", "v" }, "<C-M-a>", toggle_ai_sidebar, { desc = "Toggle Antigravity AI sidebar" })
map({ "n", "v", "t" }, "<leader>ai", toggle_ai_sidebar, { desc = "Toggle Antigravity AI sidebar" })

local search_win = nil
local search_buf = nil

local function close_floating_search()
  if search_win and vim.api.nvim_win_is_valid(search_win) then
    pcall(vim.api.nvim_win_close, search_win, true)
  end
  search_win = nil
end

local function open_floating_search()
  local target_win = vim.api.nvim_get_current_win()
  local target_buf = vim.api.nvim_win_get_buf(target_win)

  if vim.bo[target_buf].filetype == "NvimTree" or vim.bo[target_buf].buftype == "terminal" then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local b = vim.api.nvim_win_get_buf(win)
      if vim.bo[b].filetype ~= "NvimTree" and vim.bo[b].buftype == "" then
        target_win = win
        break
      end
    end
  end

  if search_win and vim.api.nvim_win_is_valid(search_win) then
    vim.api.nvim_set_current_win(search_win)
    vim.cmd("startinsert!")
    return
  end

  if not search_buf or not vim.api.nvim_buf_is_valid(search_buf) then
    search_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[search_buf].buftype = "nofile"
    vim.bo[search_buf].bufhidden = "hide"
    vim.bo[search_buf].swapfile = false
  end

  local width = 38
  local win_width = vim.api.nvim_win_get_width(target_win)

  search_win = vim.api.nvim_open_win(search_buf, true, {
    relative = "win",
    win = target_win,
    row = 0,
    col = math.max(0, win_width - width - 4),
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    title = "  Find (Enter/↓: Next, ↑: Prev) ",
    title_pos = "left",
  })

  vim.api.nvim_buf_set_lines(search_buf, 0, -1, false, { "" })
  vim.cmd("startinsert")

  local function perform_search(forward, move_cursor)
    local query = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)[1] or ""
    if query == "" then
      vim.cmd("nohlsearch")
      return
    end

    local escaped = vim.fn.escape(query, [[/\.*$^~[]])
    vim.fn.setreg("/", "\\V\\c" .. escaped)
    vim.o.hlsearch = true

    if vim.api.nvim_win_is_valid(target_win) then
      vim.api.nvim_win_call(target_win, function()
        local flags = forward and "w" or "bw"
        if not move_cursor then
          flags = flags .. "c"
        end
        pcall(vim.fn.search, "\\V\\c" .. escaped, flags)
        vim.cmd("normal! zz")
      end)
    end
    vim.cmd("redraw")
  end

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = search_buf,
    callback = function()
      perform_search(true, false)
    end,
  })

  local opts = { buffer = search_buf, silent = true }

  vim.keymap.set({ "i", "n" }, "<CR>", function()
    perform_search(true, true)
  end, opts)

  vim.keymap.set({ "i", "n" }, "<Down>", function()
    perform_search(true, true)
  end, opts)

  vim.keymap.set({ "i", "n" }, "<Up>", function()
    perform_search(false, true)
  end, opts)

  vim.keymap.set({ "i", "n" }, "<Esc>", function()
    close_floating_search()
    vim.cmd("nohlsearch")
    if vim.api.nvim_win_is_valid(target_win) then
      vim.api.nvim_set_current_win(target_win)
      vim.cmd("startinsert")
    end
  end, opts)

  vim.keymap.set({ "i", "n" }, "<C-f>", function()
    close_floating_search()
    vim.cmd("nohlsearch")
    if vim.api.nvim_win_is_valid(target_win) then
      vim.api.nvim_set_current_win(target_win)
      vim.cmd("startinsert")
    end
  end, opts)
end

map({ "n", "i", "v" }, "<C-f>", open_floating_search, { desc = "Find keyword in current file" })
map({ "n", "i", "v" }, "<C-S-f>", "<Esc><cmd>Telescope live_grep<CR>", { desc = "Find keyword in project" })

_G.open_floating_search = open_floating_search

map({ "n", "i", "v" }, "<M-f>", function()
  require("vscode_header").open_menu("File")
end, { desc = "VS Code Top Header: File Menu" })

map({ "n", "i", "v" }, "<M-e>", function()
  require("vscode_header").open_menu("Edit")
end, { desc = "VS Code Top Header: Edit Menu" })

map({ "n", "i", "v" }, "<M-r>", function()
  require("vscode_header").open_menu("Run")
end, { desc = "VS Code Top Header: Run Menu" })

map({ "n", "i", "v" }, "<M-T>", function()
  require("vscode_header").open_menu("Terminal")
end, { desc = "VS Code Top Header: Terminal Menu" })

map({ "n", "i", "v" }, "<leader>mt", function()
  require("vscode_header").open_menu("Terminal")
end, { desc = "VS Code Top Header: Terminal Menu" })

map({ "n", "i", "v" }, "<M-h>", function()
  require("vscode_header").open_menu("Help")
end, { desc = "VS Code Top Header: Help Menu" })

map({ "n", "i", "v" }, "<C-p>", function()
  require("vscode_header").open_search()
end, { desc = "VS Code Global Search (Quick Open)" })

local default_commentstrings = {
  java = "// %s",
  sql = "-- %s",
  pgsql = "-- %s",
  mysql = "-- %s",
  lua = "-- %s",
  sh = "# %s",
  bash = "# %s",
  zsh = "# %s",
  python = "# %s",
  xml = "<!-- %s -->",
  html = "<!-- %s -->",
  javascript = "// %s",
  typescript = "// %s",
  javascriptreact = "// %s",
  typescriptreact = "// %s",
  c = "// %s",
  cpp = "// %s",
  rust = "// %s",
  go = "// %s",
}

local function ensure_commentstring()
  local ft = vim.bo.filetype
  if ft == "sql" or ft == "pgsql" or ft == "mysql" then
    vim.bo.commentstring = "-- %s"
  elseif vim.bo.commentstring == "" or not vim.bo.commentstring:find("%%s") then
    local fallback = default_commentstrings[ft]
    if fallback then
      vim.bo.commentstring = fallback
    end
  end
end

local function toggle_comment_insert()
  ensure_commentstring()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_before = vim.api.nvim_get_current_line()
  local cs = vim.bo.commentstring
  if line_before:match("^%s*$") and cs and cs:find("%%s") then
    local indent = line_before
    local s_idx = cs:find("%%s")
    local comment_text = cs:gsub("%%s", "")
    local new_line = indent .. comment_text
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, { cursor[1], #indent + s_idx - 1 })
    return
  end
  vim.cmd.normal({ "gcc", bang = false })
  local line_after = vim.api.nvim_get_current_line()
  local col_diff = #line_after - #line_before
  local new_col = math.max(0, cursor[2] + col_diff)
  vim.api.nvim_win_set_cursor(0, { cursor[1], new_col })
end

map("n", "<C-/>", function()
  ensure_commentstring()
  return (vim.v.count > 0 and vim.v.count or "") .. "gcc"
end, { expr = true, remap = true, desc = "Toggle line comment" })

map("n", "<C-_>", function()
  ensure_commentstring()
  return (vim.v.count > 0 and vim.v.count or "") .. "gcc"
end, { expr = true, remap = true, desc = "Toggle line comment" })

map({ "v", "x" }, "<C-/>", function()
  ensure_commentstring()
  return "gc"
end, { expr = true, remap = true, desc = "Toggle comment block" })

map({ "v", "x" }, "<C-_>", function()
  ensure_commentstring()
  return "gc"
end, { expr = true, remap = true, desc = "Toggle comment block" })

map("i", "<C-/>", toggle_comment_insert, { desc = "Toggle line comment" })
map("i", "<C-_>", toggle_comment_insert, { desc = "Toggle line comment" })
