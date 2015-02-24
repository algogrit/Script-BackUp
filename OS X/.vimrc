set nocompatible              " be iMproved
filetype off                  " required!
set ic

" Load Vundle
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#rc()

" let Vundle manage Vundle
Bundle 'gmarik/vundle'

" vim-script repos
Bundle 'LargeFile'

" Vim UI
Bundle 'bling/vim-airline'
Bundle 'w0ng/vim-hybrid'
Bundle 'scrooloose/nerdtree'

" Other Config
filetype plugin indent on     " required!

set relativenumber
set number

" Turn on plugins
let g:airline#extensions#tabline#enabled = 1
let g:hybrid_use_Xresources = 1
colorscheme hybrid

" UI config
let &t_Co=256
syntax on
set clipboard=unnamed
