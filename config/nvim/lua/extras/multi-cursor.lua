return {
    "mg979/vim-visual-multi",
    init = function()
        -- Map only the commands in use so VM leaves other keys alone
        vim.g.VM_default_mappings = 0
        -- PowerToys remaps LAlt+J/K to Down/Up, so Alt+Shift+j/k arrive as <S-Down>/<S-Up>
        vim.g.VM_maps = {
            ["Find Under"] = "<C-n>",
            ["Find Subword Under"] = "<C-n>",
            ["Add Cursor Down"] = "<S-Down>",
            ["Add Cursor Up"] = "<S-Up>",
            ["Select All"] = "<M-n>",
            ["Visual All"] = "<M-n>",
        }
    end,
}
