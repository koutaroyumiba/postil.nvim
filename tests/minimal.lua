local source = debug.getinfo(1, "S").source:sub(2)
local repository_root = vim.fn.fnamemodify(source, ":p:h:h")

vim.opt.runtimepath:prepend(repository_root)

local ok, err = xpcall(function()
  local postil = require("postil")

  assert(type(postil) == "table")
  assert(type(postil.setup) == "function")
  assert(postil.setup() == true)

  assert(type(require("postil.selection")) == "table")
  assert(type(require("postil.tmux")) == "table")
end, debug.traceback)

if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
else
  print("postil.nvim minimal checks passed")
  vim.cmd("quitall!")
end
