-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.colorcolumn = ""
vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.cmdheight = 1
vim.opt.laststatus = 3
vim.opt.showcmd = true
vim.opt.title = true

vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.breakindent = true
vim.opt.smarttab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.expandtab = true
vim.opt.backspace = { "start", "eol", "indent" }
vim.opt.formatoptions:append({ "r" })

vim.opt.hlsearch = true
vim.opt.inccommand = "split"
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.splitkeep = "cursor"
vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.clipboard = "unnamedplus"
vim.opt.mouse = "a"

vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
-- Raise the regex memory limit (KiB) to prevent E363 on large files or long lines
vim.opt.maxmempattern = 20000

vim.opt.shada = ""
vim.opt.backup = false
vim.opt.swapfile = false
vim.opt.undofile = true

vim.opt.path:append({ "**" })
vim.opt.wildignore:append({ "*/node_modules/*" })
