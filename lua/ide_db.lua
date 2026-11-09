local M = {}

local state = {
  active_conn = nil,
  saved_conns = {},
  tables = {},
  columns = {},
  all_columns = {},
  status = "Disconnected",
}

local config_file = vim.fn.stdpath("data") .. "/ide_db_connections.json"

local function load_saved_connections()
  local ok, lines = pcall(vim.fn.readfile, config_file)
  if ok and lines and #lines > 0 then
    local decoded_ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
    if decoded_ok and type(data) == "table" then
      state.saved_conns = data
    end
  end
end

local function save_connections()
  local ok, encoded = pcall(vim.json.encode, state.saved_conns)
  if ok then
    pcall(vim.fn.writefile, { encoded }, config_file)
  end
end

load_saved_connections()

local function build_cli_cmd(conn, sql, raw_tuples)
  if conn.type == "postgresql" then
    local env = { PATH = vim.env.PATH, HOME = vim.env.HOME }
    if conn.password and conn.password ~= "" then
      env.PGPASSWORD = conn.password
    end
    local cmd = {
      "psql",
      "-h", conn.host,
      "-p", tostring(conn.port),
      "-U", conn.user,
      "-d", conn.dbname,
      "-w",
    }
    if raw_tuples then
      table.insert(cmd, "-t")
      table.insert(cmd, "-A")
      table.insert(cmd, "-F")
      table.insert(cmd, "|")
    else
      table.insert(cmd, "--pset=pager=off")
    end
    table.insert(cmd, "-c")
    table.insert(cmd, sql)
    return cmd, env
  elseif conn.type == "mysql" then
    local cmd = {
      "mysql",
      "-h", conn.host,
      "-P", tostring(conn.port),
      "-u", conn.user,
    }
    if conn.password and conn.password ~= "" then
      table.insert(cmd, "-p" .. conn.password)
    end
    if raw_tuples then
      table.insert(cmd, "-N")
      table.insert(cmd, "-B")
    else
      table.insert(cmd, "-t")
    end
    table.insert(cmd, conn.dbname)
    table.insert(cmd, "-e")
    table.insert(cmd, sql)
    return cmd, nil
  elseif conn.type == "sqlite" then
    local cmd = { "sqlite3" }
    if raw_tuples then
      table.insert(cmd, "-separator")
      table.insert(cmd, "|")
    else
      table.insert(cmd, "-header")
      table.insert(cmd, "-box")
    end
    table.insert(cmd, conn.dbname)
    table.insert(cmd, sql)
    return cmd, nil
  end
end

function M.refresh_schema(callback)
  local conn = state.active_conn
  if not conn then
    return
  end

  local sql = ""
  if conn.type == "postgresql" then
    sql = "SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema = 'public' ORDER BY table_name, ordinal_position;"
  elseif conn.type == "mysql" then
    sql = string.format(
      "SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema = '%s' ORDER BY table_name, ordinal_position;",
      conn.dbname
    )
  elseif conn.type == "sqlite" then
    sql = "SELECT m.name, p.name, p.type FROM sqlite_master m JOIN pragma_table_info(m.name) p WHERE m.type = 'table' AND m.name NOT LIKE 'sqlite_%' ORDER BY m.name, p.cid;"
  end

  local cmd, env = build_cli_cmd(conn, sql, true)
  vim.system(cmd, { text = true, env = env }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        state.status = "Error"
        vim.cmd("redrawstatus")
        vim.notify("Database connection failed: " .. vim.trim(res.stderr or "Unknown error"), vim.log.levels.ERROR)
        if callback then
          callback(false)
        end
        return
      end

      local tables_map = {}
      local tables_list = {}
      local columns_map = {}
      local all_cols_map = {}

      local sep = (conn.type == "mysql") and "\t" or "|"
      for line in (res.stdout or ""):gmatch("[^\r\n]+") do
        local parts = vim.split(line, sep, { plain = true })
        if #parts >= 2 then
          local tname = vim.trim(parts[1])
          local cname = vim.trim(parts[2])
          local dtype = parts[3] and vim.trim(parts[3]) or "column"

          if tname ~= "" and cname ~= "" then
            if not tables_map[tname] then
              tables_map[tname] = true
              table.insert(tables_list, tname)
              columns_map[tname] = {}
            end
            table.insert(columns_map[tname], { name = cname, type = dtype })
            all_cols_map[cname] = dtype
          end
        end
      end

      state.tables = tables_list
      state.columns = columns_map
      state.all_columns = all_cols_map
      state.status = conn.dbname

      vim.cmd("redrawstatus")
      vim.notify(
        string.format("Connected to '%s' (%d tables loaded).", conn.dbname, #tables_list),
        vim.log.levels.INFO
      )
      if callback then
        callback(true)
      end
    end)
  end)
end

local function save_or_update_conn(conn)
  for i, c in ipairs(state.saved_conns) do
    if c.name == conn.name then
      state.saved_conns[i] = conn
      save_connections()
      return
    end
  end
  table.insert(state.saved_conns, conn)
  save_connections()
end

function M.connect_to(conn)
  state.active_conn = conn
  state.status = "Connecting..."
  vim.cmd("redrawstatus")
  M.refresh_schema(function(ok)
    if ok then
      save_or_update_conn(conn)
    else
      state.active_conn = nil
    end
  end)
end

function M.prompt_new_connection()
  local db_types = {
    { label = "PostgreSQL", value = "postgresql", default_port = "5432", default_user = "postgres" },
    { label = "MySQL / MariaDB", value = "mysql", default_port = "3306", default_user = "root" },
    { label = "SQLite", value = "sqlite" },
  }

  vim.ui.select(db_types, {
    prompt = "Select Database Engine:",
    format_item = function(item)
      return "  " .. item.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    if choice.value == "sqlite" then
      vim.ui.input({ prompt = "SQLite Database File Path: ", default = vim.fn.getcwd() .. "/database.db" }, function(dbpath)
        if not dbpath or dbpath == "" then
          return
        end
        local conn = {
          name = "SQLite: " .. vim.fn.fnamemodify(dbpath, ":t"),
          type = "sqlite",
          dbname = dbpath,
        }
        M.connect_to(conn)
      end)
      return
    end

    vim.ui.input({ prompt = "Host: ", default = "localhost" }, function(host)
      if not host or host == "" then
        return
      end
      vim.ui.input({ prompt = "Port: ", default = choice.default_port }, function(port)
        if not port or port == "" then
          return
        end
        vim.ui.input({ prompt = "Database Name: " }, function(dbname)
          if not dbname or dbname == "" then
            return
          end
          vim.ui.input({ prompt = "Username: ", default = choice.default_user }, function(user)
            if not user or user == "" then
              return
            end
            vim.schedule(function()
              local ok_pw, password = pcall(vim.fn.inputsecret, "Password (leave empty if none): ")
              if not ok_pw then
                password = ""
              end
              local conn = {
                name = string.format("%s (%s@%s:%s/%s)", choice.label, user, host, port, dbname),
                type = choice.value,
                host = host,
                port = port,
                dbname = dbname,
                user = user,
                password = password,
              }
              M.connect_to(conn)
            end)
          end)
        end)
      end)
    end)
  end)
end

local result_buf = nil
local result_win = nil

local function show_query_output(title, lines)
  if not result_buf or not vim.api.nvim_buf_is_valid(result_buf) then
    result_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[result_buf].buflisted = false
    vim.bo[result_buf].buftype = "nofile"
    vim.bo[result_buf].filetype = "dbout"
  end

  vim.bo[result_buf].modifiable = true
  vim.api.nvim_buf_set_lines(result_buf, 0, -1, false, lines)
  vim.bo[result_buf].modifiable = false

  if not result_win or not vim.api.nvim_win_is_valid(result_win) then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local b = vim.api.nvim_win_get_buf(win)
      if vim.bo[b].filetype ~= "NvimTree" and vim.bo[b].buftype == "" then
        vim.api.nvim_set_current_win(win)
        break
      end
    end
    local height = math.max(10, math.floor(vim.o.lines * 0.28))
    vim.cmd("belowright " .. height .. "split")
    result_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(result_win, result_buf)
    vim.wo[result_win].number = false
    vim.wo[result_win].relativenumber = false
    vim.wo[result_win].signcolumn = "no"
  else
    vim.api.nvim_win_set_buf(result_win, result_buf)
  end

  _G.ide_db_close_result = function(_, _, btn)
    if btn == "l" and result_win and vim.api.nvim_win_is_valid(result_win) then
      pcall(vim.api.nvim_win_close, result_win, true)
      result_win = nil
    end
  end

  vim.wo[result_win].winbar = "%#TabLineSel# 󰆼 " .. title .. " %#TabLineFill#%="
    .. "%@v:lua.ide_db_close_result@%#TabLine# x Close %X"
end

function M.execute_sql(sql)
  if not state.active_conn then
    vim.notify("No active database connection. Click the DB icon in the statusline first.", vim.log.levels.WARN)
    return
  end

  if not sql or vim.trim(sql) == "" then
    return
  end

  local cmd, env = build_cli_cmd(state.active_conn, sql, false)
  vim.system(cmd, { text = true, env = env }, function(res)
    vim.schedule(function()
      local out = {}
      table.insert(out, "-- Connection: " .. state.active_conn.name)
      table.insert(out, "-- Query: " .. (sql:gsub("\r?\n", " "):gsub("%s+", " ")))
      table.insert(out, string.rep("-", 72))

      if res.code ~= 0 then
        table.insert(out, "ERROR:")
        for line in (res.stderr or ""):gmatch("[^\r\n]+") do
          table.insert(out, line)
        end
      else
        local has_lines = false
        for line in (res.stdout or ""):gmatch("[^\r\n]+") do
          table.insert(out, line)
          has_lines = true
        end
        if not has_lines then
          table.insert(out, "Query executed successfully (no rows returned).")
        end
      end

      show_query_output("DB Data Tables (" .. state.active_conn.dbname .. ")", out)
    end)
  end)
end

function M.browse_tables()
  if not state.active_conn then
    M.prompt_new_connection()
    return
  end

  if #state.tables == 0 then
    vim.notify("No tables found in schema.", vim.log.levels.WARN)
    return
  end

  vim.ui.select(state.tables, {
    prompt = "Select Table (" .. state.active_conn.dbname .. "):",
    format_item = function(t)
      local cols = state.columns[t] or {}
      return string.format("  󰓫 %s (%d columns)", t, #cols)
    end,
  }, function(table_name)
    if not table_name then
      return
    end
    local actions = {
      "View Top 100 Rows (SELECT * FROM " .. table_name .. " LIMIT 100)",
      "View Table Columns & Data Types",
      "Copy INSERT INTO Template to Clipboard",
    }
    vim.ui.select(actions, {
      prompt = "Table Action [" .. table_name .. "]:",
    }, function(act)
      if not act then
        return
      end
      if act:find("^View Top 100") then
        M.execute_sql("SELECT * FROM " .. table_name .. " LIMIT 100;")
      elseif act:find("^View Table Columns") then
        local lines = {
          "Table: " .. table_name,
          string.rep("=", 48),
          string.format("%-28s | %s", "COLUMN NAME", "DATA TYPE"),
          string.rep("-", 48),
        }
        for _, col in ipairs(state.columns[table_name] or {}) do
          table.insert(lines, string.format("%-28s | %s", col.name, col.type))
        end
        show_query_output("Structure: " .. table_name, lines)
      elseif act:find("^Copy INSERT") then
        local cols = state.columns[table_name] or {}
        local col_names = {}
        local placeholders = {}
        for _, c in ipairs(cols) do
          table.insert(col_names, c.name)
          table.insert(placeholders, "?")
        end
        local tpl = string.format(
          "INSERT INTO %s (%s)\nVALUES (%s)",
          table_name,
          table.concat(col_names, ", "),
          table.concat(placeholders, ", ")
        )
        vim.fn.setreg("+", tpl)
        vim.notify("Copied INSERT statement for '" .. table_name .. "' to clipboard.", vim.log.levels.INFO)
      end
    end)
  end)
end

function M.open_scratchpad()
  if not state.active_conn then
    vim.notify("Connect to a database first.", vim.log.levels.WARN)
    return
  end
  vim.cmd("tabnew")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = ""
  vim.bo[buf].filetype = "sql"
  vim.api.nvim_buf_set_name(buf, "DB_Console_" .. state.active_conn.dbname .. ".sql")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "-- Connected to: " .. state.active_conn.name,
    "-- Press <Leader>r or click DB -> Run SQL Under Cursor to execute",
    "",
    "SELECT * FROM " .. (state.tables[1] or "table_name") .. " LIMIT 50;",
  })
  vim.keymap.set({ "n", "v" }, "<Leader>r", function()
    M.run_current_sql()
  end, { buffer = buf, desc = "Execute SQL query" })
end

function M.run_current_sql()
  if vim.bo.filetype == "sql" then
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local filtered = {}
    for _, l in ipairs(lines) do
      if not l:match("^%s*%-%-") then
        table.insert(filtered, l)
      end
    end
    M.execute_sql(table.concat(filtered, "\n"))
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, math.max(0, row - 15), math.min(vim.api.nvim_buf_line_count(0), row + 15), false)
  local block = table.concat(lines, "\n")

  local multiline_sql = block:match('"""%s*(.-)%s*"""')
  if multiline_sql and multiline_sql ~= "" then
    M.execute_sql(multiline_sql)
    return
  end

  local cur_line = vim.api.nvim_get_current_line()
  local single_sql = cur_line:match('"%s*(.-)%s*"')
  if single_sql and single_sql ~= "" then
    M.execute_sql(single_sql)
    return
  end

  vim.ui.input({ prompt = "Execute SQL: " }, function(input_sql)
    if input_sql and input_sql ~= "" then
      M.execute_sql(input_sql)
    end
  end)
end

function M.open_menu()
  local items = {}

  if state.active_conn then
    table.insert(items, { id = "browse", label = "Browse Tables & Data (" .. state.active_conn.dbname .. ")" })
    table.insert(items, { id = "console", label = "Open SQL Query Console" })
    table.insert(items, { id = "run_cursor", label = "Run SQL Query Under Cursor" })
    table.insert(items, { id = "refresh", label = "Refresh Database Schema" })
    table.insert(items, { id = "disconnect", label = "Disconnect (" .. state.active_conn.dbname .. ")" })
  end

  table.insert(items, { id = "new", label = "+ New Database Connection..." })

  for _, conn in ipairs(state.saved_conns) do
    local is_current = state.active_conn and state.active_conn.name == conn.name
    if not is_current then
      table.insert(items, { id = "saved", label = "Connect: " .. conn.name, conn = conn })
    end
  end

  vim.ui.select(items, {
    prompt = "Database Tool Window:",
    format_item = function(item)
      return "  " .. item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    if choice.id == "new" then
      M.prompt_new_connection()
    elseif choice.id == "saved" then
      M.connect_to(choice.conn)
    elseif choice.id == "browse" then
      M.browse_tables()
    elseif choice.id == "console" then
      M.open_scratchpad()
    elseif choice.id == "run_cursor" then
      M.run_current_sql()
    elseif choice.id == "refresh" then
      M.refresh_schema()
    elseif choice.id == "disconnect" then
      state.active_conn = nil
      state.tables = {}
      state.columns = {}
      state.all_columns = {}
      state.status = "Disconnected"
      vim.cmd("redrawstatus")
      vim.notify("Database disconnected.", vim.log.levels.INFO)
    end
  end)
end

function M.statusline()
  if state.active_conn then
    return "%@v:lua.ide_db_click@%#St_gitIcons# 󰆼 " .. state.status .. " %X"
  end
  return "%@v:lua.ide_db_click@%#St_gitIcons# 󰆼 DB %X"
end

_G.ide_db_click = function(_, _, button)
  if button == "l" then
    M.open_menu()
  elseif button == "r" then
    M.browse_tables()
  end
end

local sql_source = {}

function sql_source.new()
  return setmetatable({}, { __index = sql_source })
end

function sql_source:is_available()
  if not state.active_conn or #state.tables == 0 then
    return false
  end
  local ft = vim.bo.filetype
  return ft == "java" or ft == "sql" or ft == "kotlin" or ft == "xml"
end

function sql_source:get_trigger_characters()
  return { " ", ".", "(", "," }
end

function sql_source:get_keyword_pattern()
  return [[\k\+]]
end

local function get_recent_sql_context()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]
  local start_row = math.max(0, row - 12)
  local lines = vim.api.nvim_buf_get_lines(0, start_row, row, false)
  if #lines > 0 then
    lines[#lines] = lines[#lines]:sub(1, col)
  end
  return table.concat(lines, " ")
end

function sql_source:complete(_, callback)
  if not state.active_conn or #state.tables == 0 then
    callback({ items = {}, isIncomplete = false })
    return
  end

  local cmp = require("cmp")
  local context = get_recent_sql_context()
  local upper_ctx = context:upper()
  local items = {}

  local after_table_Dot = context:match("([%w_]+)%.([%w_]*)$")
  if after_table_Dot and state.columns[after_table_Dot] then
    for _, col in ipairs(state.columns[after_table_Dot]) do
      table.insert(items, {
        label = col.name,
        kind = cmp.lsp.CompletionItemKind.Field,
        detail = after_table_Dot .. "." .. col.name .. " (" .. col.type .. ")",
      })
    end
    callback({ items = items, isIncomplete = false })
    return
  end

  local is_insert_into = upper_ctx:match("INSERT%s+INTO%s+[%w_]*$")
  local is_table_ctx = is_insert_into
    or upper_ctx:match("FROM%s+[%w_]*$")
    or upper_ctx:match("JOIN%s+[%w_]*$")
    or upper_ctx:match("UPDATE%s+[%w_]*$")
    or upper_ctx:match("TABLE%s+[%w_]*$")
    or upper_ctx:match("INTO%s+[%w_]*$")

  local is_col_ctx = upper_ctx:match("SELECT%s+[%w_,%s]*$")
    or upper_ctx:match("WHERE%s+[%w_]*$")
    or upper_ctx:match("AND%s+[%w_]*$")
    or upper_ctx:match("OR%s+[%w_]*$")
    or upper_ctx:match("SET%s+[%w_,%s=%?]*$")
    or upper_ctx:match("BY%s+[%w_]*$")
    or upper_ctx:match("%([%w_,%s]*$")

  if is_table_ctx then
    for _, tname in ipairs(state.tables) do
      local cols = state.columns[tname] or {}
      local col_names = {}
      local placeholders = {}
      for _, c in ipairs(cols) do
        table.insert(col_names, c.name)
        table.insert(placeholders, "?")
      end

      local col_str = table.concat(col_names, ", ")
      local val_str = table.concat(placeholders, ", ")

      table.insert(items, {
        label = tname,
        kind = cmp.lsp.CompletionItemKind.Struct,
        detail = string.format("Table (%d columns)", #cols),
        documentation = "Columns: " .. col_str,
      })

      if is_insert_into and #col_names > 0 then
        table.insert(items, {
          label = tname .. " (Full INSERT Snippet)",
          filterText = tname,
          kind = cmp.lsp.CompletionItemKind.Snippet,
          detail = "INSERT INTO " .. tname .. " (...) VALUES (?)",
          insertText = string.format("%s (%s)\nVALUES (%s)", tname, col_str, val_str),
          documentation = string.format("Expands to:\nINSERT INTO %s (%s)\nVALUES (%s)", tname, col_str, val_str),
        })
      end
    end
  end

  local target_table = context:match("[Ii][Nn][Tt][Oo]%s+([%w_]+)")
    or context:match("[Ff][Rr][Oo][Mm]%s+([%w_]+)")
    or context:match("[Uu][Pp][Dd][Aa][Tt][Ee]%s+([%w_]+)")

  if is_col_ctx or target_table then
    if target_table and state.columns[target_table] then
      local cols = state.columns[target_table]
      local all_names = {}
      for _, col in ipairs(cols) do
        table.insert(all_names, col.name)
        table.insert(items, {
          label = col.name,
          kind = cmp.lsp.CompletionItemKind.Field,
          detail = target_table .. "." .. col.name .. " (" .. col.type .. ")",
        })
      end
      if #all_names > 1 then
        table.insert(items, {
          label = table.concat(all_names, ", "),
          filterText = all_names[1],
          kind = cmp.lsp.CompletionItemKind.Snippet,
          detail = "All columns of " .. target_table,
        })
      end
    else
      for cname, dtype in pairs(state.all_columns) do
        table.insert(items, {
          label = cname,
          kind = cmp.lsp.CompletionItemKind.Field,
          detail = "Column (" .. dtype .. ")",
        })
      end
    end
  end

  if #items == 0 and upper_ctx:find("SQL") then
    for _, tname in ipairs(state.tables) do
      table.insert(items, {
        label = tname,
        kind = cmp.lsp.CompletionItemKind.Struct,
        detail = "DB Table",
      })
    end
  end

  callback({ items = items, isIncomplete = true })
end

M.cmp_source = sql_source.new()

return M
