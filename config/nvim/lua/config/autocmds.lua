-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Highlight on yank
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
    group = highlight_group,
    pattern = "*",
    callback = function()
        vim.highlight.on_yank({
            higroup = "IncSearch",
            timeout = 200,
        })
    end,
})

-- Remove trailing whitespace on save
local trim_group = vim.api.nvim_create_augroup("TrimWhitespace", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
    group = trim_group,
    pattern = "*",
    command = "%s/\\s\\+$//e",
})

-- Open an empty buffer instead of a directory listing when started with a directory
local directory_start_group = vim.api.nvim_create_augroup("DirectoryStart", { clear = true })
vim.api.nvim_create_autocmd("VimEnter", {
    group = directory_start_group,
    once = true,
    callback = function()
        local directory_buffer = vim.api.nvim_get_current_buf()
        if vim.fn.argc(-1) ~= 1 or vim.fn.isdirectory(vim.api.nvim_buf_get_name(directory_buffer)) == 0 then
            return
        end
        vim.cmd.enew()
        vim.api.nvim_buf_delete(directory_buffer, { force = true })
    end,
})
