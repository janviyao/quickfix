let g:quickfix_module = "init"
let g:quickfix_index_max = 50
let g:quickfix_timer = 0 

function! Quickfix_ctrl(module, mode)
    call quickfix#ctrl_main(a:module, a:mode)
endfunction

function! Quickfix_csfind(ccmd)
    call quickfix#csfind(a:ccmd)
endfunction

function! Quickfix_grep()
    call quickfix#grep_find()
endfunction

function! Quickfix_first_index(module)
    let id_dic = getqflist({'id' : 0})
    if has_key(id_dic, 'id')
        let qfix_id = id_dic.id
    else
        let qfix_id = -1
    endif

    let index_list = worker#map_list(a:module, qfix_id)
    if empty(index_list)
        return -1
    else
        return get(index_list, 0)
    endif
endfunction

function! Quickfix_rebuild(module, index_list)
    let id_dic = getqflist({'id' : 0})
    if has_key(id_dic, 'id')
        let qfix_id = id_dic.id
    else
        let qfix_id = -1
    endif
    call PrintArgs("file", "Quickfix_rebuild", a:module, "qfix_id=".qfix_id, a:index_list)

    let length = len(a:index_list)
    let index =0
    while index < length
        let item = str2nr(get(a:index_list, index))
        if index + 1 < length
            let next = index + 1 
            if index - 1 >= 0
                let prev = index - 1 
            else
                let prev = index
            endif
        else
            let next = index
            if index - 1 >= 0
                let prev = index - 1 
            else
                let prev = index
            endif
        endif
        call worker#map_set(a:module, qfix_id, item, prev, next, 0)

        let index += 1
    endwhile
endfunction

function! Quickfix_leave()
    let work_index = worker#work_index_get()
    while work_index >= 0
        call PrintMsg("file", "quickfix-worker[".work_index."] wait: 10ms")
        silent! execute 'sleep 10m'
        let work_index = worker#work_index_get()
    endwhile

    call PrintMsg("file", "quickfix-worker stop: ".g:quickfix_timer)
    call timer_stop(g:quickfix_timer) 
endfunction

"切换下一条quickfix记录
nnoremap <silent> <Leader>qf  :call quickfix#ctrl_main(g:quickfix_module, "next")<CR>
nnoremap <silent> <Leader>qb  :call quickfix#ctrl_main(g:quickfix_module, "prev")<CR>
nnoremap <silent> <Leader>qd  :call quickfix#ctrl_main(g:quickfix_module, "delete")<CR>
nnoremap <silent> <Leader>qrc :call quickfix#ctrl_main(g:quickfix_module, "recover")<CR>
nnoremap <silent> <Leader>qrf :call quickfix#ctrl_main(g:quickfix_module, "recover-next")<CR>
nnoremap <silent> <Leader>qrb :call quickfix#ctrl_main(g:quickfix_module, "recover-prev")<CR>

function! s:timer_run(timer_id)
    let work_index = worker#work_index_get()
    if work_index >= 0
        call worker#work_handler(work_index)
    endif
endfunction

let g:quickfix_timer = timer_start(50, "s:timer_run", {'repeat': -1})
