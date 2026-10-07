local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(source, ":p:h:h")

vim.opt.runtimepath:prepend(root)
vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.signcolumn = "no"
vim.opt.laststatus = 2
vim.opt.showmode = false
vim.opt.termguicolors = true

vim.cmd.colorscheme("habamax")

require("postil").setup({
  prompt = "Postil Instruction",
})

vim.keymap.set("x", "<leader>ap", function()
  require("postil").preview_visual()
end, { desc = "Preview selection with Postil" })
