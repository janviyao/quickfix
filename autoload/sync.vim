" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

" Location of the grep utility
if !exists("quickfix_sync")
    let quickfix_sync = 1
endif

function! sync#read_dic(module, file, mode, line_num) abort
    let id_dic = getqflist({'id' : 0})
    if has_key(l, 'id')
        let qfix_id = id_dic.id
    else
        let qfix_id = -1
    endif

    let data_index = worker#map_index(a:module, qfix_id)    

    call worker#fill_worker(data_index, "read", a:mode, "dic", a:file, a:line_num, 0, {})
    while worker#work_status() != 2
        sleep 1
    endwhile

    let data = worker#work_data(data_index, "dic")
    return data
endfunction

function! sync#read_list(module, file, mode, line_num) abort
    let id_dic = getqflist({'id' : 0})
    if has_key(l, 'id')
        let qfix_id = id_dic.id
    else
        let qfix_id = -1
    endif

    let data_index = worker#map_index(a:module, qfix_id)    

    call worker#fill_worker(data_index, "read", a:mode, "list", a:file, a:line_num, 0, [])
    while worker#work_status() != 2
        sleep 1
    endwhile
    
    let data = worker#work_data(data_index, "list")
    return data 
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save

