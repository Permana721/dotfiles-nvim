local M = {}

local state_dir = vim.fn.stdpath("state")
local storage_file = state_dir .. "/cmp_mru_mfu.json"

local frequency_counts = {}

local buffer_imports_cache = {}
local buffer_package_cache = {}
local workspace_classes_cache = {}
local entry_tier_cache = {}

function M.load_storage()
  if vim.fn.filereadable(storage_file) == 1 then
    local ok, content = pcall(vim.fn.readfile, storage_file)
    if ok and content and #content > 0 then
      local json_str = table.concat(content, "\n")
      local parse_ok, data = pcall(vim.json.decode, json_str)
      if parse_ok and type(data) == "table" then
        if type(data.frequency) == "table" then
          frequency_counts = data.frequency
        end

        local cmp_ok, cmp = pcall(require, "cmp")
        if cmp_ok and cmp.config and cmp.config.compare and cmp.config.compare.recently_used then
          local ru = cmp.config.compare.recently_used
          if ru.records and type(data.recency) == "table" then
            for k, v in pairs(data.recency) do
              ru.records[k] = v
            end
          end
        end
      end
    end
  end
end

local function save_storage()
  local cmp_ok, cmp = pcall(require, "cmp")
  local recency_records = {}
  if cmp_ok and cmp.config and cmp.config.compare and cmp.config.compare.recently_used then
    recency_records = cmp.config.compare.recently_used.records or {}
  end

  local data = {
    frequency = frequency_counts,
    recency = recency_records,
  }

  local ok, json_str = pcall(vim.json.encode, data)
  if ok and json_str then
    pcall(vim.fn.writefile, { json_str }, storage_file)
  end
end

local save_timer = nil
local function schedule_save()
  if save_timer then
    return
  end
  save_timer = vim.defer_fn(function()
    save_timer = nil
    save_storage()
  end, 1000)
end

function M.clear_tier_cache()
  entry_tier_cache = {}
end

function M.record_confirmed(entry)
  if not entry then
    return
  end

  local item = entry.completion_item or {}
  local label = item.label or entry.word

  if label and label ~= "" then
    frequency_counts[label] = (frequency_counts[label] or 0) + 1
  end

  if item.insertText and item.insertText ~= "" and item.insertText ~= label then
    frequency_counts[item.insertText] = (frequency_counts[item.insertText] or 0) + 1
  end

  if item.textEdit and item.textEdit.newText and item.textEdit.newText ~= "" and item.textEdit.newText ~= label then
    frequency_counts[item.textEdit.newText] = (frequency_counts[item.textEdit.newText] or 0) + 1
  end

  if entry.word and entry.word ~= "" and entry.word ~= label then
    frequency_counts[entry.word] = (frequency_counts[entry.word] or 0) + 1
  end

  local cmp_ok, cmp = pcall(require, "cmp")
  if cmp_ok and cmp.config and cmp.config.compare and cmp.config.compare.recently_used then
    if cmp.config.compare.recently_used.add_entry then
      cmp.config.compare.recently_used:add_entry(entry)
    end
  end

  schedule_save()
end

local function get_entry_frequency(entry)
  if not entry then
    return 0
  end

  local count = 0
  local item = entry.completion_item

  if item then
    if item.label and frequency_counts[item.label] then
      count = math.max(count, frequency_counts[item.label])
    end
    if item.insertText and frequency_counts[item.insertText] then
      count = math.max(count, frequency_counts[item.insertText])
    end
    if item.textEdit and item.textEdit.newText and frequency_counts[item.textEdit.newText] then
      count = math.max(count, frequency_counts[item.textEdit.newText])
    end
  end

  if entry.word and frequency_counts[entry.word] then
    count = math.max(count, frequency_counts[entry.word])
  end

  return count
end

function M.frequently_used(entry1, entry2)
  local count1 = get_entry_frequency(entry1)
  local count2 = get_entry_frequency(entry2)

  if count1 ~= count2 then
    return count1 > count2
  end

  return nil
end

local function get_cached_buffer_package(bufnr)
  bufnr = (bufnr and bufnr ~= 0) and bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local tick = vim.b[bufnr].changedtick
  local cached = buffer_package_cache[bufnr]
  if cached and cached.tick == tick then
    return cached.pkg
  end

  local pkg = nil
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 40, false)
  for _, line in ipairs(lines) do
    local p = line:match("^%s*package%s+([%w_%.]+)%s*;")
    if p then
      pkg = p
      break
    end
  end

  buffer_package_cache[bufnr] = { tick = tick, pkg = pkg }
  return pkg
end

local function get_cached_buffer_imports(bufnr)
  bufnr = (bufnr and bufnr ~= 0) and bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end

  local tick = vim.b[bufnr].changedtick
  local cached = buffer_imports_cache[bufnr]
  if cached and cached.tick == tick then
    return cached.imports
  end

  local imports = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 100, false)
  for _, line in ipairs(lines) do
    local imp = line:match("^%s*import%s+static%s+([%w_%.%*]+)%s*;")
      or line:match("^%s*import%s+([%w_%.%*]+)%s*;")
    if imp then
      imports[imp] = true
      local wildcard = imp:match("^([%w_%.]+)%.%*$")
      if wildcard then
        imports[wildcard] = true
      end
    end
  end

  buffer_imports_cache[bufnr] = { tick = tick, imports = imports }
  return imports
end

local standard_java_layers = {
  view = true, views = true, entity = true, entities = true,
  model = true, models = true, service = true, services = true,
  repository = true, repositories = true, repo = true,
  controller = true, controllers = true, dao = true, dto = true,
  util = true, utils = true, config = true, configs = true,
  configuration = true, configurations = true, exception = true, exceptions = true,
  handler = true, handlers = true, impl = true, interfaces = true,
  constant = true, constants = true, security = true, domain = true,
  mapper = true, mappers = true, component = true, components = true, client = true,
}

local function get_project_package_prefix(pkg)
  if not pkg or pkg == "" then
    return nil
  end

  local parts = vim.split(pkg, ".", { plain = true })
  while #parts > 1 and standard_java_layers[parts[#parts]:lower()] do
    table.remove(parts)
  end

  if #parts >= 3 then
    return table.concat({ parts[1], parts[2], parts[3] }, ".")
  elseif #parts >= 2 then
    return table.concat({ parts[1], parts[2] }, ".")
  end

  return parts[1]
end

local function get_cached_workspace_classes(bufnr)
  local root = vim.fs.root(bufnr, { "pom.xml", "build.gradle", "mvnw", ".git" })
  if not root then
    return {}
  end

  if workspace_classes_cache[root] then
    return workspace_classes_cache[root]
  end

  local classes = {}
  local java_dir = root .. "/src/main/java"
  local scan_dir = vim.fn.isdirectory(java_dir) == 1 and java_dir or root

  local java_files = vim.fs.find(function(name, path)
    return name:match("%.java$")
      and not path:find("/target/", 1, true)
      and not path:find("/build/", 1, true)
      and not path:find("/%.git/", 1, true)
  end, { path = scan_dir, type = "file", limit = 1000 })

  for _, file in ipairs(java_files) do
    local class_name = file:match("([^/\\]+)%.java$")
    if class_name then
      classes[class_name] = true
    end
  end

  workspace_classes_cache[root] = classes
  return classes
end

local function get_open_buffers_classes()
  local classes = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name and name ~= "" then
        local class_name = name:match("([^/\\]+)%.java$")
        if class_name then
          classes[class_name] = true
        end
      end
    end
  end
  return classes
end

local function extract_entry_signatures(entry)
  local item = entry.completion_item
  if not item then
    return {}
  end

  local sigs = {}

  if type(item.detail) == "string" and item.detail ~= "" then
    table.insert(sigs, item.detail)
  end

  if type(item.labelDetails) == "table" then
    if type(item.labelDetails.description) == "string" and item.labelDetails.description ~= "" then
      table.insert(sigs, item.labelDetails.description)
    end
    if type(item.labelDetails.detail) == "string" and item.labelDetails.detail ~= "" then
      table.insert(sigs, item.labelDetails.detail)
    end
  end

  if type(item.additionalTextEdits) == "table" then
    for _, edit in ipairs(item.additionalTextEdits) do
      if edit.newText and type(edit.newText) == "string" then
        local imp = edit.newText:match("import%s+static%s+([%w_%.]+)%s*;")
          or edit.newText:match("import%s+([%w_%.]+)%s*;")
        if imp then
          table.insert(sigs, imp)
        else
          table.insert(sigs, edit.newText)
        end
      end
    end
  end

  if type(item.data) == "string" and item.data ~= "" then
    table.insert(sigs, item.data)
  end

  return sigs
end

local function is_penalized(entry, imports, query)
  local item = entry.completion_item
  local label = (item and item.label) or entry.word or ""
  local query_lower = query and query:lower() or ""

  if query_lower ~= "" and query_lower == label:lower() then
    return false
  end

  if #query_lower >= 3 then
    if query_lower:find("swing", 1, true)
      or query_lower:find("com.sun", 1, true)
      or query_lower:find("sun.", 1, true)
      or query_lower:find("internal", 1, true) then
      return false
    end
  end

  local sigs = extract_entry_signatures(entry)
  for _, sig in ipairs(sigs) do
    local is_match = sig:match("^javax%.swing%.")
      or sig:match("[ %-%(]javax%.swing%.")
      or sig:match("^com%.sun%.")
      or sig:match("[ %-%(]com%.sun%.")
      or sig:match("^sun%.")
      or sig:match("[ %-%(]sun%.")
      or sig:match("^jdk%.internal%.")
      or sig:match("[ %-%(]jdk%.internal%.")
      or sig:match("^com%.oracle%.")
      or sig:match("[ %-%(]com%.oracle%.")

    if is_match then

      local is_imported = false
      if imports then
        if imports[sig] then
          is_imported = true
        else
          for imp, _ in pairs(imports) do
            if sig:find(imp, 1, true) or imp:find(sig, 1, true) then
              is_imported = true
              break
            end
          end
        end
      end

      if not is_imported then
        return true
      end
    end
  end

  return false
end

local function compute_entry_tier(entry, bufnr, query)
  local item = entry.completion_item
  local label = (item and item.label) or entry.word or ""
  local source_name = entry.source and entry.source.name or ""

  if source_name == "java_var" then
    return 4
  end

  local imports = get_cached_buffer_imports(bufnr)

  if is_penalized(entry, imports, query) then
    return 0
  end

  local current_pkg = get_cached_buffer_package(bufnr)
  local project_prefix = get_project_package_prefix(current_pkg)
  local sigs = extract_entry_signatures(entry)

  if project_prefix then
    for _, sig in ipairs(sigs) do
      if sig:find(project_prefix, 1, true) then
        return 4
      end
    end
  end

  local ws_classes = get_cached_workspace_classes(bufnr)
  if ws_classes and ws_classes[label] then
    return 4
  end

  local open_classes = get_open_buffers_classes()
  if open_classes and open_classes[label] then
    return 4
  end

  if source_name == "buffer" then
    return 3
  end

  if imports then
    for _, sig in ipairs(sigs) do
      if imports[sig] then
        return 3
      end
      for imp, _ in pairs(imports) do
        if sig:find(imp, 1, true) or imp:find(sig, 1, true) then
          return 3
        end
      end
    end
  end

  return 2
end

local function get_entry_tier(entry)
  if not entry then
    return 2
  end

  local id = entry.id
  if id and entry_tier_cache[id] ~= nil then
    return entry_tier_cache[id]
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local query = ""
  if entry.context and entry.context.cursor_before_line then
    query = entry.context.cursor_before_line:match("([%w_%.]+)$") or ""
  end

  local tier = compute_entry_tier(entry, bufnr, query)
  if id then
    entry_tier_cache[id] = tier
  end

  return tier
end

function M.workspace_locality(entry1, entry2)
  local tier1 = get_entry_tier(entry1)
  local tier2 = get_entry_tier(entry2)

  if tier1 ~= tier2 then
    return tier1 > tier2
  end

  return nil
end

function M.get_frequency_counts()
  return frequency_counts
end

function M.clear_frequency_counts()
  frequency_counts = {}
  pcall(vim.fn.delete, storage_file)
end

function M.setup(opts)
  opts = opts or {}
  local cmp = require("cmp")

  cmp.config.compare.frequently_used = M.frequently_used
  cmp.config.compare.workspace_locality = M.workspace_locality

  M.load_storage()

  if not _G.__cmp_ranking_confirm_attached then
    _G.__cmp_ranking_confirm_attached = true

    cmp.event:on("confirm_done", function(event)
      if event and event.entry then
        M.record_confirmed(event.entry)
      end
    end)

    cmp.event:on("menu_closed", function()
      M.clear_tier_cache()
    end)

    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        save_storage()
      end,
    })
  end

  opts.sorting = {
    priority_weight = 2,
    comparators = {
      cmp.config.compare.offset,
      cmp.config.compare.exact,

      M.frequently_used,

      cmp.config.compare.recently_used,

      M.workspace_locality,
      cmp.config.compare.score,
      cmp.config.compare.locality,
      cmp.config.compare.kind,
      cmp.config.compare.sort_text,
      cmp.config.compare.length,
      cmp.config.compare.order,
    },
  }

  return opts
end

return M
