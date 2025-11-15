-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Encoding
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"

-- Display & UI
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

-- Indentation & Formatting
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.breakindent = true
vim.opt.smarttab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.expandtab = true
vim.opt.backspace = { "start", "eol", "indent" }
vim.opt.formatoptions:append({ "r" })

-- Search & Replace
vim.opt.hlsearch = true
vim.opt.inccommand = "split"
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Window & Split
vim.opt.splitkeep = "cursor"
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Input & Interaction
vim.opt.clipboard = "unnamedplus"
vim.opt.mouse = "a"

-- Performance & UX
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

-- File & Backup
vim.opt.shada = ""
vim.opt.backup = false
vim.opt.swapfile = false
vim.opt.undofile = true

-- Path & Ignore
vim.opt.path:append({ "**" })
vim.opt.wildignore:append({ "*/node_modules/*" })
