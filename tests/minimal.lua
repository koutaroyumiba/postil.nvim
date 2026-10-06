local source = debug.getinfo(1, "S").source:sub(2)
local repository_root = vim.fn.fnamemodify(source, ":p:h:h")

vim.opt.runtimepath:prepend(repository_root)

local ok, err = xpcall(function()
  local function assert_error(callback, expected)
    local call_ok, call_err = pcall(callback)

    assert(not call_ok, "expected function to produce an error")
    assert(
      tostring(call_err):find(expected, 1, true),
      string.format("expected error containing %q, got: %s", expected, call_err)
    )
  end

  local postil = require("postil")
  assert(type(postil) == "table")
  assert(type(require("postil.selection")) == "table")
  assert(type(require("postil.tmux")) == "table")

  assert(type(postil.setup) == "function")
  assert(postil.setup() == true)

  -- testing default configs
  local defaults = postil._get_config()
  assert(defaults.command == "pi")
  assert(defaults.split.direction == "right")
  assert(defaults.split.size == 40)
  assert(defaults.submit == true)
  assert(defaults.startup_delay == 500)
  assert(defaults.prompt == "Postil: ")
  assert(vim.deep_equal(defaults.root_markers, { ".git" }))
  assert(defaults.format == nil)

  -- testing overrides
  local formatter = function(context)
    return context.text
  end

  assert(postil.setup({
    command = "pi --model example",
    split = {
      direction = "above",
      size = 20,
    },
    submit = false,
    startup_delay = 0,
    prompt = "> ",
    root_markers = { ".git", "lua" },
    format = formatter,
  }))

  local configured = postil._get_config()
  assert(configured.command == "pi --model example")
  assert(configured.split.direction == "above")
  assert(configured.split.size == 20)
  assert(configured.submit == false)
  assert(configured.startup_delay == 0)
  assert(configured.prompt == "> ")
  assert(vim.deep_equal(configured.root_markers, { ".git", "lua" }))
  assert(configured.format == formatter)

  -- test repeated setup replacement
  assert(postil.setup({
    split = {
      size = 80,
    },
  }))

  local replaced = postil._get_config()
  assert(replaced.command == "pi")
  assert(replaced.split.direction == "right")
  assert(replaced.split.size == 80)
  assert(replaced.submit == true)

  -- test representative errors
  assert_error(function()
    postil.setup(false)
  end, "setup options must be a table")
  assert_error(function()
    postil.setup({ unknown = true })
  end, "unknown option setup.unknown")
  assert_error(function()
    postil.setup({ command = "" })
  end, "command must be a non-empty string")
  assert_error(function()
    postil.setup({ split = { direction = "diagonal" } })
  end, "split.direction must be one of")
  assert_error(function()
    postil.setup({ split = { size = 0 } })
  end, "split.size must be a positive integer")
  assert_error(function()
    postil.setup({ root_markers = {} })
  end, "root_markers must be a non-empty list")
end, debug.traceback)

if not ok then
  io.stderr:write(tostring(err), "\n")
  vim.cmd("cquit 1")
else
  print("postil.nvim minimal checks passed")
  vim.cmd("quitall!")
end
