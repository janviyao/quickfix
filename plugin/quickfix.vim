let g:quickfix_module = "init"
let g:quickfix_index_max = 50

function! s:do_buf_enter()
    if &buftype == "quickfix"
        let s:qfix_opened = bufnr("$")
    endif
endfunction

function! s:do_buf_leave()
    if &buftype == "quickfix"
        let s:qfix_pick = getqflist({'idx' : 0}).idx
    endif
endfunction

"跟踪quickfix窗口状态
augroup QFixToggle
    autocmd!

    autocmd BufWinEnter * call s:do_buf_enter()
    autocmd BufWinLeave * call s:do_buf_leave()
    autocmd BufLeave * call s:do_buf_leave()

    "不在quickfix窗内移动，则关闭quickfix窗口
    autocmd CursorMoved * if exists("s:qfix_opened") && &buftype != 'quickfix' | call qfix#ctrl_main(g:quickfix_module, "close") | endif
augroup END

function! quick_ctrl(module, mode)
    call qfix#ctrl_main(a:module, a:mode)
endfunction

function! quick_csfind(ccmd)
    call qfix#csfind(a:ccmd)
endfunction

function! quick_grep()
    call qfix#grep_find()
endfunction

"切换下一条quickfix记录
nnoremap <silent> <Leader>qf  :call qfix#ctrl_main(g:quickfix_module, "next")<CR>
nnoremap <silent> <Leader>qb  :call qfix#ctrl_main(g:quickfix_module, "prev")<CR>
nnoremap <silent> <Leader>qd  :call qfix#ctrl_main(g:quickfix_module, "delete")<CR>
nnoremap <silent> <Leader>qrc :call qfix#ctrl_main(g:quickfix_module, "recover")<CR>
nnoremap <silent> <Leader>qrf :call qfix#ctrl_main(g:quickfix_module, "recover-next")<CR>
nnoremap <silent> <Leader>qrb :call qfix#ctrl_main(g:quickfix_module, "recover-prev")<CR>

function! s:timer_run(timer_id)
    let data_index = worker#get_data_index()
    call PrintMsg("file", "timer data_index: ".data_index)

    if data_index >= 0
        call worker#data_handle(data_index)
    endif
endfunction

let s:timer_id = timer_start(200, "s:timer_run", {'repeat': -1})
