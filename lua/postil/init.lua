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

---@class PostilSendOptions
---@field submit? boolean

local selection = require("postil.selection")
local tmux = require("postil.tmux")

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

---@param message string
local function notify_info(message)
  vim.notify(message, vim.log.levels.INFO, { title = "postil.nvim" })
end

---@param message string
local function notify_warn(message)
  vim.notify(message, vim.log.levels.WARN, { title = "postil.nvim" })
end

---@param message string
local function notify_error(message)
  vim.notify(message, vim.log.levels.ERROR, { title = "postil.nvim" })
end

---@param message string?
---@return nil
---@return string
local function fail(message)
  notify_error(message or "something went wrong")
  return nil, message or "something went wrong"
end

---@param bufnr? integer
---@return string
local function project_root(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cwd = vim.fs.abspath(vim.fn.getcwd())
  local name = vim.api.nvim_buf_get_name(bufnr)

  if name == "" then
    return cwd
  end

  local path = vim.fs.abspath(name)
  return vim.fs.root(path, config.root_markers) or cwd
end

---@param bufnr? integer
---@return PostilTmuxTargetOptions
local function target_options(bufnr)
  return {
    direction = config.split.direction,
    size = config.split.size,
    cwd = project_root(bufnr),
    command = config.command,
  }
end

---@param prompt string
---@param callback fun(instruction: string?)
local function open_instruction_editor(prompt, callback)
  local buffer = vim.api.nvim_create_buf(false, true)

  vim.bo[buffer].buftype = "acwrite"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].filetype = "markdown"

  vim.api.nvim_buf_set_name(buffer, "postil://instruction/" .. buffer)

  local max_width = math.max(1, vim.o.columns - 4)
  local max_height = math.max(1, vim.o.lines - 4)

  local width = math.min(math.max(40, math.floor(vim.o.columns * 0.6)), max_width)
  local height = math.min(math.max(5, math.floor(vim.o.lines * 0.25)), max_height)

  local title = prompt:gsub("%s+$", "")
  if title == "" then
    title = "Postil Instruction"
  end

  local window = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    footer = " :w submit · :q! cancel ",
    footer_pos = "center",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
  })

  vim.wo[window].wrap = true
  vim.wo[window].cursorline = false

  local finished = false

  ---@param instruction string?
  local function complete(instruction)
    if finished then
      return
    end

    finished = true

    vim.schedule(function()
      if vim.api.nvim_win_is_valid(window) then
        vim.api.nvim_win_close(window, true)
      end

      callback(instruction)
    end)
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buffer,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
      local instruction = table.concat(lines, "\n")

      vim.bo[buffer].modified = false

      if not instruction:find("%S") then
        complete(nil)
        return
      end

      complete(instruction)
    end
  })

  -- Treat :q! or another external window close as cancellation
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buffer,
    once = true,
    callback = function()
      if finished then
        return
      end

      finished = true

      vim.schedule(function()
        callback(nil)
      end)
    end
  })

  vim.cmd("startinsert")
end

---@param message string
local function open_preview(message)
  local lines = vim.split(message, "\n", {
    plain = true,
  })

  local content_width = 1

  for _, line in ipairs(lines) do
    content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
  end

  local max_width = math.max(1, vim.o.columns - 4)
  local max_height = math.max(1, vim.o.lines - 4)

  local width = math.min(math.max(20, content_width), max_width)
  local height = math.min(math.max(1, #lines), max_height)

  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)

  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].filetype = "markdown"
  vim.bo[buffer].modifiable = false

  local window = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    title = "Postil Preview ",
    title_pos = "center",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2))
  })

  vim.wo[window].wrap = true
  vim.wo[window].cursorline = false

  local function close()
    if vim.api.nvim_win_is_valid(window) then
      vim.api.nvim_win_close(window, true)
    end
  end

  vim.keymap.set("n", "q", close, {
    buffer = buffer,
    nowait = true,
    silent = true,
  })
  vim.keymap.set("n", "<Esc>", close, {
    buffer = buffer,
    nowait = true,
    silent = true,
  })
end

local function leave_visual_mode()
  local mode = vim.api.nvim_get_mode().mode

  if mode == "v" or mode == "V" or mode == "\22" then
    vim.cmd("normal! \27")
  end
end

local M = {}
local busy = false

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
  M._register_commands()

  return true
end

function M._register_commands()
  local function register(name, callback, opts)
    opts = opts or {}
    opts.force = true

    vim.api.nvim_create_user_command(name, callback, opts)
  end

  register("PostilSend", function(args)
    local submit = config.submit

    if args.bang then
      submit = not submit
    end

    M.send_visual({ submit = submit })
  end, {
    bang = true,
    range = true,
    desc = "Send the visual selection with Postil",
  })

  register("PostilTarget", function(args)
    local pane_id = args.args ~= "" and args.args or nil
    M.select_target(pane_id)
  end, {
    nargs = "?",
    desc = "Select a Postil target pane",
  })

  register("PostilNew", function()
    M.new_target()
  end, { desc = "Create a new Postil target pane" })

  register("PostilClearTarget", function()
    M.clear_target()
  end, { desc = "Forget the Postil target pane" })

  register("PostilStatus", function()
    M.status()
  end, { desc = "Show Postil status" })

  register("PostilPreview", function()
    M.preview_visual()
  end, { range = true, desc = "Preview a formatted Postil selection" })
end

---@param opts? PostilSendOptions
---@return true? ok
---@return string? error
function M.send_visual(opts)
  if opts == nil then
    opts = {}
  end

  if type(opts) ~= "table" then
    return fail("send options must be a table")
  end

  for key in pairs(opts) do
    if key ~= "submit" then
      return fail("unknown send option: " .. tostring(key))
    end
  end

  if opts.submit ~= nil and type(opts.submit) ~= "boolean" then
    return fail("submit must be a boolean")
  end

  if busy then
    local message = "Postil is busy"
    notify_warn(message)
    return nil, message
  end

  local environment_ok, environment_error = tmux.check_environment()
  if not environment_ok then
    return fail(environment_error)
  end

  local submit = config.submit
  if opts.submit ~= nil then
    submit = opts.submit
    assert(submit ~= nil)
  end

  local bufnr = vim.api.nvim_get_current_buf()
  busy = true
  leave_visual_mode()

  vim.schedule(function()
    local captured, capture_error = selection.capture(bufnr)
    if not captured then
      busy = false
      notify_error(capture_error or "failed to capture selection")
      return
    end

    open_instruction_editor(config.prompt, function(instruction)
      if instruction == nil then
        busy = false
        return
      end

      local context, context_error = selection.build_context(captured, instruction, bufnr, config.root_markers)
      if not context then
        busy = false
        notify_error(context_error or "failed to build selection context")
        return
      end

      local message, format_error = selection.format(context, config.format)
      if not message then
        busy = false
        notify_error(format_error or "failed to format selection")
        return
      end

      local pane_id, created, target_error = tmux.resolve_target(target_options(bufnr))
      if not pane_id then
        busy = false
        notify_error(target_error or "failed to resolve tmux target")
        return
      end

      local delay = 0
      if created then
        delay = config.startup_delay
      end

      vim.defer_fn(function()
        local sent, send_error = tmux.paste(pane_id, message, submit)
        busy = false
        if not sent then
          notify_error(send_error or "failed to send to tmux pane")
          return
        end

        notify_info("Sent to " .. pane_id)
      end, delay)
    end)
  end)

  return true
end

---@param pane_id? string
---@return true? ok
---@return string? error
function M.select_target(pane_id)
  local environment_ok, environment_error = tmux.check_environment()
  if not environment_ok then
    return fail(environment_error)
  end

  if pane_id ~= nil then
    local selected, select_error = tmux.set_target(pane_id)
    if not selected then
      return fail(select_error)
    end

    notify_info("Target set to " .. pane_id)
    return true
  end

  local panes, list_error = tmux.list_panes()
  if not panes then
    return fail(list_error)
  end
  if #panes == 0 then
    return fail("no tmux panes found in the current session")
  end

  vim.ui.select(panes, {
    prompt = "Postil target: ",
    format_item = function(pane)
      local location = string.format(
        "%s:%d.%d",
        pane.session_name,
        pane.window_index,
        pane.pane_index
      )
      local path = vim.fn.fnamemodify(pane.current_path, ":~")
      return string.format(
        "%s  %s  %s  %s",
        pane.id,
        location,
        pane.current_command,
        path
      )
    end,
  }, function(choice)
    if choice == nil then
      return
    end

    local selected, select_error = tmux.set_target(choice.id)
    if not selected then
      notify_error(select_error or "tmux target selection error")
      return
    end

    notify_info("Target set to " .. choice.id)
  end)

  return true
end

---@return true? ok
---@return string? error
function M.new_target()
  local pane_id, create_error = tmux.create_pane(target_options())
  if not pane_id then
    return fail(create_error)
  end

  notify_info("Created target " .. pane_id)
  return true
end

---@return true
function M.clear_target()
  tmux.clear_target()
  notify_info("Cleared Postil target")
  return true
end

---@return true? ok
---@return string? error
function M.status()
  local pane_id = tmux.get_target()
  local live = false
  local environment_ok, environment_error = tmux.check_environment()

  if pane_id ~= nil and environment_ok then
    local exists, exists_error = tmux.pane_exists(pane_id)
    if exists == nil then
      return fail(exists_error or "failed to inspect tmux target")
    end
    live = exists
  end

  local lines = {
    "Target: " .. (pane_id or "none"),
    "Live: " .. (live and "yes" or "no"),
    "Command: " .. config.command,
    "Project: " .. project_root(),
  }

  if not environment_ok then
    lines[#lines + 1] = "Tmux: " .. environment_error
  end

  notify_info(table.concat(lines, "\n"))
  return true
end

function M.preview_visual()
  local bufnr = vim.api.nvim_get_current_buf()
  leave_visual_mode()

  vim.schedule(function()
    local captured, capture_error = selection.capture(bufnr)
    if not captured then
      notify_error(capture_error or "failed to capture selection")
      return
    end

    open_instruction_editor(config.prompt, function(instruction)
      if instruction == nil or instruction == "" then
        return
      end

      local context, context_error = selection.build_context(captured, instruction, bufnr, config.root_markers)
      if not context then
        notify_error(context_error or "failed to build selection context")
        return
      end

      local message, format_error = selection.format(context, config.format)
      if not message then
        notify_error(format_error or "failed to format selection")
        return
      end

      open_preview(message)
    end)
  end)

  return true
end

-- private helper for testing
function M._get_config()
  return vim.deepcopy(config)
end

return M
