set nocompatible              " be iMproved
filetype off                  " required!
set ic
set noswapfile

" Load Vundle
set rtp+=~/.vim/bundle/vundle
call vundle#rc()

" let Vundle manage Vundle
Bundle 'gmarik/vundle'

" vim-script repos
Bundle 'LargeFile'

" Vim UI
Bundle 'bling/vim-airline'
Bundle 'w0ng/vim-hybrid'

Bundle 'tpope/vim-rails'
Bundle 'tpope/vim-eunuch'
Bundle 'tpope/vim-sensible'
Bundle 'tpope/vim-fugitive'
Bundle 'tpope/vim-unimpaired'
Bundle 'tpope/vim-dispatch'
Bundle 'tpope/vim-surround'
Bundle 'tpope/vim-vinegar'
Bundle 'tpope/vim-endwise'

Bundle 'kien/ctrlp.vim'
Bundle 'SirVer/ultisnips'
Bundle 'honza/vim-snippets'
Bundle 'slim-template/vim-slim'

" Other Config
filetype plugin indent on     " required!

set autoread
set number
set shiftwidth=2 expandtab tabstop=2 softtabstop=2
set hlsearch

" Turn on plugins
let g:hybrid_use_Xresources = 1
colorscheme hybrid

let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<tab>"
let g:UltiSnipsJumpBackwardTrigger="<s-tab>"

" UI config
let &t_Co=256
syntax on
set clipboard=unnamed

augroup VimrcEx
  au!

  autocmd BufWritePost $MYVIMRC so $MYVIMRC
augroup END
