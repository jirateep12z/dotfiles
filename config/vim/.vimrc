set clipboard=unnamedplus,unnamed
set guifont=Hack\ Nerd\ Font\ Mono:h16
set viminfo=
set noerrorbells
set noundofile

nnoremap <silent> x "_x
nnoremap <silent> + <C-a>
nnoremap <silent> - <C-x>
nnoremap <silent> <C-a> gg<S-v>G

nnoremap <silent> te :tabedit<Enter>
nnoremap <silent> tc :tabclose<Enter>
nnoremap <silent> <Tab> :tabnext<Enter>
nnoremap <silent> <S-Tab> :tabprevious<Enter>

nnoremap <silent> ss :split<Enter>
nnoremap <silent> sv :vsplit<Enter>
nnoremap <silent> sh <C-w>h
nnoremap <silent> sj <C-w>j
nnoremap <silent> sk <C-w>k
nnoremap <silent> sl <C-w>l

nnoremap <silent> <Left> <C-w><
nnoremap <silent> <Down> <C-w>-
nnoremap <silent> <Up> <C-w>+
nnoremap <silent> <Right> <C-w>>

vnoremap <silent> J :m'>+1<Enter>gv
vnoremap <silent> K :m'<-2<Enter>gv

vnoremap <silent> < <gv
vnoremap <silent> > >gv

vnoremap <silent> ;nl :s/\n/\r\r/g<Enter>:noh<Enter>
vnoremap <silent> ;dl :s/^\s*$\n//g<Enter>:noh<Enter>
vnoremap <silent> ;uc gU
vnoremap <silent> ;lc gu
vnoremap <silent> ;st :sort i<Enter>
