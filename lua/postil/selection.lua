---@alias PostilSelectionType "character" | "line" | "block"
---@alias PostilVisualMode "v" | "V" | "\22"
---@alias PostilSelectionOption "inclusive" | "exclusive" | "old"

---@class PostilPosition
---@field line integer
---@field column integer

---@class PostilSelection
---@field text string
---@field start_line integer
---@field end_line integer
---@field selection_type PostilSelectionType

local M = {}

---@type table<string, PostilSelectionType>
local selection_types = {
  ["v"] = "character",
  ["V"] = "line",
  ["\22"] = "block",
}

---@param value any
---@return boolean
local function is_positive_integer(value)
  return type(value) == "number"
      and value > 0
      and value < math.huge
      and value == math.floor(value)
end

---@param position any
---@param name string
---@return boolean valid
---@return string? error
local function validate_position(position, name)
  if type(position) ~= "table" then
    return false, name .. " must be a table"
  end

  if not is_positive_integer(position.line) then
    return false, name .. ".line must be a positive integer"
  end

  if not is_positive_integer(position.column) then
    return false, name .. ".column must be a positive integer"
  end

  return true
end

---@param left PostilPosition
---@param right PostilPosition
---@return boolean
local function position_is_after(left, right)
  return left.line > right.line or (left.line == right.line and left.column > right.column)
end

---@param position PostilPosition
---@return PostilPosition
local function copy_position(position)
  return {
    line = position.line,
    column = position.column,
  }
end

---@param start_mark PostilPosition
---@param end_mark PostilPosition
---@param selection_type PostilSelectionType
---@return PostilPosition start_position
---@return PostilPosition end_position
local function normalize_positions(start_mark, end_mark, selection_type)
  if selection_type == "block" then
    return {
      line = math.min(start_mark.line, end_mark.line),
      column = math.min(start_mark.column, end_mark.column),
    }, {
      line = math.max(start_mark.line, end_mark.line),
      column = math.max(start_mark.column, end_mark.column),
    }
  end

  local start_position = copy_position(start_mark)
  local end_position = copy_position(end_mark)

  if position_is_after(start_position, end_position) then
    start_position, end_position = end_position, start_position
  end

  return start_position, end_position
end

---@param byte integer?
---@return boolean
local function is_continuation_byte(byte)
  return byte ~= nil and byte >= 0x80 and byte < 0xC0
end

---@param line string
---@param column integer
---@return integer
local function character_start_column(line, column)
  if column > #line then
    return column
  end

  while column > 1 and is_continuation_byte(line:byte(column)) do
    column = column - 1
  end

  return column
end

---@param line string
---@param column integer
---@return integer
local function inclusive_end_column(line, column)
  local start_column = character_start_column(line, column)
  local first_byte = line:byte(start_column)

  -- UTF-8 character width is encoded by the leading byte. Expanding to
  -- the final byte prevents an inclusive selection from splitting a codepoint.
  if first_byte == nil or first_byte < 0x80 then
    return start_column
  elseif first_byte < 0xE0 then
    return start_column + 1
  elseif first_byte < 0xF0 then
    return start_column + 2
  elseif first_byte < 0xF8 then
    return start_column + 3
  end

  return start_column
end

---@param lines string[]
---@param start_column integer
---@param end_column integer
---@return string
local function extract_characterwise(lines, start_column, end_column)
  if #lines == 1 then
    return lines[1]:sub(start_column, end_column)
  end

  local selected = {}

  selected[1] = lines[1]:sub(start_column)

  for index = 2, #lines - 1 do
    selected[#selected + 1] = lines[index]
  end

  selected[#selected + 1] = lines[#lines]:sub(1, end_column)

  return table.concat(selected, "\n")
end

---@param lines string[]
---@param start_column integer
---@param end_column integer
---@return string
local function extract_blockwise(lines, start_column, end_column, exclusive)
  local selected = {}

  for _, line in ipairs(lines) do
    local row_start_column = character_start_column(line, start_column)
    local row_end_column

    if exclusive then
      row_end_column = character_start_column(line, end_column) - 1
    else
      row_end_column = inclusive_end_column(line, end_column)
    end

    selected[#selected + 1] = line:sub(row_start_column, row_end_column)
  end

  return table.concat(selected, "\n")
end

---@param start_mark PostilPosition
---@param end_mark PostilPosition
---@param visual_mode PostilVisualMode
---@param selection_option PostilSelectionOption
---@return PostilSelection? selection
---@return string? error
function M.extract(bufnr, start_mark, end_mark, visual_mode, selection_option)
  if type(bufnr) ~= "number" or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, "buffer is invalid"
  end

  local start_valid, start_error = validate_position(start_mark, "start mark")
  if not start_valid then
    return nil, start_error
  end

  local end_valid, end_error = validate_position(end_mark, "end mark")
  if not end_valid then
    return nil, end_error
  end

  local selection_type = selection_types[visual_mode]
  if not selection_type then
    return nil, "unsupported visual selection mode"
  end

  if selection_option ~= "inclusive" and selection_option ~= "exclusive" and selection_option ~= "old" then
    return nil, "invalid selection option"
  end

  local start_position, end_position = normalize_positions(start_mark, end_mark, selection_type)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  if start_position.line > line_count or end_position.line > line_count then
    return nil, "selection marks are outside the buffer"
  end

  local read_ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, start_position.line - 1, end_position.line, false)
  if not read_ok then
    return nil, "failed to read the selected lines"
  end
  if #lines == 0 then
    return nil, "selection contains no lines"
  end

  local end_column = end_position.column
  -- for characterwise and blockwise selections, nvim's "exclusive" option
  -- excludes the final byte...
  -- blockwise is handled in extract_blockwise
  if selection_type == "character" then
    if selection_option == "exclusive" then
      end_column = end_column - 1
    else
      end_column = inclusive_end_column(lines[#lines], end_column)
    end
  end

  local text

  if selection_type == "character" then
    text = extract_characterwise(lines, start_position.column, end_column)
  elseif selection_type == "line" then
    text = table.concat(lines, "\n")
  else
    text = extract_blockwise(lines, start_position.column, end_column, selection_option == "exclusive")
  end

  return {
    text = text,
    start_line = start_position.line,
    end_line = end_position.line,
    selection_type = selection_type,
  }
end

---@param bufnr? integer
---@return PostilSelection? selection
---@return string? error
function M.capture(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, "buffer is invalid"
  end

  local start_mark = vim.api.nvim_buf_get_mark(bufnr, "<")
  local end_mark = vim.api.nvim_buf_get_mark(bufnr, ">")

  if start_mark[1] == 0 or end_mark[1] == 0 then
    return nil, "visual selection marks are unavailable"
  end

  -- nvim_buf_get_mark() returns a one-based line and a zero-based byte
  -- column, while M.extract() uses one-based columns for Lua string slicing.
  local start_position = {
    line = start_mark[1],
    column = start_mark[2] + 1,
  }
  local end_position = {
    line = end_mark[1],
    column = end_mark[2] + 1,
  }

  return M.extract(
    bufnr,
    start_position,
    end_position,
    vim.fn.visualmode(),
    vim.o.selection
  )
end

---@param selection PostilSelection
---@param instruction string
---@param bufnr? integer
---@param root_markers string[]
---@return PostilFormatContext? context
---@return string? error
function M.build_context(selection, instruction, bufnr, root_markers)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return nil, "buffer is invalid"
  end

  if type(selection) ~= "table" then
    return nil, "selection is invalid"
  end

  if type(instruction) ~= "string" then
    return nil, "instruction must be a string"
  end

  if type(root_markers) ~= "table" or not vim.islist(root_markers) or #root_markers == 0 then
    return nil, "root markers must be a non-empty list"
  end

  local cwd = vim.fs.abspath(vim.fn.getcwd())
  local name = vim.api.nvim_buf_get_name(bufnr)

  local path
  local relative_path
  local root

  if name == "" then
    path = "[No Name]"
    relative_path = "[No Name]"
    root = cwd
  else
    path = vim.fs.abspath(name)
    root = vim.fs.root(path, root_markers) or cwd
    relative_path = vim.fs.relpath(root, path) or path
  end

  return {
    instruction = instruction,
    text = selection.text,
    path = path,
    relative_path = relative_path,
    start_line = selection.start_line,
    end_line = selection.end_line,
    filetype = vim.bo[bufnr].filetype,
    root = root,
    selection_type = selection.selection_type,
  }
end

---@param text string
---@return string
local function code_fence(text)
  local longest_run = 0

  for run in text:gmatch("`+") do
    longest_run = math.max(longest_run, #run)
  end

  return string.rep("`", math.max(3, longest_run + 1))
end

---@param context PostilFormatContext
---@return string
local function default_format(context)
  local lines = { "File: " .. context.relative_path }

  if context.start_line == context.end_line then
    lines[#lines + 1] = string.format("Line: %d", context.start_line)
  else
    lines[#lines + 1] = string.format("Lines: %d-%d", context.start_line, context.end_line)
  end

  if context.filetype ~= "" then
    lines[#lines + 1] = "Filetype: " .. context.filetype
  end

  local fence = code_fence(context.text)
  local opening_fence = fence

  if context.filetype ~= "" then
    opening_fence = opening_fence .. context.filetype
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = opening_fence
  lines[#lines + 1] = context.text
  lines[#lines + 1] = fence
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Instruction: " .. context.instruction

  return table.concat(lines, "\n")
end

---@param context PostilFormatContext
---@param custom_formatter? PostilFormatter
---@return string? message
---@return string? error
function M.format(context, custom_formatter)
  if type(context) ~= "table" then
    return nil, "formatter context is invalid"
  end

  if custom_formatter == nil then
    return default_format(context)
  end

  if type(custom_formatter) ~= "function" then
    return nil, "custom formatter must be a function"
  end

  local ok, result = pcall(custom_formatter, vim.deepcopy(context))

  if not ok then
    return nil, "custom formatter failed"
  end

  if type(result) ~= "string" then
    return nil, "custom formatter must return a string"
  end

  return result
end

return M
