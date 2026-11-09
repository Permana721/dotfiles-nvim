local source = {}

local modifiers = {
  public = true,
  private = true,
  protected = true,
  static = true,
  final = true,
  abstract = true,
  transient = true,
  volatile = true,
  synchronized = true,
}

local function split_words(type_name)
  local spaced = type_name
    :gsub("(%u+)(%u%l)", "%1 %2")
    :gsub("(%l%d?)(%u)", "%1 %2")

  local words = {}

  for word in spaced:gmatch("[^%s]+") do
    table.insert(words, word:lower())
  end

  return words
end

local function capitalize(word)
  return word:sub(1, 1):upper() .. word:sub(2):lower()
end

local function generate_variations(type_name)
  local words = split_words(type_name)

  if #words == 0 then
    return {}
  end

  local camel = words[1]
  local pascal = ""
  local snake = table.concat(words, "_")
  local abbreviation = ""
  local short = words[1]

  for i, word in ipairs(words) do
    pascal = pascal .. capitalize(word)
    abbreviation = abbreviation .. word:sub(1, 1)

    if i > 1 then
      camel = camel .. capitalize(word)
      short = short .. capitalize(word:sub(1, 4))
    end
  end

  if #words == 1 then
    abbreviation = words[1]:sub(1, 4)
  end

  local candidates = {
    { name = camel, style = "camelCase" },
    { name = pascal, style = "PascalCase" },
    { name = snake, style = "snake_case" },
    { name = abbreviation, style = "abbreviation" },
    { name = short, style = "short camelCase" },
    { name = camel .. "Obj", style = "object suffix" },
  }

  local result = {}
  local seen = {}

  for _, candidate in ipairs(candidates) do
    if not seen[candidate.name] then
      seen[candidate.name] = true
      table.insert(result, candidate)
    end
  end

  return result
end

local function get_declaration_context(line)
  local before, prefix = line:match("^(.-)%s+([%w_]*)$")

  if not before then
    return nil
  end

  before = vim.trim(before)

  local type_name = before:match("([%a_][%w_]*)$")

  if not type_name then
    return nil
  end

  if not type_name:match("^[A-Z][%w_]*$") then
    return nil
  end

  local preceding = vim.trim(
    before:sub(1, #before - #type_name)
  )

  for modifier in preceding:gmatch("%S+") do
    if not modifiers[modifier] then
      return nil
    end
  end

  return type_name, prefix or ""
end

function source:is_available()
  return vim.bo.filetype == "java"
end

function source:get_debug_name()
  return "java_var"
end

function source:get_keyword_pattern()
  return [[\k*]]
end

function source:get_trigger_characters()
  return { " " }
end

function source:complete(params, callback)
  local line = params.context.cursor_before_line or ""

  local type_name = get_declaration_context(line)

  if not type_name then
    callback({})
    return
  end

  local candidates = generate_variations(type_name)
  local items = {}

  for index, candidate in ipairs(candidates) do
    table.insert(items, {
      label = candidate.name,
      insertText = candidate.name,
      filterText = candidate.name,

      kind = 6,

      detail = candidate.style,
      sortText = string.format("%02d", index),
    })
  end

  callback(items)
end

return source
