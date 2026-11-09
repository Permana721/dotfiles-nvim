local M = {}

_G.diagnostic_click = function(_, _, button)
  if button == "l" then
    vim.diagnostic.setloclist()
    vim.cmd("lopen")
  end
end

local last_diag_time = 0
local seen_diag_on_line = {}
local diag_count_on_line = {}

local function format_diagnostic(diagnostic)
  local now = vim.uv.hrtime()

  if now - last_diag_time > 50000000 then
    seen_diag_on_line = {}
    diag_count_on_line = {}
  end
  last_diag_time = now

  local lnum = diagnostic.lnum or 0
  local raw_msg = diagnostic.message or ""
  local clean_msg = raw_msg:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

  local key = string.format("%d:%s", lnum, clean_msg)
  if seen_diag_on_line[key] then
    return nil
  end
  seen_diag_on_line[key] = true

  diag_count_on_line[lnum] = (diag_count_on_line[lnum] or 0) + 1
  if diag_count_on_line[lnum] > 3 then
    return nil
  end

  local msg = clean_msg
  if #msg > 80 then
    msg = msg:sub(1, 77) .. "..."
  end

  return msg
end

local function setup_diagnostic_config()
  local x = vim.diagnostic.severity
  vim.diagnostic.config({
    severity_sort = true,
    signs = { text = { [x.ERROR] = "󰅙", [x.WARN] = "", [x.INFO] = "󰋼", [x.HINT] = "󰌵" } },
    underline = true,
    float = { border = "single" },
    virtual_text = {
      prefix = "■",
      spacing = 2,
      severity_sort = true,
      format = format_diagnostic,
    },
  })
end

local ok_lsp, nv_lsp = pcall(require, "nvchad.lsp")
if ok_lsp then
  nv_lsp.diagnostic_config = setup_diagnostic_config
end
setup_diagnostic_config()

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function()
    setup_diagnostic_config()
  end,
})

_G.open_wakatime_dashboard = function(_, _, button)
  if button == "l" then
    vim.ui.open("http://192.168.0.182:3000")
  end
end

local wakatime_today = "Loading..."
local api_url = "http://192.168.0.182:3000/api/compat/wakatime/v1/users/current/summaries?range=today"

local key_path = vim.fn.stdpath("config") .. "/wakapi.key"
local ok, key_lines = pcall(vim.fn.readfile, key_path)
local api_key = ok and key_lines[1] or nil

local request_running = false
local last_request = 0

local function update_wakatime()
  local now = os.time()

  if request_running or now - last_request < 60 then
    return
  end

  if not api_key or api_key == "" then
    wakatime_today = "API key missing"
    vim.cmd("redrawstatus")
    return
  end

  request_running = true
  last_request = now

  local encoded_key = vim.fn.system({ "base64", "-w", "0" }, api_key)
  if vim.v.shell_error ~= 0 then
    request_running = false
    wakatime_today = "Base64 encoding failure"
    vim.cmd("redrawstatus")
    return
  end

  encoded_key = vim.trim(encoded_key)

  vim.system({
    "curl",
    "-fsS",
    "--max-time", "5",
    "-H", "Authorization: Basic " .. encoded_key,
    api_url,
  }, { text = true }, function(response)
    local new_status

    if response.code ~= 0 then
      new_status = "API error"
      local err = vim.trim(response.stderr or "")
      if err ~= "" then
        vim.schedule(function()
          vim.notify("Wakapi request failed: " .. err, vim.log.levels.WARN)
        end)
      end
    else
      local success, data = pcall(vim.json.decode, response.stdout or "")
      if not success then
        new_status = "Invalid JSON response"
      else
        local summary = data.data and data.data[1]
        local total = summary and summary.grand_total and summary.grand_total.text

        if type(total) == "string" and total ~= "" then
          new_status = total
        else
          new_status = "No activity recorded"
        end
      end
    end

    vim.schedule(function()
      request_running = false
      wakatime_today = new_status
      vim.cmd("redrawstatus")
    end)
  end)
end

local runner_script = vim.fn.stdpath("cache") .. "/fast_java_run.sh"
vim.fn.writefile({
  "#!/usr/bin/env bash",
  "set -e",
  'MAIN_CLASS="$1"',
  "if [ -f pom.xml ]; then",
  "  mkdir -p target/classes",
  "  if [ ! -f target/.cp ] || [ pom.xml -nt target/.cp ]; then",
  '    echo "Building Maven classpath cache..."',
  "    mvn dependency:build-classpath -Dmdep.outputFile=target/.cp -q",
  "  fi",
  '  DEPS="$(cat target/.cp 2>/dev/null || true)"',
  '  CP="target/classes${DEPS:+:$DEPS}"',
  "  if [ -d src/main/resources ]; then",
  "    cp -ru src/main/resources/* target/classes/ 2>/dev/null || true",
  "  fi",
  '  if [ ! -f target/.last_build ] || [ -n "$(find src/main/java -name \'*.java\' -newer target/.last_build 2>/dev/null)" ]; then',
  '    find src/main/java -name "*.java" > target/.sources',
  '    javac -encoding UTF-8 -cp "$CP" -d target/classes @target/.sources',
  "    touch target/.last_build",
  "  fi",
  '  exec java -cp "$CP" "$MAIN_CLASS"',
  "else",
  "  mkdir -p out",
  '  find . -name "*.java" > out/.sources',
  '  javac -encoding UTF-8 -d out @out/.sources',
  '  exec java -cp out "$MAIN_CLASS"',
  "fi",
}, runner_script)
vim.fn.setfperm(runner_script, "rwxr-xr-x")

local function get_runnable_class()
  if vim.bo.filetype ~= "java" then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local has_main = false
  local package_name = nil

  for _, line in ipairs(lines) do
    if not package_name then
      local pkg = line:match("^%s*package%s+([%w_%.]+)%s*;")
      if pkg then
        package_name = pkg
      end
    end

    if line:match("static%s+void%s+main%s*%(") or line:match("void%s+main%s*%(") then
      has_main = true
    end
  end

  if not has_main then
    return nil
  end

  local class_name = vim.fn.expand("%:t:r")
  return package_name and (package_name .. "." .. class_name) or class_name
end

_G.statusline_run_execute = function(_, _, button)
  if button ~= "l" then
    return
  end

  local ok, rh = pcall(require, "run_history")
  if ok and rh.run then
    rh.run()
  end
end

_G.statusline_run_stop = function(_, _, button)
  if button ~= "l" then
    return
  end

  local ok, rh = pcall(require, "run_history")
  if ok and rh.stop then
    rh.stop()
  end
end

_G.java_run = _G.statusline_run_execute
_G.java_stop = _G.statusline_run_stop

vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "CursorHold" }, {
  callback = update_wakatime,
})

vim.api.nvim_create_autocmd("TermClose", {
  callback = function()
    vim.schedule(function()
      vim.cmd("redrawstatus")
    end)
  end,
})

vim.api.nvim_set_hl(0, "StatusLineStop", { fg = "#e06c75", bold = true, default = true })

local git_and_error_highlights = {

  NvimTreeGitDirty = { fg = "#e5c07b" },
  NvimTreeGitDirtyIcon = { fg = "#e5c07b" },
  NvimTreeFileDirty = { fg = "#e5c07b" },
  NvimTreeGitFileDirtyHL = { fg = "#e5c07b" },
  NvimTreeGitFolderDirtyHL = { fg = "#e5c07b" },
  NvimTreeFolderDirty = { fg = "#e5c07b" },
  GitSignsChange = { fg = "#e5c07b" },
  GitSignsChangeNr = { fg = "#e5c07b" },
  GitSignsChangeLn = { fg = "#e5c07b" },
  GitSignsChangedelete = { fg = "#e5c07b" },
  GitSignsChangedeleteNr = { fg = "#e5c07b" },
  GitSignsChangedeleteLn = { fg = "#e5c07b" },
  TbBufOnModified = { fg = "#e5c07b" },
  TbBufOffModified = { fg = "#e5c07b" },
  DiffChange = { fg = "#e5c07b" },
  DiffModified = { fg = "#e5c07b" },

  NvimTreeGitNew = { fg = "#98c379" },
  NvimTreeGitNewIcon = { fg = "#98c379" },
  NvimTreeFileNew = { fg = "#98c379" },
  NvimTreeGitFileNewHL = { fg = "#98c379" },
  NvimTreeGitFolderNewHL = { fg = "#98c379" },
  NvimTreeFolderNew = { fg = "#98c379" },
  GitSignsAdd = { fg = "#98c379" },
  GitSignsAddNr = { fg = "#98c379" },
  GitSignsAddLn = { fg = "#98c379" },
  GitSignsUntracked = { fg = "#98c379" },
  GitSignsUntrackedNr = { fg = "#98c379" },
  GitSignsUntrackedLn = { fg = "#98c379" },
  DiffAdd = { fg = "#98c379" },
  DiffAdded = { fg = "#98c379" },

  NvimTreeGitStaged = { fg = "#56b6c2" },
  NvimTreeGitStagedIcon = { fg = "#56b6c2" },
  NvimTreeFileStaged = { fg = "#56b6c2" },
  NvimTreeGitFileStagedHL = { fg = "#56b6c2" },
  NvimTreeGitFolderStagedHL = { fg = "#56b6c2" },
  NvimTreeFolderStaged = { fg = "#56b6c2" },

  NvimTreeGitDeleted = { fg = "#c678dd" },
  NvimTreeGitDeletedIcon = { fg = "#c678dd" },
  NvimTreeFileDeleted = { fg = "#c678dd" },
  NvimTreeGitFileDeletedHL = { fg = "#c678dd" },
  NvimTreeGitFolderDeletedHL = { fg = "#c678dd" },
  NvimTreeFolderDeleted = { fg = "#c678dd" },
  GitSignsDelete = { fg = "#c678dd" },
  GitSignsDeleteNr = { fg = "#c678dd" },
  GitSignsDeleteLn = { fg = "#c678dd" },
  GitSignsTopdelete = { fg = "#c678dd" },
  GitSignsTopdeleteNr = { fg = "#c678dd" },
  GitSignsTopdeleteLn = { fg = "#c678dd" },
  DiffDelete = { fg = "#c678dd" },
  DiffRemoved = { fg = "#c678dd" },
  DiffChangeDelete = { fg = "#c678dd" },

  NvimTreeGitRenamed = { fg = "#61afef" },
  NvimTreeGitRenamedIcon = { fg = "#61afef" },
  NvimTreeFileRenamed = { fg = "#61afef" },
  NvimTreeGitFileRenamedHL = { fg = "#61afef" },
  NvimTreeGitFolderRenamedHL = { fg = "#61afef" },
  NvimTreeFolderRenamed = { fg = "#61afef" },
  NvimTreeGitIgnored = { fg = "#5c6370" },
  NvimTreeGitIgnoredIcon = { fg = "#5c6370" },
  NvimTreeFileIgnored = { fg = "#5c6370" },
  NvimTreeGitFileIgnoredHL = { fg = "#5c6370" },
  NvimTreeGitFolderIgnoredHL = { fg = "#5c6370" },
  NvimTreeFolderIgnored = { fg = "#5c6370" },
  NvimTreeGitMerge = { fg = "#d19a66" },
  NvimTreeGitMergeIcon = { fg = "#d19a66" },
  NvimTreeFileMerge = { fg = "#d19a66" },
  NvimTreeGitFileMergeHL = { fg = "#d19a66" },
  NvimTreeGitFolderMergeHL = { fg = "#d19a66" },
  NvimTreeFolderMerge = { fg = "#d19a66" },
  NvimTreeRootFolder = { fg = "#61afef", bold = true },

  DiagnosticError = { fg = "#e06c75" },
  DiagnosticSignError = { fg = "#e06c75" },
  DiagnosticFloatingError = { fg = "#e06c75" },
  NvimTreeLspDiagnosticsError = { fg = "#e06c75" },
  NvimTreeDiagnosticErrorFileHL = { fg = "#e06c75" },
  NvimTreeDiagnosticErrorFolderHL = { fg = "#e06c75" },
  NvimTreeDiagnosticErrorIcon = { fg = "#e06c75" },
  NvimTreeLspDiagnosticsErrorText = { fg = "#e06c75" },
  NvimTreeLspDiagnosticsErrorFolderText = { fg = "#e06c75" },
  St_DiagnosticsError = { fg = "#e06c75" },
  StatusLineStop = { fg = "#e06c75", bold = true },
}

local function apply_git_and_error_highlights()
  for group, def in pairs(git_and_error_highlights) do
    vim.api.nvim_set_hl(0, group, def)
  end
end

apply_git_and_error_highlights()

vim.api.nvim_create_autocmd({ "ColorScheme", "User" }, {
  pattern = { "*", "NvThemeReload" },
  callback = apply_git_and_error_highlights,
})

M.base46 = {
  theme = "onedark",
  integrations = { "gitsigns" },
  hl_add = git_and_error_highlights,
  hl_override = vim.tbl_extend("force", git_and_error_highlights, {
    GitSignsCurrentLineBlame = { fg = "#5c6370", italic = true },

    VSCodeHeaderNormal = { fg = "#abb2bf", bg = "#1e222a" },
    VSCodeHeaderFill = { fg = "#abb2bf", bg = "#1e222a" },
    VSCodeHeaderMenu = { fg = "#abb2bf", bg = "#1e222a" },
    VSCodeHeaderMenuHover = { fg = "#ffffff", bg = "#282c34", bold = true },
    VSCodeHeaderSearch = { fg = "#abb2bf", bg = "#282c34" },
    VSCodeHeaderSearchBorder = { fg = "#3e4451", bg = "#1e222a" },
    VSCodeHeaderProject = { fg = "#98c379", bg = "#282c34", bold = true },
    VSCodeHeaderKey = { fg = "#5c6370", bg = "#282c34" },
    VSCodeExplorerHeader = { fg = "#abb2bf", bg = "#1e222a", bold = true },
    VSCodeExplorerAction = { fg = "#abb2bf", bg = "#1e222a" },

    VSCodeHeaderRunPill = { fg = "#abb2bf", bg = "#282c34" },
    VSCodeHeaderRunBorder = { fg = "#3e4451", bg = "#1e222a" },
    VSCodeHeaderRunIcon = { fg = "#98c379", bg = "#282c34" },
    VSCodeHeaderRunName = { fg = "#abb2bf", bg = "#282c34", bold = true },
    VSCodeHeaderRunArrow = { fg = "#5c6370", bg = "#282c34" },
    VSCodeHeaderRunBtn = { fg = "#98c379", bg = "#282c34", bold = true },
    VSCodeHeaderRunBtnActive = { fg = "#61afef", bg = "#282c34", bold = true },
    VSCodeHeaderStopBtn = { fg = "#e06c75", bg = "#282c34", bold = true },
    VSCodeHeaderStopBtnIdle = { fg = "#5c6370", bg = "#282c34" },
    StatusLineStop = { fg = "#e06c75", bold = true },
  }),
}

M.ui = {
  tabufline = {
    lazyload = false,
    order = { "header" },
    modules = {
      header = function()
        return require("vscode_header").render()
      end,
    },
  },

  statusline = {
    order = {
      "mode",
      "file",
      "git",
      "java_run",
      "java_stop",
      "wakatime",
      "%=",
      "lsp_msg",
      "%=",
      "diagnostics",
      "db_manager",
      "lsp",
      "cwd",
      "cursor",
    },

    modules = {
      java_run = function()
        local ok_rh, rh = pcall(require, "run_history")
        local is_running = ok_rh and rh.is_running and rh.is_running()
        if is_running then
          return ""
        end
        local runnable = ok_rh and rh.is_buffer_runnable and rh.is_buffer_runnable(0)
        if not runnable then
          return ""
        end
        return "%@v:lua.statusline_run_execute@%#St_gitIcons# Run %X"
      end,

      java_stop = function()
        local ok_rh, rh = pcall(require, "run_history")
        local is_running = ok_rh and rh.is_running and rh.is_running()
        if not is_running then
          return ""
        end
        return "%@v:lua.statusline_run_stop@%#StatusLineStop# ⏹ Stop %X"
      end,

      wakatime = function()
        return "%@v:lua.open_wakatime_dashboard@%#St_gitIcons#  " .. wakatime_today .. " %X"
      end,

      diagnostics = function()
        local errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
        local warns = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })

        if errors == 0 and warns == 0 then
          return "%@v:lua.diagnostic_click@%#St_DiagnosticsOk# 󰄬 %X"
        end

        local result = ""
        if errors > 0 then
          result = result .. "%#St_DiagnosticsError#  " .. errors .. " "
        end
        if warns > 0 then
          result = result .. "%#St_DiagnosticsWarn#  " .. warns .. " "
        end

        return "%@v:lua.diagnostic_click@" .. result .. "%X"
      end,

      db_manager = function()
        local ok_db, ide_db = pcall(require, "ide_db")
        if ok_db then
          return ide_db.statusline()
        end
        return ""
      end,
    },
  },
}

return M
