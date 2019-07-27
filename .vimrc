scriptencoding utf-8
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=ucs-bom,uft8,prc

set nocompatible
filetype off
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'
Plugin 'vim-scripts/indentpython.vim'
Plugin 'tpope/vim-fugitive'
Plugin 'airblade/vim-gitgutter'
Bundle 'Valloric/YouCompleteMe'
Plugin 'vim-syntastic/syntastic'
Plugin 'nvie/vim-flake8'
Plugin 'jnurmine/Zenburn'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'altercation/vim-colors-solarized'
Plugin 'joshdick/onedark.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'jistr/vim-nerdtree-tabs'
Plugin 'honza/vim-snippets'
Plugin 'SirVer/ultisnips'
Plugin 'skywind3000/asyncrun.vim'

call vundle#end()

filetype plugin indent on

set termguicolors
let g:airline#extensions#ycm#enabled=1
let g:airline_powerline_fonts=1
let g:airline#extensions#tabline#enabled=1
" colorscheme koehler
let g:airline_theme='cobalt2'
set laststatus=2
set ttimeoutlen=50
set t_Co=256






syntax on
set splitbelow
set splitright
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

map <F6> :NERDTreeToggle<CR>
"set showtabline=2
" set timeoutlen=1000 ttimeoutlen=10


colorscheme onedark

set nu
set tabstop=4
set softtabstop=4 
set shiftwidth=4 
"let g:UltiSnipsExpandTrigger=","
"let g:UltiSnipsJumpForwardTrigger="<tab>"
"let g:UltiSnipsJumpBackwardTrigger="<s-tab>"

let g:ycm_collect_identifiers_from_tags_files = 1 " Let YCM read tags from Ctags file
let g:ycm_use_ultisnips_completer = 1 " Default 1, just ensure
let g:ycm_seed_identifiers_with_syntax = 1 " Completion for programming language's keyword
let g:ycm_complete_in_comments = 1 " Completion in comments
let g:ycm_complete_in_strings = 1 " Completion in string
let g:ycm_autoclose_preview_window_after_completion=1
let g:ycm_min_num_identifier_candidate_chars = 1
let g:ycm_min_num_of_chars_for_completion = 1
let g:ycm_max_num_identifier_candidates = 0

"let g:ycm_key_list_select_completion = ['<C-j>', '<Down>']
"let g:ycm_key_list_previous_completion = ['<C-k>', '<Up>']
let g:ycm_key_list_select_completion = ['<tab>', '<Down>']
let g:ycm_key_list_previous_completion = ['<s-tab>', '<Up>']
let g:ycm_global_ycm_extra_conf = "~/.vim/.ycm_extra_conf.py"
map <F3> :YcmCompleter GoTo<CR>
"map <leader>g  : YcmCompleter GoToDefinitionElseDeclaration<CR>
let mapleader = ","
let python_highlight_all=1

autocmd BufNewFile,BufRead *.py
	\ set textwidth=79 |
	\ set colorcolumn=80 |
	\ set expandtab |
	\ set autoindent |
	\ set fileformat=unix |
	\ let g:ycm_python_binary_path = 'python' |
	\ nnoremap <buffer> <F5> :exec '!python -i' shellescape(@%, 1)<cr> |
	\ nnoremap <buffer> <F4> :exec '!python -d' shellescape(@%, 1)<cr>

"autocmd filetype cpp nnoremap <F4> :w <bar> exec '!g++ '.shellescape('%').' -o '.shellescape('%:r').' && ./'.shellescape('%:r')<CR>
autocmd BufNewFile,BufRead *.cpp,*.cxx,*.c,*.h,*.hpp,*.hxx
	\ set expandtab |
	\ set autoindent |
	\ set colorcolumn=110 |
	\ let &path.="src/include,/usr/include/AL," |
	\ nnoremap <buffer> <F5> :AsyncRun make -j8<cr> 

" Borrowing airline's example
function! AirlineThemePatch(palette)
	let a:palette.accents.running = [ '', '', '', '', '']
	let a:palette.accents.success = [ '#00ff00', '', 'green', '', '']
	let a:palette.accents.failure = [ '#ff0000', '', 'red', '', '']
endfunction
let g:airline_theme_patch_func = 'AirlineThemePatch'

let g:async_status_old = ''
function! Get_asyncrun_running()
	let async_status = g:asyncrun_status
	if async_status != g:async_status_old
		if async_status == 'running'
			call airline#parts#define_accent('asyncrun_status', 'running')
		elseif async_status == 'success'
			call airline#parts#define_accent('asyncrun_status', 'success')
		elseif async_status == 'failure'
			call airline#parts#define_accent('asyncrun_status', 'failure')
		endif
		
		let g:airline_section_x = airline#section#create(['asyncrun_status'])
		AirlineRefresh
		let g:async_status_old = async_status
	endif
	return async_status
endfunction

call airline#parts#define_function('asyncrun_status', 'Get_asyncrun_running')
let g:airline_section_x = airline#section#create(['asyncrun_status'])





