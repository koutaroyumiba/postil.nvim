---@class PostilTmuxPane
---@field id string
---@field session_name string
---@field window_index integer
---@field pane_index integer
---@field current_command string
---@field current_path string
---@field active boolean

---@class PostilTmuxTargetOptions
---@field direction "right"|"left"|"above"|"below"
---@field size integer
---@field cwd string
---@field command string

local M = {}

local target_pane_id = nil
local buffer_counter = 0

local split_flags = {
  right = "-h",
  left = "-hb",
  below = "-v",
  above = "-vb",
}

---@param value string
---@return string
local function trim_trailing_newlines(value)
  return (value:gsub("[\r\n]+$", ""))
end

---@param args string[]
---@param opts? { stdin?: string }
---@return vim.SystemCompleted? result
---@return string? error
local function run(args, opts)
  local environment_ok, environment_error = M.check_environment()
  if not environment_ok then
    return nil, environment_error
  end

  local command = { "tmux" }
  vim.list_extend(command, args)

  local system_ok, process = pcall(vim.system, command, {
    stdin = opts and opts.stdin or nil,
    text = true,
  })

  if not system_ok then
    return nil, "failed to start tmux"
  end

  local wait_ok, result = pcall(function()
    return process:wait()
  end)

  if not wait_ok then
    return nil, "tmux invocation failed"
  end

  if result.code ~= 0 then
    local detail = trim_trailing_newlines(result.stderr or "")
    if detail == "" then
      detail = string.format("tmux exited with status %d", result.code)
    end
    return nil, detail
  end

  return result
end

---@return true? ok
---@return string? error
function M.check_environment()
  if type(vim.env.TMUX) ~= "string" or vim.env.TMUX == "" then
    return nil, "postil.nvim requires Neovim to be running inside tmux"
  end

  if vim.fn.executable("tmux") ~= 1 then
    return nil, "tmux is not available on PATH"
  end

  return true
end

---@return string? pane_id
function M.current_pane()
  if type(vim.env.TMUX_PANE) ~= "string" or vim.env.TMUX_PANE == "" then
    return nil
  end

  return vim.env.TMUX_PANE
end

---@param pane_id any
---@return boolean
local function valid_pane_id(pane_id)
  return type(pane_id) == "string" and pane_id:match("^%%%d+$") ~= nil
end

---@param pane_id string
---@return boolean? exists
---@return string? error
function M.pane_exists(pane_id)
  if not valid_pane_id(pane_id) then
    return nil, "invalid tmux pane ID"
  end

  local environment_ok, environment_error = M.check_environment()
  if not environment_ok then
    return nil, environment_error
  end

  local command = {
    "tmux",
    "display-message",
    "-p",
    "-t",
    pane_id,
    "#{pane_id}",
  }

  local system_ok, process = pcall(vim.system, command, { text = true })
  if not system_ok then
    return nil, "failed to start tmux"
  end

  local wait_ok, result = pcall(function()
    return process:wait()
  end)
  if not wait_ok then
    return nil, "tmux invocation failed"
  end

  if result.code ~= 0 then
    local detail = trim_trailing_newlines(result.stderr or "")
    if detail == "" then
      detail = string.format("tmux exited with status %d", result.code)
    end
    return nil, detail
  end

  return trim_trailing_newlines(result.stdout or "") == pane_id
end

---@return PostilTmuxPane[]? panes
---@return string? error
function M.list_panes()
  local format = table.concat({
    "#{pane_id}",
    "#{session_name}",
    "#{window_index}",
    "#{pane_index}",
    "#{pane_current_command}",
    "#{pane_current_path}",
    "#{pane_active}",
  }, "\t")

  local result, list_error = run({
    "list-panes",
    "-s",
    "-F",
    format,
  })
  if not result then
    return nil, list_error
  end

  local panes = {}
  local output = trim_trailing_newlines(result.stdout or "")
  if output == "" then
    return panes
  end

  for line in output:gmatch("[^\r\n]+") do
    local fields = vim.split(line, "\t", {
      plain = true,
      trimempty = false,
    })

    if #fields == 7 and valid_pane_id(fields[1]) then
      panes[#panes + 1] = {
        id = fields[1],
        session_name = fields[2],
        window_index = tonumber(fields[3]) or 0,
        pane_index = tonumber(fields[4]) or 0,
        current_command = fields[5],
        current_path = fields[6],
        active = fields[7] == "1",
      }
    end
  end

  return panes
end

---@return string? pane_id
function M.get_target()
  return target_pane_id
end

---@param pane_id string
---@return true? ok
---@return string? error
function M.set_target(pane_id)
  if not valid_pane_id(pane_id) then
    return nil, "invalid tmux pane ID"
  end

  if pane_id == M.current_pane() then
    return nil, "cannot use the Neovim pane as the Postil target"
  end

  local exists, exists_error = M.pane_exists(pane_id)
  if exists == nil then
    return nil, exists_error
  end
  if not exists then
    return nil, string.format("tmux pane %s does not exist", pane_id)
  end

  target_pane_id = pane_id
  return true
end

---@return true
function M.clear_target()
  target_pane_id = nil
  return true
end

---@return string? pane_id
---@return string? error
function M.live_target()
  if target_pane_id == nil then
    return nil
  end

  local exists, exists_error = M.pane_exists(target_pane_id)
  if exists == nil then
    return nil, exists_error
  end
  if not exists then
    target_pane_id = nil
    return nil
  end

  return target_pane_id
end

---@param opts PostilTmuxTargetOptions
---@return string? pane_id
---@return string? error
function M.create_pane(opts)
  if type(opts) ~= "table" then
    return nil, "pane options must be a table"
  end

  local split_flag = split_flags[opts.direction]
  if not split_flag then
    return nil, "invalid tmux split direction"
  end
  if type(opts.size) ~= "number" or opts.size <= 0 or opts.size ~= math.floor(opts.size) then
    return nil, "tmux split size must be a positive integer"
  end
  if type(opts.cwd) ~= "string" or opts.cwd == "" then
    return nil, "tmux pane directory must be a non-empty string"
  end
  if type(opts.command) ~= "string" or opts.command == "" then
    return nil, "tmux pane command must be a non-empty string"
  end

  local result, create_error = run({
    "split-window",
    "-d",
    "-P",
    "-F",
    "#{pane_id}",
    split_flag,
    "-l",
    tostring(opts.size),
    "-c",
    opts.cwd,
    opts.command,
  })
  if not result then
    return nil, "failed to create tmux pane: " .. create_error
  end

  local pane_id = trim_trailing_newlines(result.stdout or "")
  if not valid_pane_id(pane_id) then
    return nil, "tmux returned an invalid pane ID"
  end

  target_pane_id = pane_id
  return pane_id
end

---@param opts PostilTmuxTargetOptions
---@return string? pane_id
---@return boolean? created
---@return string? error
function M.resolve_target(opts)
  if target_pane_id ~= nil then
    local exists, exists_error = M.pane_exists(target_pane_id)
    if exists == nil then
      return nil, nil, exists_error
    end
    if exists then
      return target_pane_id, false
    end
    target_pane_id = nil
  end

  local pane_id, create_error = M.create_pane(opts)
  if not pane_id then
    return nil, nil, create_error
  end

  return pane_id, true
end

---@param pane_id string
---@param message string
---@param submit boolean
---@return true? ok
---@return string? error
function M.paste(pane_id, message, submit)
  if type(message) ~= "string" then
    return nil, "message must be a string"
  end
  if type(submit) ~= "boolean" then
    return nil, "submit must be a boolean"
  end

  local exists, exists_error = M.pane_exists(pane_id)
  if exists == nil then
    return nil, exists_error
  end
  if not exists then
    return nil, "destination tmux pane no longer exists"
  end

  buffer_counter = buffer_counter + 1
  local pid = vim.uv.os_getpid()
  local buffer_name = string.format("postil-%d-%d", pid, buffer_counter)

  local loaded, load_error = run({
    "load-buffer",
    "-b",
    buffer_name,
    "-",
  }, { stdin = message })
  if not loaded then
    run({ "delete-buffer", "-b", buffer_name })
    return nil, "failed to load tmux buffer: " .. load_error
  end

  local pasted, paste_error = run({
    "paste-buffer",
    "-d",
    "-p",
    "-r",
    "-b",
    buffer_name,
    "-t",
    pane_id,
  })
  if not pasted then
    run({ "delete-buffer", "-b", buffer_name })
    return nil, "failed to paste into tmux pane: " .. paste_error
  end

  if submit then
    local submitted, submit_error = run({
      "send-keys",
      "-t",
      pane_id,
      "Enter",
    })
    if not submitted then
      return nil, "failed to submit in tmux pane: " .. submit_error
    end
  end

  return true
end

return M
