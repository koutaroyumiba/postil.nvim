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

  -- testing command registration
  for _, command in ipairs({ "PostilSend", "PostilTarget", "PostilNew", "PostilClearTarget", "PostilStatus" }) do
    assert(vim.fn.exists(":" .. command) == 2, command .. " was not registered")
  end

  -- tseting selection extraction
  local selection = require("postil.selection")
  assert(type(selection) == "table")

  local function assert_selection(actual, expected)
    assert(actual ~= nil, "expected a selection")
    assert(
      vim.deep_equal(actual, expected),
      string.format(
        "selection mismatch\nexpected: %s\nactual: %s",
        vim.inspect(expected),
        vim.inspect(actual)
      )
    )
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "alpha bravo",
    "charlie delta",
    "echo",
    "xy",
    "日本語abc",
    "日x",
    "abc"
  })

  -- characterwise selection
  local character = assert(selection.extract(
    bufnr,
    { line = 1, column = 7 },
    { line = 1, column = 11 },
    "v",
    "inclusive"
  ))
  assert_selection(character, {
    text = "bravo",
    start_line = 1,
    end_line = 1,
    selection_type = "character"
  })

  local multiline = assert(selection.extract(
    bufnr,
    { line = 1, column = 7 },
    { line = 2, column = 7 },
    "v",
    "inclusive"
  ))
  assert_selection(multiline, {
    text = "bravo\ncharlie",
    start_line = 1,
    end_line = 2,
    selection_type = "character"
  })

  local exclusive = assert(selection.extract(
    bufnr,
    { line = 1, column = 7 },
    { line = 1, column = 11 },
    "v",
    "exclusive"
  ))
  assert_selection(exclusive, {
    text = "brav",
    start_line = 1,
    end_line = 1,
    selection_type = "character"
  })

  -- linewise selections
  local linewise = assert(selection.extract(
    bufnr,
    { line = 1, column = 8 },
    { line = 2, column = 2 },
    "V",
    "inclusive"
  ))
  assert_selection(linewise, {
    text = "alpha bravo\ncharlie delta",
    start_line = 1,
    end_line = 2,
    selection_type = "line"
  })

  -- blockwise selection
  local blockwise = assert(selection.extract(
    bufnr,
    { line = 1, column = 1 },
    { line = 3, column = 4 },
    "\22",
    "inclusive"
  ))
  assert_selection(blockwise, {
    text = "alph\nchar\necho",
    start_line = 1,
    end_line = 3,
    selection_type = "block"
  })

  local short_blockwise = assert(selection.extract(
    bufnr,
    { line = 3, column = 3 },
    { line = 4, column = 6 },
    "\22",
    "inclusive"
  ))
  assert_selection(short_blockwise, {
    text = "ho\n",
    start_line = 3,
    end_line = 4,
    selection_type = "block",
  })

  -- reversed selections
  local reversed = assert(selection.extract(
    bufnr,
    { line = 2, column = 7 },
    { line = 1, column = 7 },
    "v",
    "inclusive"
  ))
  assert_selection(reversed, {
    text = "bravo\ncharlie",
    start_line = 1,
    end_line = 2,
    selection_type = "character",
  })

  local reversed_line = assert(selection.extract(
    bufnr,
    { line = 2, column = 2 },
    { line = 1, column = 8 },
    "V",
    "inclusive"
  ))
  assert_selection(reversed_line, {
    text = "alpha bravo\ncharlie delta",
    start_line = 1,
    end_line = 2,
    selection_type = "line"
  })

  local reversed_block = assert(selection.extract(
    bufnr,
    { line = 3, column = 4 },
    { line = 1, column = 1 },
    "\22",
    "inclusive"
  ))
  assert_selection(reversed_block, {
    text = "alph\nchar\necho",
    start_line = 1,
    end_line = 3,
    selection_type = "block"
  })

  -- unicode tests
  -- japanese chars take up 3 utf8 bytes
  local unicode = assert(selection.extract(
    bufnr,
    { line = 5, column = 1 },
    { line = 5, column = 4 },
    "v",
    "inclusive"
  ))
  assert_selection(unicode, {
    text = "日本",
    start_line = 5,
    end_line = 5,
    selection_type = "character"
  })

  local unicode_block = assert(selection.extract(
    bufnr,
    { line = 6, column = 1 },
    { line = 7, column = 1 },
    "\22",
    "inclusive"
  ))
  assert_selection(unicode_block, {
    text = "日\na",
    start_line = 6,
    end_line = 7,
    selection_type = "block",
  })

  -- invalid input
  local missing_mark, missing_mark_error = selection.extract(
    bufnr,
    { line = 0, column = 1 },
    { line = 1, column = 1 },
    "v",
    "inclusive"
  )
  assert(missing_mark == nil)
  assert(missing_mark_error == "start mark.line must be a positive integer")

  local invalid_mode, invalid_mode_error = selection.extract(
    bufnr,
    { line = 1, column = 1 },
    { line = 1, column = 2 },
    "?",
    "inclusive"
  )
  assert(invalid_mode == nil)
  assert(invalid_mode_error == "unsupported visual selection mode")

  -- formatting tests
  vim.api.nvim_buf_set_name(bufnr, repository_root .. "/lua/example.lua")
  vim.bo[bufnr].filetype = "lua"

  local context = assert(selection.build_context(
    character,
    "Explain this selection",
    bufnr,
    { ".git" }
  ))

  assert(context.instruction == "Explain this selection")
  assert(context.text == "bravo")
  assert(context.path == repository_root .. "/lua/example.lua")
  assert(context.relative_path == "lua/example.lua")
  assert(context.start_line == 1)
  assert(context.end_line == 1)
  assert(context.filetype == "lua")
  assert(context.root == repository_root)
  assert(context.selection_type == "character")
  assert(vim.fs.normalize(context.path) == vim.fs.normalize(repository_root .. "/lua/example.lua"))

  -- default formatting
  local message = assert(selection.format(context))
  local expected_message = table.concat({
    "File: lua/example.lua",
    "Line: 1",
    "Filetype: lua",
    "",
    "```lua",
    "bravo",
    "```",
    "",
    "Instruction: Explain this selection",
  }, "\n")

  assert(
    message == expected_message,
    string.format(
      "message mismatch\nexpected: %s\nactual: %s",
      vim.inspect(expected_message),
      vim.inspect(message)
    )
  )
  assert(message:sub(-1) ~= "\n")

  -- multiline ranges
  local multiline_context = assert(selection.build_context(
    multiline,
    "Explain both lines",
    bufnr,
    { ".git" }
  ))
  local multiline_message = assert(selection.format(multiline_context))
  assert(multiline_message:find("Lines: 1-2", 1, true), "expected multiline range")

  -- embedded backticks
  local fence_context = vim.deepcopy(context)
  fence_context.text = "before ``` after"
  local fence_message = assert(selection.format(fence_context))

  assert(fence_message:find(
    "````lua\nbefore ``` after\n````",
    1,
    true
  ), "expected a four-backtick fence")

  -- empty filetype
  local no_filetype_context = vim.deepcopy(context)
  no_filetype_context.filetype = ""
  local no_filetype_message = assert(selection.format(no_filetype_context))

  assert(not no_filetype_message:find("Filetype:", 1, true))
  assert(no_filetype_message:find("\n```\nbravo\n```", 1, true), "expected a fence without a language")

  -- custom formatter
  local custom_message = assert(selection.format(
    context,
    function(custom_context)
      return custom_context.instruction
          .. ": "
          .. custom_context.text
    end
  ))
  assert(custom_message == "Explain this selection: bravo")

  -- custom formatter error
  local failed_message, formatter_error = selection.format(context, function()
    error("formatter exploded")
  end)
  assert(failed_message == nil)
  assert(formatter_error == "custom formatter failed")

  -- non string formatter result
  local invalid_message, invalid_formatter_error = selection.format(context, function()
    return 42
  end)
  assert(invalid_message == nil)
  assert(invalid_formatter_error == "custom formatter must return a string")

  -- unnamed buffers
  local unnamed_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(unnamed_bufnr, 0, -1, false, { "unnamed content" })

  local unnamed_context = assert(selection.build_context({
    text = "unnamed",
    start_line = 1,
    end_line = 1,
    selection_type = "character"
  }, "Explain", unnamed_bufnr, { ".git" }))

  assert(unnamed_context.path == "[No Name]")
  assert(unnamed_context.relative_path == "[No Name]")
  assert(unnamed_context.root == vim.fs.abspath(vim.fn.getcwd()))

  -- cleanup
  vim.api.nvim_buf_delete(unnamed_bufnr, { force = true })
  vim.api.nvim_buf_delete(bufnr, { force = true })

  -- END OF TESTS
end, debug.traceback)

if not ok then
  io.stderr:write(tostring(err), "\n")
  vim.cmd("cquit 1")
else
  print("postil.nvim minimal checks passed")
  vim.cmd("quitall!")
end
