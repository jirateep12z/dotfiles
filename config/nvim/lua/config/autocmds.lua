-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

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

local trim_group = vim.api.nvim_create_augroup("TrimWhitespace", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
    group = trim_group,
    pattern = "*",
    command = "%s/\\s\\+$//e",
})

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
