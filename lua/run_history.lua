local M = {}

M._cache = nil
local history_file = vim.fn.stdpath("data") .. "/run_history.json"

local RUNNABLE_FILETYPES = {
  java = true,
  c = true,
  cpp = true,
  python = true,
  javascript = true,
  typescript = true,
  sql = true,
  pgsql = true,
  mysql = true,
  sh = true,
  bash = true,
  lua = true,
  rust = true,
  go = true,
}

function M.get_lang_icon(lang)
  if not lang then return "󰐊" end
  lang = lang:lower()
  if lang == "java" then return ""
  elseif lang == "c" then return ""
  elseif lang == "cpp" then return ""
  elseif lang == "python" then return ""
  elseif lang == "javascript" or lang == "js" then return ""
  elseif lang == "typescript" or lang == "ts" then return ""
  elseif lang == "sql" or lang == "pgsql" or lang == "mysql" then return "󰆼"
  elseif lang == "sh" or lang == "bash" then return ""
  elseif lang == "lua" then return ""
  elseif lang == "rust" then return ""
  elseif lang == "go" then return ""
  end
  return "󰐊"
end

function M.parse_history_item(item)
  if type(item) == "table" then
    return item
  end
  if type(item) ~= "string" or item == "" then
    return nil
  end

  local ext = item:match("%.([%w_]+)$")
  local lang = "java"
  if ext == "c" then lang = "c"
  elseif ext == "cpp" or ext == "cc" or ext == "cxx" then lang = "cpp"
  elseif ext == "py" then lang = "python"
  elseif ext == "sql" or ext == "pgsql" or ext == "mysql" then lang = "sql"
  elseif ext == "js" or ext == "mjs" then lang = "javascript"
  elseif ext == "ts" then lang = "typescript"
  elseif ext == "sh" or ext == "bash" then lang = "sh"
  elseif ext == "lua" then lang = "lua"
  elseif ext == "rs" then lang = "rust"
  elseif ext == "go" then lang = "go"
  end

  return {
    name = item,
    lang = lang,
    target = item,
  }
end

function M.get_project_root()
  local cwd = vim.fn.getcwd()
  local cur_buf = vim.api.nvim_get_current_buf()
  local root = nil
  if vim.api.nvim_buf_is_valid(cur_buf) and vim.bo[cur_buf].buftype == "" then
    root = vim.fs.root(cur_buf, { "pom.xml", "build.gradle", ".git" })
  end
  if not root then
    local ok_wm, wm = pcall(require, "workspace_manager")
    if ok_wm and wm.find_project_root then
      root = wm.find_project_root(cwd)
    else
      root = vim.fs.root(cwd, { "pom.xml", "build.gradle", ".git" }) or cwd
    end
  end
  if not root or root == "" then
    root = cwd
  end
  return vim.fn.fnamemodify(root, ":p"):gsub("/+$", "")
end

function M.load()
  if M._cache then
    return M._cache
  end

  if vim.fn.filereadable(history_file) == 1 then
    local lines = vim.fn.readfile(history_file)
    if lines and #lines > 0 then
      local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
      if ok and type(decoded) == "table" then
        M._cache = decoded
        return M._cache
      end
    end
  end

  M._cache = {}
  return M._cache
end

function M.save()
  if not M._cache then
    return
  end
  local dir = vim.fn.fnamemodify(history_file, ":h")
  if vim.fn.isdirectory(dir) ~= 1 then
    pcall(vim.fn.mkdir, dir, "p")
  end
  local ok, encoded = pcall(vim.json.encode, M._cache)
  if ok and encoded then
    pcall(vim.fn.writefile, { encoded }, history_file)
  end
end

function M.get_current_entry(root)
  root = root or M.get_project_root()
  M.load()
  local proj = M._cache[root]
  if proj and proj.current then
    return M.parse_history_item(proj.current)
  end
  if proj and proj.history and #proj.history > 0 then
    return M.parse_history_item(proj.history[1])
  end
  return { name = "Main", lang = "java", target = "Main" }
end

function M.get_current_config(root)
  local entry = M.get_current_entry(root)
  return (entry and entry.name) or "Main"
end

function M.get_history(root)
  root = root or M.get_project_root()
  M.load()
  local proj = M._cache[root]
  return (proj and proj.history) or {}
end

function M.add_to_history(config, root)
  if not config then
    return
  end
  root = root or M.get_project_root()
  M.load()
  if not M._cache[root] then
    M._cache[root] = { current = config, history = {} }
  end

  local item = M.parse_history_item(config)
  if not item or not item.name or item.name == "" then
    return
  end

  local hist = M._cache[root].history or {}
  local new_hist = { item }
  for _, existing_raw in ipairs(hist) do
    local existing = M.parse_history_item(existing_raw)
    if existing and existing.name ~= item.name and #new_hist < 10 then
      table.insert(new_hist, existing)
    end
  end
  M._cache[root].history = new_hist
  M.save()
end

function M.set_current_config(config, root)
  if not config then
    return
  end
  root = root or M.get_project_root()
  M.load()
  if not M._cache[root] then
    M._cache[root] = { current = config, history = {} }
  end
  M._cache[root].current = config
  M.add_to_history(config, root)
  M.save()
  vim.cmd("redrawtabline")
  vim.cmd("redrawstatus")
end

function M.is_buffer_runnable(bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local bt = vim.bo[bufnr].buftype
  if bt ~= "" then
    return false
  end

  local ft = vim.bo[bufnr].filetype
  return RUNNABLE_FILETYPES[ft] == true
end

function M.get_buffer_runnable(bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  if vim.bo[bufnr].filetype ~= "java" then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local has_main = false
  local is_test = false
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

    if line:match("@Test") or line:match("@ParameterizedTest") then
      is_test = true
    end
  end

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local class_name = vim.fn.fnamemodify(bufname, ":t:r")
  if not has_main and not is_test then
    if class_name:match("Test$") or class_name:match("Tests$") then
      is_test = true
    else
      return nil
    end
  end

  local fqcn = package_name and (package_name .. "." .. class_name) or class_name
  return fqcn, is_test
end

function M.get_header_pill_info(cols)
  cols = cols or vim.o.columns
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_ft = vim.bo[cur_buf].filetype
  local cur_bt = vim.bo[cur_buf].buftype
  local cur_path = vim.api.nvim_buf_get_name(cur_buf)

  if cur_bt == "" then
    if cur_ft == "sql" or cur_ft == "pgsql" or cur_ft == "mysql" then
      return { icon = "󰆼", label = "Execute SQL", lang = "SQL" }
    elseif cur_ft == "c" or cur_ft == "cpp" then
      return { icon = "", label = "Run C/C++", lang = "C/C++" }
    elseif cur_ft == "javascript" or cur_ft == "typescript" then
      return { icon = "", label = "Run JS/TS", lang = "JS/TS" }
    elseif cur_ft == "python" then
      return { icon = "", label = "Run Python", lang = "Python" }
    elseif cur_ft == "sh" or cur_ft == "bash" then
      return { icon = "", label = "Run Shell", lang = "Shell" }
    elseif cur_ft == "lua" then
      return { icon = "", label = "Run Lua", lang = "Lua" }
    elseif cur_ft == "rust" then
      return { icon = "", label = "Run Rust", lang = "Rust" }
    elseif cur_ft == "go" then
      return { icon = "", label = "Run Go", lang = "Go" }
    elseif cur_ft == "java" then
      local fqcn = M.get_buffer_runnable(cur_buf)
      local name = fqcn and (fqcn:match("([^%.]+)$") or fqcn) or M.get_current_config()
      if not name or name == "" then name = "Main" end
      return { icon = "󰐊", label = name, lang = "Java" }
    end
  end

  local root = M.get_project_root()
  local entry = M.get_current_entry(root)
  if entry and entry.lang and entry.lang ~= "java" then
    local icon = M.get_lang_icon(entry.lang)
    local short = entry.name:match("([^%.]+)$") or entry.name
    return { icon = icon, label = short, lang = entry.lang:upper() }
  end

  local cur_config = M.get_current_config(root)
  local short_name = cur_config:match("([^%.]+)$") or cur_config
  if short_name == "" then
    short_name = "Main"
  end
  return { icon = "󰐊", label = short_name, lang = "Java" }
end

local function is_ide_db_connected()
  local ok, ide_db = pcall(require, "ide_db")
  if not ok then return false, nil end
  if not ide_db.execute_query and ide_db.execute_sql then
    ide_db.execute_query = ide_db.execute_sql
  end
  local info = debug.getinfo(ide_db.execute_sql or ide_db.open_menu)
  if info and info.nups then
    for i = 1, info.nups do
      local name, val = debug.getupvalue(ide_db.execute_sql or ide_db.open_menu, i)
      if name == "state" and val and val.active_conn then
        return true, ide_db, val
      end
    end
  end
  return false, ide_db, nil
end

function M.get_runner_script()
  local runner_script = vim.fn.stdpath("cache") .. "/fast_java_run.sh"
  if vim.fn.filereadable(runner_script) == 0 then
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
  end
  return runner_script
end

function M.is_running()
  local S = _G._ide_term_state
  if S and S.terminals then
    for _, t in ipairs(S.terminals) do
      if t.is_runner and t.job ~= nil then
        return true
      end
    end
  end
  local ok, ide_term = pcall(require, "ide_term")
  if ok and ide_term.is_java_running then
    return ide_term.is_java_running()
  end
  return false
end

function M.run_in_term(cmd, title, cwd)
  local ok, ide_term = pcall(require, "ide_term")
  if not ok then
    vim.notify("ide_term module is not available.", vim.log.levels.ERROR)
    return
  end

  local S = _G._ide_term_state
  if not S then
    vim.notify("Terminal state is not initialized.", vim.log.levels.ERROR)
    return
  end

  for i = #S.terminals, 1, -1 do
    if not vim.api.nvim_buf_is_valid(S.terminals[i].buf) then
      table.remove(S.terminals, i)
    end
  end
  if S.active_idx > #S.terminals then
    S.active_idx = math.max(1, #S.terminals)
  end

  ide_term.open_window()

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

  local entry = {
    buf = buf,
    id = 0,
    title = title or "Runner",
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

  local job_cmd = type(cmd) == "table" and cmd or { "bash", "-c", cmd }
  entry.job = vim.fn.jobstart(job_cmd, {
    cwd = cwd or vim.fn.getcwd(),
    term = true,
    on_exit = function()
      entry.job = nil
      vim.schedule(function()
        vim.cmd("redrawstatus")
        vim.cmd("redrawtabline")
      end)
    end,
  })

  vim.bo[buf].buflisted = false

  if S.term_win and vim.api.nvim_win_is_valid(S.term_win) then
    local parts = {}
    for i, t in ipairs(S.terminals) do
      _G["ide_term_tab_" .. i] = function(_, _, button)
        if button == "l" then
          ide_term.select(i)
        elseif button == "m" then
          ide_term.kill(i)
        end
      end
      _G["ide_term_close_" .. i] = function(_, _, button)
        if button == "l" then
          ide_term.kill(i)
        end
      end
      local hl = (i == S.active_idx) and "%#TabLineSel#" or "%#TabLine#"
      local t_title = t.title or ("Terminal " .. t.id)
      parts[#parts + 1] = "%@v:lua.ide_term_tab_" .. i .. "@" .. hl .. " " .. t_title .. " %X"
        .. "%@v:lua.ide_term_close_" .. i .. "@" .. hl .. "x %X"
    end
    parts[#parts + 1] = "%#TabLineFill#%="
    parts[#parts + 1] = "%@v:lua.ide_term_new@%#TabLine# + New %X "
    parts[#parts + 1] = "%@v:lua.ide_term_hide@%#TabLine# _ Hide %X"
    vim.wo[S.term_win].winbar = table.concat(parts)
  end

  vim.cmd("startinsert")
  vim.cmd("redrawstatus")
  vim.cmd("redrawtabline")
end

function M.prompt_sql_execution(filepath, ft, root)
  local basename = vim.fn.fnamemodify(filepath, ":t")
  vim.ui.select({
    {
      id = "connect",
      label = "󰆼 Connect Database (Open Database Tool Window)...",
      action = function()
        local ok_db, db = pcall(require, "ide_db")
        if ok_db and db.open_menu then
          db.open_menu()
        end
      end,
    },
    {
      id = "cli",
      label = "  Run Query via CLI in Terminal",
      action = function()
        if not filepath or filepath == "" then
          vim.notify("Please save the SQL file first to execute via CLI.", vim.log.levels.WARN)
          return
        end
        local cmd
        if ft == "pgsql" then
          cmd = string.format('psql -f "%s"', filepath)
        elseif ft == "mysql" then
          cmd = string.format('mysql < "%s"', filepath)
        elseif vim.fn.executable("sqlite3") == 1 then
          cmd = string.format('sqlite3 < "%s"', filepath)
        else
          cmd = string.format('echo "Executing %s:" && cat "%s"', basename, filepath)
        end
        M.run_in_term(cmd, "Run SQL: " .. basename, root)
        M.add_to_history({ name = basename, lang = "sql", path = filepath }, root)
      end,
    },
  }, {
    prompt = "No active database connection: ",
    format_item = function(item) return item.label end,
  }, function(choice)
    if choice and choice.action then
      choice.action()
    end
  end)
end

function M.run_file(filepath, ft, root)
  root = root or M.get_project_root()
  ft = ft or vim.filetype.match({ filename = filepath }) or ""
  local basename = vim.fn.fnamemodify(filepath, ":t:r")
  local filename = vim.fn.fnamemodify(filepath, ":t")

  if ft == "sql" or ft == "pgsql" or ft == "mysql" then
    local connected, ide_db = is_ide_db_connected()
    if connected then
      if ide_db.run_current_sql then
        ide_db.run_current_sql()
      elseif ide_db.execute_sql then
        local lines = vim.fn.readfile(filepath)
        ide_db.execute_sql(table.concat(lines, "\n"))
      end
      M.add_to_history({ name = filename, lang = "sql", path = filepath }, root)
      return
    else
      M.prompt_sql_execution(filepath, ft, root)
      return
    end
  elseif ft == "c" then
    local cache_dir = vim.fn.stdpath("cache") .. "/bin"
    if vim.fn.isdirectory(cache_dir) ~= 1 then
      pcall(vim.fn.mkdir, cache_dir, "p")
    end
    local bin = cache_dir .. "/" .. basename
    local cmd = string.format('gcc -O2 -Wall "%s" -o "%s" && "%s"', filepath, bin, bin)
    M.run_in_term(cmd, "Run: " .. basename, root)
    M.add_to_history({ name = filename, lang = "c", path = filepath }, root)
  elseif ft == "cpp" then
    local cache_dir = vim.fn.stdpath("cache") .. "/bin"
    if vim.fn.isdirectory(cache_dir) ~= 1 then
      pcall(vim.fn.mkdir, cache_dir, "p")
    end
    local bin = cache_dir .. "/" .. basename
    local cmd = string.format('g++ -O2 -Wall -std=c++20 "%s" -o "%s" && "%s"', filepath, bin, bin)
    M.run_in_term(cmd, "Run: " .. basename, root)
    M.add_to_history({ name = filename, lang = "cpp", path = filepath }, root)
  elseif ft == "javascript" or ft == "typescript" then
    local cmd
    local has_bun = (vim.fn.executable("bun") == 1)
    if ft == "typescript" then
      if has_bun then
        cmd = string.format('bun run "%s"', filepath)
      elseif vim.fn.executable("ts-node") == 1 then
        cmd = string.format('ts-node "%s"', filepath)
      else
        cmd = string.format('npx ts-node "%s"', filepath)
      end
    else
      if has_bun then
        cmd = string.format('bun run "%s"', filepath)
      else
        cmd = string.format('node "%s"', filepath)
      end
    end
    M.run_in_term(cmd, "Run: " .. basename, root)
    M.add_to_history({ name = filename, lang = ft, path = filepath }, root)
  elseif ft == "python" then
    local py = (vim.fn.executable("python3") == 1) and "python3" or "python"
    local cmd = string.format('%s "%s"', py, filepath)
    M.run_in_term(cmd, "Run: " .. basename, root)
    M.add_to_history({ name = filename, lang = "python", path = filepath }, root)
  elseif ft == "sh" or ft == "bash" then
    local cmd = string.format('bash "%s"', filepath)
    M.run_in_term(cmd, "Run: " .. basename, root)
    M.add_to_history({ name = filename, lang = "sh", path = filepath }, root)
  elseif ft == "lua" then
    local cmd = string.format('nvim -l "%s"', filepath)
    M.run_in_term(cmd, "Run: " .. basename, root)
    M.add_to_history({ name = filename, lang = "lua", path = filepath }, root)
  elseif ft == "java" then
    local class_name = basename
    local parsed = parse_java_file(filepath)
    if parsed and parsed.fqcn then
      class_name = parsed.fqcn
    end
    M.set_current_config(class_name, root)
    local runner_script = M.get_runner_script()
    local ok, ide_term = pcall(require, "ide_term")
    if ok and ide_term.run_java then
      ide_term.run_java(runner_script, class_name, root)
    end
  end
end

function M.run(target, root)
  root = root or M.get_project_root()
  vim.cmd("silent! write")

  if target then
    if type(target) == "table" and target.path and vim.fn.filereadable(target.path) == 1 then
      M.set_current_config(target, root)
      M.run_file(target.path, target.lang, root)
      return
    elseif type(target) == "string" and vim.fn.filereadable(target) == 1 then
      local ft = vim.filetype.match({ filename = target })
      M.set_current_config({ name = vim.fn.fnamemodify(target, ":t"), lang = ft, path = target }, root)
      M.run_file(target, ft, root)
      return
    elseif type(target) == "string" and (target:match("%.") or target:match("^[A-Z]")) then

      M.set_current_config(target, root)
      local runner_script = M.get_runner_script()
      local ok, ide_term = pcall(require, "ide_term")
      if ok and ide_term.run_java then
        ide_term.run_java(runner_script, target, root)
      else
        vim.notify("ide_term module is not available.", vim.log.levels.ERROR)
      end
      vim.cmd("redrawtabline")
      vim.cmd("redrawstatus")
      return
    end
  end

  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_ft = vim.bo[cur_buf].filetype
  local cur_bt = vim.bo[cur_buf].buftype
  local cur_path = vim.api.nvim_buf_get_name(cur_buf)
  local cur_basename = vim.fn.fnamemodify(cur_path, ":t:r")
  local cur_filename = vim.fn.fnamemodify(cur_path, ":t")

  if cur_bt == "" and RUNNABLE_FILETYPES[cur_ft] then
    if cur_ft == "sql" or cur_ft == "pgsql" or cur_ft == "mysql" then
      local connected, ide_db = is_ide_db_connected()
      if connected then
        if ide_db.run_current_sql then
          ide_db.run_current_sql()
        elseif ide_db.execute_sql then
          local lines = vim.api.nvim_buf_get_lines(cur_buf, 0, -1, false)
          ide_db.execute_sql(table.concat(lines, "\n"))
        end
        M.add_to_history({ name = cur_filename ~= "" and cur_filename or "SQL Console", lang = "sql", path = cur_path }, root)
        return
      else
        M.prompt_sql_execution(cur_path, cur_ft, root)
        return
      end
    elseif cur_ft == "java" then
      local target_class = M.get_buffer_runnable(cur_buf) or M.get_current_config(root)
      if not target_class or target_class == "" then
        vim.notify("No runnable Java class found in active buffer.", vim.log.levels.WARN)
        return
      end
      M.set_current_config(target_class, root)
      local runner_script = M.get_runner_script()
      local ok, ide_term = pcall(require, "ide_term")
      if ok and ide_term.run_java then
        ide_term.run_java(runner_script, target_class, root)
      else
        vim.notify("ide_term module is not available.", vim.log.levels.ERROR)
      end
      vim.cmd("redrawtabline")
      vim.cmd("redrawstatus")
      return
    else
      if cur_path == "" then
        vim.notify("Please save the file before executing.", vim.log.levels.WARN)
        return
      end
      M.run_file(cur_path, cur_ft, root)
      return
    end
  end

  local entry = M.get_current_entry(root)
  if entry and entry.path and vim.fn.filereadable(entry.path) == 1 then
    M.run_file(entry.path, entry.lang, root)
    return
  elseif entry and entry.name then
    local runner_script = M.get_runner_script()
    local ok, ide_term = pcall(require, "ide_term")
    if ok and ide_term.run_java then
      ide_term.run_java(runner_script, entry.name, root)
    end
    vim.cmd("redrawtabline")
    vim.cmd("redrawstatus")
    return
  end

  vim.notify("No active runnable file or configuration found.", vim.log.levels.WARN)
end

function M.stop()
  local S = _G._ide_term_state
  local stopped = false
  local ok, ide_term = pcall(require, "ide_term")

  if S and S.terminals then
    for i = #S.terminals, 1, -1 do
      local t = S.terminals[i]
      if t and t.is_runner then
        if ok and ide_term.kill then
          ide_term.kill(i)
          stopped = true
        end
      end
    end
  end

  if not stopped and ok and ide_term.stop_java then
    stopped = ide_term.stop_java()
  end

  if stopped then
    vim.notify("Process terminated successfully.", vim.log.levels.INFO)
  else
    vim.notify("No active runner process found.", vim.log.levels.WARN)
  end

  vim.cmd("redrawtabline")
  vim.cmd("redrawstatus")
  return stopped
end

local function parse_java_file(filepath)
  local f = io.open(filepath, "r")
  if not f then
    return nil
  end

  local package_name = nil
  local has_main = false
  local is_test = false
  local line_count = 0

  for line in f:lines() do
    line_count = line_count + 1
    if not package_name then
      local pkg = line:match("^%s*package%s+([%w_%.]+)%s*;")
      if pkg then
        package_name = pkg
      end
    end

    if line:match("static%s+void%s+main%s*%(") or line:match("void%s+main%s*%(") then
      has_main = true
    end

    if line:match("@Test") or line:match("@ParameterizedTest") then
      is_test = true
    end

    if line_count > 300 and (has_main or is_test) and package_name then
      break
    end
  end
  f:close()

  local class_name = vim.fn.fnamemodify(filepath, ":t:r")
  if not has_main and not is_test then
    if class_name:match("Test$") or class_name:match("Tests$") then
      is_test = true
    else
      return nil
    end
  end

  local fqcn = package_name and (package_name .. "." .. class_name) or class_name
  return {
    fqcn = fqcn,
    class_name = class_name,
    filepath = filepath,
    has_main = has_main,
    is_test = is_test,
  }
end

function M.find_runnable_classes(root)
  root = root or M.get_project_root()
  local results = {}
  local seen = {}

  local files = {}
  if vim.fn.executable("rg") == 1 then
    local cmd = {
      "rg",
      "-l",
      "-e", "void\\s+main\\s*\\(",
      "-e", "@Test",
      "-g", "*.java",
      "--hidden",
      "-g", "!.git",
      "-g", "!target",
      "-g", "!build",
      "-g", "!.idea",
      "-g", "!bin",
      root,
    }
    local out = vim.fn.systemlist(cmd)
    if vim.v.shell_error == 0 and out then
      files = out
    end
  end

  if #files == 0 then
    local find_cmd = {
      "find",
      root,
      "-maxdepth", "6",
      "-name", "*.java",
      "-not", "-path", "*/.*",
      "-not", "-path", "*/target/*",
      "-not", "-path", "*/build/*",
    }
    local out = vim.fn.systemlist(find_cmd)
    if vim.v.shell_error == 0 and out then
      files = out
    end
  end

  for _, file in ipairs(files) do
    if file and file ~= "" and vim.fn.filereadable(file) == 1 then
      local parsed = parse_java_file(file)
      if parsed and not seen[parsed.fqcn] then
        seen[parsed.fqcn] = true
        table.insert(results, parsed)
      end
    end
  end

  table.sort(results, function(a, b)
    if a.has_main and not b.has_main then
      return true
    elseif not a.has_main and b.has_main then
      return false
    end
    return a.fqcn < b.fqcn
  end)

  return results
end

function M.open_project_runnables_picker(root)
  root = root or M.get_project_root()
  local runnables = M.find_runnable_classes(root)
  if #runnables == 0 then
    vim.notify("No runnable Java classes or test suites found in project.", vim.log.levels.WARN)
    return
  end

  local rel_root = root:gsub("/+$", "")
  local items = {}
  for _, r in ipairs(runnables) do
    local icon = r.has_main and "󰐊" or "󰙨"
    local rel_path = r.filepath
    if rel_path:sub(1, #rel_root) == rel_root then
      rel_path = rel_path:sub(#rel_root + 2)
    end
    table.insert(items, {
      fqcn = r.fqcn,
      label = icon .. " " .. r.fqcn,
      desc = rel_path,
      action = function()
        M.set_current_config(r.fqcn, root)
        vim.notify("Active configuration set to: " .. r.fqcn, vim.log.levels.INFO)
      end,
    })
  end

  vim.ui.select(items, {
    prompt = " 󰐊 Select Runnable Class: ",
    format_item = function(item)
      return item.label .. (item.desc and ("  (" .. item.desc .. ")") or "")
    end,
  }, function(choice)
    if choice and choice.action then
      choice.action()
    end
  end)
end

function M.open_select_menu()
  local root = M.get_project_root()
  local cur_config = M.get_current_config(root)
  local history = M.get_history(root)
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_ft = vim.bo[cur_buf].filetype
  local cur_path = vim.api.nvim_buf_get_name(cur_buf)
  local cur_filename = vim.fn.fnamemodify(cur_path, ":t")

  local items = {}

  local pill_info = M.get_header_pill_info()
  table.insert(items, {
    type = "run_active",
    label = pill_info.icon .. " Run: " .. pill_info.label,
    desc = "Execute immediately (" .. pill_info.lang .. ")",
    action = function()
      M.run()
    end,
  })

  if M.is_buffer_runnable(cur_buf) and cur_filename ~= "" then
    local icon = M.get_lang_icon(cur_ft)
    table.insert(items, {
      type = "run_current",
      label = icon .. " Run Focused Buffer: " .. cur_filename,
      desc = "Execute focused " .. (cur_ft:upper()) .. " file",
      action = function()
        M.run()
      end,
    })
  end

  if #history > 0 then
    for _, raw_item in ipairs(history) do
      local item = M.parse_history_item(raw_item)
      if item then
        local is_active = (item.name == cur_config)
        local check = is_active and "✓ " or "  "
        local icon = M.get_lang_icon(item.lang)
        table.insert(items, {
          type = "history",
          config = item,
          label = check .. icon .. " " .. item.name,
          desc = is_active and "(Active Configuration)" or ("Select " .. (item.lang and item.lang:upper() or "Config") .. " as active"),
          action = function()
            M.set_current_config(item, root)
            vim.notify("Active configuration set to: " .. item.name, vim.log.levels.INFO)
          end,
        })
      end
    end
  end

  local proj_has_java = (vim.fn.glob(root .. "/**/*.java") ~= "") or (cur_ft == "java")
  if proj_has_java then
    table.insert(items, {
      type = "find_java",
      label = " Find Runnable Java Classes in Project...",
      desc = "Search project for main methods and tests",
      action = function()
        vim.schedule(function()
          M.open_project_runnables_picker(root)
        end)
      end,
    })
  end

  table.insert(items, {
    type = "open_db",
    label = "󰆼 Open Database Tool Window...",
    desc = "Manage connections, browse tables, and run queries",
    action = function()
      local ok_db, db = pcall(require, "ide_db")
      if ok_db and db.open_menu then
        db.open_menu()
      end
    end,
  })

  if M.is_running() then
    table.insert(items, {
      type = "stop",
      label = "⏹ Stop Running Process",
      desc = "Terminate active runner process",
      action = function()
        M.stop()
      end,
    })
  end

  local proj_name = vim.fn.fnamemodify(root, ":t")
  if proj_name == "" or proj_name == "/" then
    proj_name = "Workspace"
  end

  vim.ui.select(items, {
    prompt = " 󰐊 Run Configurations (" .. proj_name .. "): ",
    format_item = function(item)
      return item.label .. (item.desc and ("  —  " .. item.desc) or "")
    end,
  }, function(choice)
    if choice and choice.action then
      choice.action()
    end
  end)
end

vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
  callback = function()
    M.load()
    vim.cmd("redrawtabline")
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "FileType" }, {
  callback = function()
    vim.schedule(function()
      vim.cmd("redrawtabline")
      vim.cmd("redrawstatus")
    end)
  end,
})

vim.api.nvim_create_autocmd("TermClose", {
  callback = function()
    vim.schedule(function()
      vim.cmd("redrawtabline")
      vim.cmd("redrawstatus")
    end)
  end,
})

return M
