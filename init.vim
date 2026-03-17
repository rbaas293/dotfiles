" Very basic vim config
scriptencoding utf-8
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=ucs-bom,uft8,prc
set ttyfast
" Disable bell
set visualbell                  " Disable visual bell
set noerrorbells                " Disable error bell
set showcmd
set nocompatible
filetype off

filetype plugin on          " keep plugin for syntax/ft detection
filetype indent off         " ← disable indent scripts that override tabs


let mapleader = ","

set nu
set ruler

" Tab stuff, sometime you need to create and throw the below into a after file as nvim overides these
" file location: ~/.config/nvim/after/plugin/override-indent.vim
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab


set smarttab            " <Tab> in front of line uses shiftwidth, not tabstop/softtabstop
set autoindent          " (or smartindent / cindent depending on file type)

" Highlight trailing whitespace
highlight ExtraWhitespace ctermbg=red guibg=red
autocmd ColorScheme * highlight ExtraWhitespace guibg=red
autocmd BufEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhiteSpace /\s\+$/

""" Window/Buffer movement
" Buffers
nmap <Leader>J :bnext<CR>
nmap <Leader>K :bprev<CR>
" Windows
nmap <Leader>k :wincmd k<CR>
nmap <Leader>j :wincmd j<CR>
nmap <Leader>h :wincmd h<CR>
nmap <Leader>l :wincmd l<CR>

" Delete extra whitespace
nnoremap <Leader>d :%s/\s\+$//<CR>
