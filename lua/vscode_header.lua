local M = {}

local api = vim.api

local function setup_highlights()
  pcall(function()
    if vim.g.base46_cache then
      pcall(dofile, vim.g.base46_cache .. "tbline")
      pcall(dofile, vim.g.base46_cache .. "nvimtree")
    end
  end)

  local tree_hl = api.nvim_get_hl(0, { name = "NvimTreeNormal" })
  local tree_bg = tree_hl.bg and string.format("#%06x", tree_hl.bg) or "#1e222a"

  local hl = {
    VSCodeHeaderNormal = { fg = "#abb2bf", bg = "#1e222a" },
    VSCodeHeaderFill = { fg = "#abb2bf", bg = "#1e222a" },
    VSCodeHeaderMenu = { fg = "#abb2bf", bg = "#1e222a" },
    VSCodeHeaderMenuHover = { fg = "#ffffff", bg = "#282c34", bold = true },
    VSCodeHeaderSearch = { fg = "#abb2bf", bg = "#282c34" },
    VSCodeHeaderSearchBorder = { fg = "#3e4451", bg = "#1e222a" },
    VSCodeHeaderProject = { fg = "#98c379", bg = "#282c34", bold = true },
    VSCodeHeaderKey = { fg = "#5c6370", bg = "#282c34" },
    VSCodeExplorerHeader = { fg = "#abb2bf", bg = tree_bg, bold = true },
    VSCodeExplorerAction = { fg = "#abb2bf", bg = tree_bg },

    VSCodeHeaderRunPill = { fg = "#abb2bf", bg = "#282c34" },
    VSCodeHeaderRunBorder = { fg = "#3e4451", bg = "#1e222a" },
    VSCodeHeaderRunIcon = { fg = "#98c379", bg = "#282c34" },
    VSCodeHeaderRunName = { fg = "#abb2bf", bg = "#282c34", bold = true },
    VSCodeHeaderRunArrow = { fg = "#5c6370", bg = "#282c34" },
    VSCodeHeaderRunBtn = { fg = "#98c379", bg = "#282c34", bold = true },
    VSCodeHeaderRunBtnActive = { fg = "#61afef", bg = "#282c34", bold = true },
    VSCodeHeaderStopBtn = { fg = "#e06c75", bg = "#282c34", bold = true },
    VSCodeHeaderStopBtnIdle = { fg = "#5c6370", bg = "#282c34" },
    VSCodeHeaderAIBtn = { fg = "#abb2bf", bg = "#1e222a" },
    VSCodeHeaderAIBtnActive = { fg = "#61afef", bg = "#282c34", bold = true },
  }

  for name, opts in pairs(hl) do
    api.nvim_set_hl(0, name, opts)
  end
end

setup_highlights()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = setup_highlights,
})

vim.cmd([[
  if !exists('*TbGoToBuf')
    function! TbGoToBuf(bufnr,b,c,d)
      call luaeval('require("nvchad.tabufline").goto_buf(_A)', a:bufnr)
    endfunction
  endif
  if !exists('*TbKillBuf')
    function! TbKillBuf(bufnr,b,c,d)
      call luaeval('require("nvchad.tabufline").close_buffer(_A)', a:bufnr)
    endfunction
  endif
  if !exists('*TbToggle_theme')
    function! TbToggle_theme(a,b,c,d)
      lua require('base46').toggle_theme()
    endfunction
  endif
  if !exists('*TbCloseAllBufs')
    function! TbCloseAllBufs(a,b,c,d)
      lua require('nvchad.tabufline').closeAllBufs()
    endfunction
  endif
]])

local function is_valid_editor_buf(bufnr)
  if not bufnr or not api.nvim_buf_is_valid(bufnr) then
    return false
  end
  if vim.bo[bufnr].filetype == "NvimTree" then
    return false
  end
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end
  local name = api.nvim_buf_get_name(bufnr)
  local fname = vim.fn.fnamemodify(name, ":t")
  if name:match("NvimTree_") or fname:match("^NvimTree_") then
    return false
  end
  if not vim.bo[bufnr].buflisted then
    return false
  end
  return true
end

local function sanitize_tab_bufs()
  if vim.t.bufs then
    local filtered = vim.tbl_filter(is_valid_editor_buf, vim.t.bufs)
    if #filtered ~= #vim.t.bufs then
      vim.t.bufs = filtered
    end
    return filtered
  end
  return {}
end

local function focus_editor_window()
  local cur_win = api.nvim_get_current_win()
  local cur_buf = api.nvim_win_get_buf(cur_win)
  if vim.bo[cur_buf].filetype == "NvimTree" then
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
      local b = api.nvim_win_get_buf(win)
      if vim.bo[b].filetype ~= "NvimTree" and vim.bo[b].buftype == "" then
        api.nvim_set_current_win(win)
        return win
      end
    end
  end
  return cur_win
end

vim.api.nvim_create_autocmd({ "BufAdd", "BufEnter", "FileType" }, {
  callback = function(args)
    local buf = args.buf
    if not api.nvim_buf_is_valid(buf) then
      return
    end
    local ft = vim.bo[buf].filetype
    local name = api.nvim_buf_get_name(buf)
    local fname = vim.fn.fnamemodify(name, ":t")
    if ft == "NvimTree" or fname:match("^NvimTree_") or name:match("NvimTree_") then
      vim.bo[buf].buflisted = false
    end
    sanitize_tab_bufs()
  end,
})

local ok_tbl, tabufline = pcall(require, "nvchad.tabufline")
if ok_tbl and not M._tabufline_hooked then
  if tabufline.goto_buf then
    local orig_goto = tabufline.goto_buf
    tabufline.goto_buf = function(bufnr)
      if not is_valid_editor_buf(bufnr) then
        return
      end
      focus_editor_window()
      orig_goto(bufnr)
    end
  end

  if tabufline.next then
    local orig_next = tabufline.next
    tabufline.next = function()
      sanitize_tab_bufs()
      focus_editor_window()
      orig_next()
    end
  end

  if tabufline.prev then
    local orig_prev = tabufline.prev
    tabufline.prev = function()
      sanitize_tab_bufs()
      focus_editor_window()
      orig_prev()
    end
  end

  if tabufline.close_buffer then
    local orig_close = tabufline.close_buffer
    tabufline.close_buffer = function(bufnr)
      sanitize_tab_bufs()
      bufnr = bufnr or api.nvim_get_current_buf()
      if not is_valid_editor_buf(bufnr) then
        return
      end
      focus_editor_window()
      orig_close(bufnr)
      sanitize_tab_bufs()
    end
  end

  if tabufline.closeAllBufs then
    local orig_close_all = tabufline.closeAllBufs
    tabufline.closeAllBufs = function(include_cur_buf)
      sanitize_tab_bufs()
      orig_close_all(include_cur_buf)
      sanitize_tab_bufs()
    end
  end

  M._tabufline_hooked = true
end

_G.vscode_menu_file = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      M.open_menu("File")
    end)
  end
end

_G.vscode_menu_edit = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      M.open_menu("Edit")
    end)
  end
end

_G.vscode_menu_run = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      M.open_menu("Run")
    end)
  end
end

_G.vscode_menu_terminal = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      M.open_menu("Terminal")
    end)
  end
end

_G.vscode_menu_help = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      M.open_menu("Help")
    end)
  end
end

_G.vscode_open_shortcuts = function()
  local shortcuts_path = vim.fn.stdpath("config") .. "/SHORTCUTS.md"
  if vim.fn.filereadable(shortcuts_path) == 0 then
    shortcuts_path = vim.fn.expand("~/.config/nvim/SHORTCUTS.md")
  end

  if vim.fn.filereadable(shortcuts_path) == 0 then
    vim.notify("Shortcuts reference file not found at " .. shortcuts_path, vim.log.levels.WARN)
    return
  end

  local lines = vim.fn.readfile(shortcuts_path)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  local width = math.min(120, math.max(60, math.floor(vim.o.columns * 0.85)))
  local height = math.min(45, math.max(15, math.floor(vim.o.lines * 0.85)))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " 󰌌 Keyboard Shortcuts & Keymaps (Press 'q' or <Esc> to exit) ",
    title_pos = "center",
  })

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true

  local function close_viewer()
    if win and api.nvim_win_is_valid(win) then
      pcall(api.nvim_win_close, win, true)
    end
  end

  vim.keymap.set("n", "q", close_viewer, { buffer = buf, silent = true, desc = "Close shortcuts viewer" })
  vim.keymap.set("n", "<Esc>", close_viewer, { buffer = buf, silent = true, desc = "Close shortcuts viewer" })
end

M.open_shortcuts = _G.vscode_open_shortcuts

_G.vscode_menu_search = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      M.open_search()
    end)
  end
end

_G.vscode_toggle_ai = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      local ok, ai = pcall(require, "ide_ai_sidebar")
      if ok and ai.toggle then
        ai.toggle()
      end
    end)
  end
end

_G.vscode_run_select = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      local ok, rh = pcall(require, "run_history")
      if ok then
        rh.open_select_menu()
      end
    end)
  end
end

_G.vscode_run_execute = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      local ok, rh = pcall(require, "run_history")
      if ok then
        rh.run()
      end
    end)
  end
end

_G.vscode_run_stop = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      local ok, rh = pcall(require, "run_history")
      if ok then
        rh.stop()
      end
    end)
  end
end

_G.vscode_explorer_new_file = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      local ok, api = pcall(require, "nvim-tree.api")
      if ok then
        api.fs.create()
      end
    end)
  end
end

_G.vscode_explorer_new_folder = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      local ok, api = pcall(require, "nvim-tree.api")
      if not ok then
        return
      end

      local core_ok, core = pcall(require, "nvim-tree.core")
      local explorer = core_ok and core.get_explorer()
      local node = api.tree.get_node_under_cursor() or explorer

      local base_dir = nil
      if node then
        local ok_f, FileNode = pcall(require, "nvim-tree.node.file")
        local ok_d, DirectoryNode = pcall(require, "nvim-tree.node.directory")
        if ok_f and ok_d then
          local dir = nil
          if node.is and node:is(FileNode) then
            dir = node.parent
          elseif node.as and node:as(DirectoryNode) then
            dir = node:as(DirectoryNode)
          end
          if dir and dir.last_group_node then
            dir = dir:last_group_node()
          end
          if dir and dir.absolute_path then
            base_dir = dir.absolute_path
          end
        end
      end

      if not base_dir then
        base_dir = (explorer and explorer.absolute_path) or vim.fn.getcwd()
      end

      vim.ui.input({
        prompt = "New Folder: ",
        completion = "dir",
      }, function(input)
        if not input or vim.trim(input) == "" then
          return
        end

        local folder_name = vim.trim(input)
        local target_path
        if folder_name:sub(1, 1) == "/" or folder_name:match("^%a:[/\\]") then
          target_path = folder_name
        else
          target_path = base_dir .. "/" .. folder_name
        end

        target_path = target_path:gsub("/+$", "")

        local mkdir_ok, err = pcall(vim.fn.mkdir, target_path, "p")
        if not mkdir_ok or vim.fn.isdirectory(target_path) == 0 then
          vim.notify("Failed to create folder: " .. (err or target_path), vim.log.levels.ERROR)
          return
        end

        api.tree.reload()
        pcall(api.tree.find_file, target_path)
      end)
    end)
  end
end

_G.vscode_explorer_refresh = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      local ok, api = pcall(require, "nvim-tree.api")
      if ok then
        api.tree.reload()
      end
    end)
  end
end

_G.vscode_explorer_collapse = function(_, _, button)
  if button == "l" then
    vim.schedule(function()
      local ok, api = pcall(require, "nvim-tree.api")
      if ok then
        api.tree.collapse_all()
      end
    end)
  end
end

local menus = {
  File = {
    {
      label = "󰈔  New File",
      desc = "Open a clean empty buffer",
      action = function()
        vim.cmd("enew")
      end,
    },
    {
      label = "󰈞  Open File...",
      desc = "Open an existing file via native file dialog",
      action = function()
        require("workspace_manager").open_file_dialog()
      end,
    },
    {
      label = "󰉋  Open Folder / Change Project...",
      desc = "Switch active workspace, tree root, and cwd",
      action = function()
        require("workspace_manager").open_folder_dialog()
      end,
    },
    {
      label = "󰆓  Save File",
      desc = "Write current buffer to disk",
      action = function()
        vim.cmd("silent! write")
      end,
    },
    {
      label = "󰅖  Close Window",
      desc = "Close active window split",
      action = function()
        vim.cmd("close")
      end,
    },
    {
      label = "󰈆  Exit Neovim",
      desc = "Prompt and exit all windows",
      action = function()
        vim.cmd("confirm qa")
      end,
    },
  },

  Edit = {
    {
      label = "󰍉  Find in File",
      desc = "Open floating search input in current buffer",
      action = function()
        if _G.open_floating_search then
          _G.open_floating_search()
        else
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-f>", true, false, true), "m", false)
        end
      end,
    },
    {
      label = "󰈞  Find across Project (Live Grep)",
      desc = "Search string in entire project via Telescope",
      action = function()
        local ok, builtin = pcall(require, "telescope.builtin")
        if ok then
          builtin.live_grep()
        else
          vim.cmd("Telescope live_grep")
        end
      end,
    },
    {
      label = "󰑕  Rename Symbol",
      desc = "Rename symbol under cursor using LSP",
      action = function()
        vim.lsp.buf.rename()
      end,
    },
    {
      label = "󰌵  Code Action",
      desc = "Show available LSP code actions and quickfixes",
      action = function()
        vim.lsp.buf.code_action()
      end,
    },
  },

  Run = {
    {
      label = "󱁤  Run Configurations & History...",
      desc = "Select active configuration or runnable classes",
      action = function()
        local ok, rh = pcall(require, "run_history")
        if ok then
          rh.open_select_menu()
        end
      end,
    },
    {
      label = "󰐊  Run Program / Query",
      desc = "Execute active configuration or focused file",
      action = function()
        local ok, rh = pcall(require, "run_history")
        if ok and rh.run then
          rh.run()
        elseif _G.statusline_run_execute then
          _G.statusline_run_execute(nil, nil, "l")
        end
      end,
    },
    {
      label = "󰓛  Stop Running Process",
      desc = "Terminate active runner terminal session",
      action = function()
        local ok, rh = pcall(require, "run_history")
        if ok and rh.stop then
          rh.stop()
        elseif _G.statusline_run_stop then
          _G.statusline_run_stop(nil, nil, "l")
        end
      end,
    },
    {
      label = "󰃤  Debug (DAP Continue)",
      desc = "Launch or continue debug session",
      action = function()
        local ok, dap = pcall(require, "dap")
        if ok and dap.continue then
          dap.continue()
        else
          vim.notify("nvim-dap is not configured for this buffer.", vim.log.levels.WARN)
        end
      end,
    },
  },

  Terminal = {
    {
      label = "󰞌  Toggle Stacked Terminal",
      desc = "Open or hide bottom terminal panel",
      action = function()
        local ok, ide_term = pcall(require, "ide_term")
        if ok then
          ide_term.toggle()
        end
      end,
    },
    {
      label = "󰐕  New Terminal Tab",
      desc = "Create a new terminal tab in stacked panel",
      action = function()
        local ok, ide_term = pcall(require, "ide_term")
        if ok then
          ide_term.new()
        end
      end,
    },
    {
      label = "󰚩  Toggle Antigravity AI Sidebar",
      desc = "Open or hide right AI terminal panel",
      action = function()
        local ok, ai = pcall(require, "ide_ai_sidebar")
        if ok and ai.toggle then
          ai.toggle()
        end
      end,
    },
  },

  Help = {
    {
      label = "󰌌  Keyboard Shortcuts & Keymaps",
      desc = "View full keymap reference and shortcuts",
      action = function()
        if _G.vscode_open_shortcuts then
          _G.vscode_open_shortcuts()
        end
      end,
    },
  },
}

function M.open_menu(name)
  local items = menus[name]
  if not items then
    return
  end

  vim.ui.select(items, {
    prompt = " 󰘳 " .. name .. " Menu: ",
    format_item = function(item)
      return item.label .. (item.desc and ("  —  " .. item.desc) or "")
    end,
  }, function(choice)
    if choice and choice.action then
      choice.action()
    end
  end)
end

function M.open_search()
  local ok, builtin = pcall(require, "telescope.builtin")
  if ok then
    builtin.find_files({
      prompt_title = "  Quick Open (VS Code Global Search) ",
    })
  else
    vim.notify("Telescope is not installed or available.", vim.log.levels.WARN)
  end
end

function M.open_folder_dialog()
  require("workspace_manager").open_folder_dialog()
end

function M.open_file_dialog()
  require("workspace_manager").open_file_dialog()
end

local function render_run_widget(cols)
  local ok_rh, rh = pcall(require, "run_history")
  if not ok_rh then
    return ""
  end

  local pill_info = (rh.get_header_pill_info and rh.get_header_pill_info(cols))
    or { icon = "󰐊", label = rh.get_current_config() or "Main" }
  local is_running = rh.is_running()

  local max_len = 16
  if cols < 95 then
    max_len = 8
  elseif cols < 115 then
    max_len = 12
  end

  local display_label = pill_info.label
  if #display_label > max_len then
    display_label = display_label:sub(1, max_len - 1) .. "…"
  end

  local pill_content
  if cols < 75 then
    pill_content = "%#VSCodeHeaderRunIcon# " .. pill_info.icon .. "%#VSCodeHeaderRunArrow#▾"
  else
    pill_content = "%#VSCodeHeaderRunIcon# " .. pill_info.icon .. " %#VSCodeHeaderRunName#" .. display_label .. " %#VSCodeHeaderRunArrow#▾"
  end

  local pill = "%@v:lua.vscode_run_select@%#VSCodeHeaderRunBorder#["
    .. pill_content
    .. "%#VSCodeHeaderRunBorder#]%#VSCodeHeaderFill#%X"

  local run_btn_hl = is_running and "VSCodeHeaderRunBtnActive" or "VSCodeHeaderRunBtn"
  local run_btn_icon = is_running and "󰑐" or "󰐊"
  local run_btn = "%@v:lua.vscode_run_execute@%#VSCodeHeaderRunBorder#[%#"
    .. run_btn_hl
    .. "# "
    .. run_btn_icon
    .. " %#VSCodeHeaderRunBorder#]%#VSCodeHeaderFill#%X"

  local stop_btn_hl = is_running and "VSCodeHeaderStopBtn" or "VSCodeHeaderStopBtnIdle"
  local stop_btn = "%@v:lua.vscode_run_stop@%#VSCodeHeaderRunBorder#[%#"
    .. stop_btn_hl
    .. "# ⏹ %#VSCodeHeaderRunBorder#]%#VSCodeHeaderFill#%X"

  return pill .. " " .. run_btn .. " " .. stop_btn
end

function M.render()
  local cols = vim.o.columns

  local menus_str = "%#VSCodeHeaderFill#"
    .. "%@v:lua.vscode_menu_file@%#VSCodeHeaderMenu# File %X"
    .. "%@v:lua.vscode_menu_edit@%#VSCodeHeaderMenu# Edit %X"
    .. "%@v:lua.vscode_menu_run@%#VSCodeHeaderMenu# Run %X"
    .. "%@v:lua.vscode_menu_terminal@%#VSCodeHeaderMenu# Terminal %X"
    .. "%@v:lua.vscode_menu_help@%#VSCodeHeaderMenu# Help %X"

  local cwd = vim.fn.getcwd()
  local root = vim.fs.root(cwd, { ".git", "pom.xml", "package.json", "build.gradle" }) or cwd
  local project_name = vim.fn.fnamemodify(root, ":t")
  if project_name == "" or project_name == "/" then
    project_name = "Workspace"
  end

  local search_str
  if cols < 85 then
    search_str = "%@v:lua.vscode_menu_search@%#VSCodeHeaderSearchBorder#[%#VSCodeHeaderSearch#  "
      .. project_name
      .. " %#VSCodeHeaderSearchBorder#]%#VSCodeHeaderFill#%X"
  elseif cols < 115 then
    search_str = "%@v:lua.vscode_menu_search@%#VSCodeHeaderSearchBorder# [%#VSCodeHeaderSearch# 󰘳 "
      .. project_name
      .. " /  Search %#VSCodeHeaderSearchBorder#]%#VSCodeHeaderFill#%X"
  else
    search_str = "%@v:lua.vscode_menu_search@%#VSCodeHeaderSearchBorder# [%#VSCodeHeaderSearch# %#VSCodeHeaderProject#󰘳 "
      .. project_name
      .. " %#VSCodeHeaderSearch#/  Search files... %#VSCodeHeaderKey#(^P) %#VSCodeHeaderSearchBorder#]%#VSCodeHeaderFill#%X"
  end

  local run_widget = render_run_widget(cols)
  local is_ai_open = false
  local ok_ai, ai = pcall(require, "ide_ai_sidebar")
  if ok_ai and ai.is_open and ai.is_open() then
    is_ai_open = true
  end
  local ai_hl = is_ai_open and "VSCodeHeaderAIBtnActive" or "VSCodeHeaderAIBtn"
  local ai_btn = "%@v:lua.vscode_toggle_ai@%#" .. ai_hl .. "# 󰚩 AI %X "
  local toggle_theme = "%@TbToggle_theme@%#TbThemeToggleBtn#   %X"
  local close_all = "%@TbCloseAllBufs@%#TbCloseAllBufsBtn# 󰅖 %X"
  local right_str = "%#VSCodeHeaderFill#" .. (run_widget ~= "" and (run_widget .. "  ") or "") .. ai_btn .. toggle_theme .. close_all .. " "

  return menus_str .. "%=" .. search_str .. "%=" .. right_str
end

function M.render_winbar()
  local win = vim.g.statusline_winid or api.nvim_get_current_win()
  if not win or not api.nvim_win_is_valid(win) then
    return ""
  end

  local cfg = api.nvim_win_get_config(win)
  if cfg.relative and cfg.relative ~= "" then
    return ""
  end

  local buf = api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype
  local bt = vim.bo[buf].buftype
  local name = api.nvim_buf_get_name(buf)
  local fname = vim.fn.fnamemodify(name, ":t")

  if ft == "NvimTree" or fname:match("^NvimTree_") or name:match("NvimTree_") then
    local new_file = "%@v:lua.vscode_explorer_new_file@  %X"
    local new_folder = "%@v:lua.vscode_explorer_new_folder@  %X"
    local refresh = "%@v:lua.vscode_explorer_refresh@  %X"
    local collapse = "%@v:lua.vscode_explorer_collapse@  %X "
    return "%#VSCodeExplorerHeader#  EXPLORER%#VSCodeExplorerHeader#%="
      .. "%#VSCodeExplorerAction#"
      .. new_file
      .. new_folder
      .. refresh
      .. collapse
  end

  if ft == "ide_ai_sidebar" then
    local ok_ai, ai = pcall(require, "ide_ai_sidebar")
    if ok_ai and ai.render_winbar then
      return ai.render_winbar()
    end
  end

  if ft == "qf" or bt == "quickfix" then
    return "%#TabLine#  Problems & Diagnostics %=%@v:lua.close_diagnostic_window@ %#TabLine#  Close %X "
  end

  if bt == "terminal" or ft == "ide_db" or ft == "help" or bt == "prompt" or bt ~= "" then
    return ""
  end

  local ok_utils, utils = pcall(require, "nvchad.tabufline.utils")
  if not ok_utils or not utils.style_buf then
    return ""
  end

  local bufs = sanitize_tab_bufs()
  if #bufs == 0 then
    local cur = api.nvim_get_current_buf()
    if is_valid_editor_buf(cur) then
      bufs = { cur }
      vim.t.bufs = bufs
    end
  end

  if #bufs == 0 then
    return "%#TbFill#%="
  end

  local win_width = api.nvim_win_get_width(win)
  local cur = api.nvim_get_current_buf()
  local tab_width = 18

  local max_tabs = math.max(1, math.floor((win_width - 2) / tab_width))
  local visible_tabs = {}
  local has_current = false

  for i, nr in ipairs(bufs) do
    if #visible_tabs + 1 > max_tabs then
      if has_current then
        break
      end
      table.remove(visible_tabs, 1)
    end
    has_current = (cur == nr) or has_current
    table.insert(visible_tabs, utils.style_buf(nr, i, tab_width))
  end

  return table.concat(visible_tabs) .. "%#TbFill#%="
end

vim.o.winbar = "%!v:lua.require('vscode_header').render_winbar()"

return M
