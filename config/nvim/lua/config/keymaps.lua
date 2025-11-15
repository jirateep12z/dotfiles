-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap

-- Delete & Increment/Decrement
keymap.set("n", "x", '"_x', { noremap = true, silent = true })
keymap.set("n", "+", "<C-a>", { noremap = true, silent = true })
keymap.set("n", "-", "<C-x>", { noremap = true, silent = true })
keymap.set("n", "<C-a>", "gg<S-v>G", { noremap = true, silent = true })

-- Tab Navigation
keymap.set("n", "te", ":tabedit<CR>", { noremap = true, silent = true })
keymap.set("n", "tc", ":tabclose<CR>", { noremap = true, silent = true })
keymap.set("n", "<Tab>", ":tabnext<CR>", { noremap = true, silent = true })
keymap.set("n", "<S-Tab>", ":tabprevious<CR>", { noremap = true, silent = true })

-- Window Management
keymap.set("n", "ss", ":split<CR>", { noremap = true, silent = true })
keymap.set("n", "sv", ":vsplit<CR>", { noremap = true, silent = true })
keymap.set("n", "sh", "<C-w>h", { noremap = true, silent = true })
keymap.set("n", "sj", "<C-w>j", { noremap = true, silent = true })
keymap.set("n", "sk", "<C-w>k", { noremap = true, silent = true })
keymap.set("n", "sl", "<C-w>l", { noremap = true, silent = true })

-- Window Resizing
keymap.set("n", "<Left>", "<C-w><", { noremap = true, silent = true })
keymap.set("n", "<Down>", "<C-w>-", { noremap = true, silent = true })
keymap.set("n", "<Up>", "<C-w>+", { noremap = true, silent = true })
keymap.set("n", "<Right>", "<C-w>>", { noremap = true, silent = true })

-- Visual Mode - Move Lines
keymap.set("v", "J", ":m'>+1<CR>gv", { noremap = true, silent = true })
keymap.set("v", "K", ":m'<-2<CR>gv", { noremap = true, silent = true })

-- Visual Mode - Indenting
keymap.set("v", "<", "<gv", { noremap = true, silent = true })
keymap.set("v", ">", ">gv", { noremap = true, silent = true })

-- Visual Mode - Text Manipulation
keymap.set("v", ";nl", ":s/\\n/\\r\\r/g<CR>:noh<CR>", { noremap = true, silent = true })
keymap.set("v", ";dl", ":s/^\\s*$\\n//g<CR>:noh<CR>", { noremap = true, silent = true })
keymap.set("v", ";uc", "gU", { noremap = true, silent = true })
keymap.set("v", ";lc", "gu", { noremap = true, silent = true })
keymap.set("v", ";st", ":sort i<CR>", { noremap = true, silent = true })
