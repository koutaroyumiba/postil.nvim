---@alias PostilSplitDirection "right" | "left" | "above" | "below"

---@class PostilFormatContext
---@field instruction string
---@field text string
---@field path string
---@field relative_path string
---@field start_line integer
---@field end_line integer
---@field filetype string
---@field root string
---@field selection_type "character" | "line" | "block"

---@alias PostilFormatter fun(context: PostilFormatContext): string

---@class PostilSplitConfig
---@field direction PostilSplitDirection
---@field size integer

---@class PostilConfig
---@field command string
---@field split PostilSplitConfig
---@field submit boolean
---@field startup_delay integer
---@field prompt string
---@field root_markers string[]
---@field format PostilFormatter?

---@class PostilSplitOptions
---@field direction? PostilSplitDirection
---@field size? integer

---@class PostilSetupOptions
---@field command? string
---@field split? PostilSplitOptions
---@field submit? boolean
---@field startup_delay? integer
---@field prompt? string
---@field root_markers? string[]
---@field format? PostilFormatter

---@type PostilConfig
local defaults = {
  command = "pi",
  split = {
    direction = "right",
    size = 40,
  },
  submit = true,
  startup_delay = 500,
  prompt = "Postil: ",
  root_markers = { ".git" },
  format = nil,
}

---@type PostilConfig
local config = vim.deepcopy(defaults)

-- ALLOWED KEYS
local setup_keys = {
  command = true,
  split = true,
  submit = true,
  startup_delay = true,
  prompt = true,
  root_markers = true,
  format = true,
}

local split_keys = {
  direction = true,
  size = true,
}

local split_directions = {
  right = true,
  left = true,
  above = true,
  below = true,
}

-- ======================== --
-- PRIVATE HELPER FUNCTIONS --
-- ======================== --

---@param message string
local function config_error(message)
  error("postil.nvim: " .. message, 3)
end

---@param values table
---@param allowed table<string, boolean>
---@param name string
local function validate_keys(values, allowed, name)
  for key in pairs(values) do
    if not allowed[key] then
      config_error(string.format("unknown option %s.%s", name, tostring(key)))
    end
  end
end

---@param value any
---@return boolean
local function is_integer(value)
  return type(value) == "number" and value > -math.huge and value < math.huge and value == math.floor(value)
end

---@param opts any
local function validate_options(opts)
  if type(opts) ~= "table" then
    config_error("setup options must be a table")
  end

  validate_keys(opts, setup_keys, "setup")

  if opts.command ~= nil then
    if type(opts.command) ~= "string" or opts.command == "" then
      config_error("command must be a non-empty string")
    end
  end

  if opts.split ~= nil then
    if type(opts.split) ~= "table" then
      config_error("split must be a table")
    end

    validate_keys(opts.split, split_keys, "split")

    if opts.split.direction ~= nil then
      if type(opts.split.direction) ~= "string" or not split_directions[opts.split.direction] then
        config_error("split.direction must be one of: right, left, above, below")
      end
    end

    if opts.split.size ~= nil then
      if not is_integer(opts.split.size) or opts.split.size <= 0 then
        config_error("split.size must be a positive integer")
      end
    end
  end

  if opts.submit ~= nil and type(opts.submit) ~= "boolean" then
    config_error("submit must be a boolean")
  end

  if opts.startup_delay ~= nil then
    if not is_integer(opts.startup_delay) or opts.startup_delay < 0 then
      config_error("startup_delay must be a non-negative integer")
    end
  end

  if opts.prompt ~= nil and type(opts.prompt) ~= "string" then
    config_error("prompt must be a string")
  end

  if opts.root_markers ~= nil then
    if type(opts.root_markers) ~= "table" or not vim.islist(opts.root_markers) or #opts.root_markers == 0 then
      config_error("root_markers must be a non-empty list")
    end

    for index, marker in ipairs(opts.root_markers) do
      if type(marker) ~= "string" or marker == "" then
        config_error(string.format("root_markers[%d] must be a non-empty string", index))
      end
    end
  end

  if opts.format ~= nil and type(opts.format) ~= "function" then
    config_error("format must be a function or nil")
  end
end

---@param opts PostilSetupOptions
---@return PostilConfig
local function merge_options(opts)
  local merged = vim.deepcopy(defaults)

  for key, value in pairs(opts) do
    if key == "split" then
      for split_key, split_value in pairs(value) do
        merged.split[split_key] = split_value
      end
    elseif key == "root_markers" then
      merged.root_markers = vim.deepcopy(value)
    else
      merged[key] = value
    end
  end

  return merged
end


local M = {}

---@param opts? PostilSetupOptions
---@return true
function M.setup(opts)
  if vim.fn.has("nvim-0.12") ~= 1 then
    config_error("Neovim 0.12 or newer is required")
  end

  if opts == nil then
    opts = {}
  end

  validate_options(opts)
  config = merge_options(opts)

  return true
end

-- private helper for testing
function M._get_config()
  return vim.deepcopy(config)
end

return M
