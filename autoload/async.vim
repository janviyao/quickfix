" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

" Location of the grep utility
if !exists("quickfix_async")
    let quickfix_async = 1
endif

function! async#write_dic(module, file, mode, dic_data) abort
    let id_dic = getqflist({'id' : 0})
    if has_key(l, 'id')
        let qfix_id = id_dic.id
    else
        let qfix_id = -1
    endif

    let data_index = worker#map_index(a:module, qfix_id)    
    call worker#fill_worker(data_index, "write", a:mode, "dic", a:file, -1, 0, a:dic_data)
endfunction

function! async#read_dic(module, file, mode, line_num, dic_data) abort
    let id_dic = getqflist({'id' : 0})
    if has_key(l, 'id')
        let qfix_id = id_dic.id
    else
        let qfix_id = -1
    endif

    let data_index = worker#map_index(a:module, qfix_id)    
    call worker#fill_worker(data_index, "read", a:mode, "dic", a:file, a:line_num, 0, a:dic_data)
endfunction

function! async#write_list(module, file, mode, dic_data) abort
    let id_dic = getqflist({'id' : 0})
    if has_key(l, 'id')
        let qfix_id = id_dic.id
    else
        let qfix_id = -1
    endif

    let data_index = worker#map_index(a:module, qfix_id)    
    call worker#fill_worker(data_index, "write", a:mode, "list", a:file, -1, 0, a:dic_data)
endfunction

function! async#read_list(module, file, mode, line_num, dic_data) abort
    let id_dic = getqflist({'id' : 0})
    if has_key(l, 'id')
        let qfix_id = id_dic.id
    else
        let qfix_id = -1
    endif

    let data_index = worker#map_index(a:module, qfix_id)    
    call worker#fill_worker(data_index, "read", a:mode, "list", a:file, a:line_num, 0, a:dic_data)
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
