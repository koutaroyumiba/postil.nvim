-- public module returned by require("postil")
local M = {}

function M.setup(opts)
  opts = opts or {}

  if type(opts) ~= "table" then
    error("postil.nvim: setup options must be a table")
  end

  return true
end

return M
