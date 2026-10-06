if vim.g.loaded_postil == 1 then
  return
end

vim.g.loaded_postil = 1

require("postil")._register_commands()
