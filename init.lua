
-- Very basic Neovim config (init.lua)

vim.scriptencoding = "utf-8"

vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"
vim.opt.fileencodings = "ucs-bom,utf8,prc"

vim.opt.ttyfast = true

-- Disable bells
vim.opt.visualbell = false
vim.opt.errorbells = false
vim.opt.belloff = "all"

vim.opt.showcmd = true
vim.opt.compatible = false

-- Filetype
vim.cmd("filetype plugin on")
vim.cmd("filetype indent off")

vim.g.mapleader = ","

vim.opt.number = true
vim.opt.ruler = true

-- Tab settings
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smarttab = true
vim.opt.autoindent = true

-- Highlight trailing whitespace
vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "red" })

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "red" })
  end,
})

-- Trailing whitespace matching
vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
  pattern = "*",
  callback = function()
    vim.fn.matchadd("ExtraWhitespace", [[\s\+$]])
  end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
  pattern = "*",
  callback = function()
    vim.fn.matchadd("ExtraWhitespace", [[\s\+\%#\@<!$]])
  end,
})

-- ==================== Keymaps ====================

-- Helper function (this is the nice "map" you're asking about)
local map = function(mode, lhs, rhs, opts)
  opts = opts or { noremap = true, silent = true }
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- Buffers
map("n", "<Leader>J", ":bnext<CR>")
map("n", "<Leader>K", ":bprev<CR>")

-- Windows
map("n", "<Leader>k", "<C-w>k")
map("n", "<Leader>j", "<C-w>j")
map("n", "<Leader>h", "<C-w>h")
map("n", "<Leader>l", "<C-w>l")

-- Delete trailing whitespace
map("n", "<Leader>d", ":%s/\\s\\+$//e<CR>")
