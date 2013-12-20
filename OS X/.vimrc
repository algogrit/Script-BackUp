set nocompatible              " be iMproved
filetype off                  " required!

" Load Vundle
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" let Vundle manage Vundle
Bundle 'gmarik/vundle'

" vim-script repos
Bundle 'LargeFile'

" Vim UI
Bundle 'bling/vim-airline'
" Bundle 'chriskempson/tomorrow-theme', {'rtp': 'vim/'}
Bundle 'w0ng/vim-hybrid'
Bundle 'scrooloose/nerdtree'

" Other Config
filetype plugin indent on     " required!

" Configure line numbers
autocmd FocusLost * :set number
autocmd InsertEnter * :set number
autocmd InsertLeave * :set relativenumber
autocmd CursorMoved * :set relativenumber

" Turn on plugins
let g:airline#extensions#tabline#enabled = 1
let g:hybrid_use_Xresources = 1
colorscheme hybrid

" UI config
let &t_Co=256
syntax on
