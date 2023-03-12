" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

" Location of the grep utility
if !exists("quickfix_async")
    let quickfix_async = 1
endif

function! async#write_dic(module, file, mode, dic_data) abort
    let id_dic = getqflist({'id' : 0})
    if has_key(id_dic, 'id')
        let qfix_id = id_dic.id
    else
        let qfix_id = -1
    endif
    call PrintArgs("file", "write_dic", a:module, a:file, a:mode, "qfix_id=".qfix_id)
    "call PrintDict("file", "arg[4]", a:dic_data) 
    "
    if worker#worker_is_stop() == 1
        call PrintMsg("file", "worker stoped")
        return
    endif

    let work_index = worker#work_index_alloc(a:module, qfix_id)    
    call worker#work_fill(work_index, "write", a:mode, "dic", a:file, -1, 0, a:dic_data)
endfunction

function! async#write_list(module, file, mode, dic_data) abort
    let id_dic = getqflist({'id' : 0})
    if has_key(id_dic, 'id')
        let qfix_id = id_dic.id
    else
        let qfix_id = -1
    endif
    call PrintArgs("file", "write_list", a:module, a:file, a:mode, "qfix_id=".qfix_id)
    "call PrintList("file", "arg[4]", a:dic_data) 
    
    if worker#worker_is_stop() == 1
        call PrintMsg("file", "worker stoped")
        return
    endif

    let work_index = worker#work_index_alloc(a:module, qfix_id)    
    call worker#work_fill(work_index, "write", a:mode, "list", a:file, -1, 0, a:dic_data)
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
