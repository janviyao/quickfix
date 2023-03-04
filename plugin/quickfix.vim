let g:quickfix_module = "init"
let g:quickfix_index_max = 50

function! s:DoBufEnter()
    if &buftype == "quickfix"
        let s:qfix_opened = bufnr("$")
    endif
endfunction

function! s:DoBufLeave()
    if &buftype == "quickfix"
        let s:qfix_pick = getqflist({'idx' : 0}).idx
    endif
endfunction

"跟踪quickfix窗口状态
augroup QFixToggle
    autocmd!

    autocmd BufWinEnter * call s:DoBufEnter()
    autocmd BufWinLeave * call s:DoBufLeave()
    autocmd BufLeave * call s:DoBufLeave()

    "不在quickfix窗内移动，则关闭quickfix窗口
    autocmd CursorMoved * if exists("s:qfix_opened") && &buftype != 'quickfix' | call qfix#QuickCtrl(g:quickfix_module, "close") | endif
augroup END

"切换下一条quickfix记录
nnoremap <silent> <Leader>qf  :call qfix#QuickCtrl(g:quickfix_module, "next")<CR>
nnoremap <silent> <Leader>qb  :call qfix#QuickCtrl(g:quickfix_module, "prev")<CR>
nnoremap <silent> <Leader>qd  :call qfix#QuickCtrl(g:quickfix_module, "delete")<CR>
nnoremap <silent> <Leader>qrc :call qfix#QuickCtrl(g:quickfix_module, "recover")<CR>
nnoremap <silent> <Leader>qrf :call qfix#QuickCtrl(g:quickfix_module, "recover-next")<CR>
nnoremap <silent> <Leader>qrb :call qfix#QuickCtrl(g:quickfix_module, "recover-prev")<CR>
