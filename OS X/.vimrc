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

Bundle 'tpope/vim-rails'
Bundle 'tpope/vim-sensible'
Bundle 'tpope/vim-fugitive'
Bundle 'tpope/vim-unimpaired'

" Other Config
filetype plugin indent on     " required!

set relativenumber
set number
set shiftwidth=2 expandtab tabstop=2 softtabstop=2

" Turn on plugins
let g:airline#extensions#tabline#enabled = 1
let g:hybrid_use_Xresources = 1
colorscheme hybrid

" UI config
let &t_Co=256
syntax on
set clipboard=unnamed
