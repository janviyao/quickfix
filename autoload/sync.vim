" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

" Location of the grep utility
if !exists("quickfix_sync")
    let quickfix_sync = 1
endif

function! sync#read_dict(module, file, mode, line_num) abort
    let id_dic = getqflist({'id' : 0})
    if has_key(id_dic, 'id')
        let qfix_id = id_dic.id
    else
        let qfix_id = -1
    endif
    call PrintArgs("file", "read_dic", a:module, a:file, a:mode, a:line_num, "qfix_id=".qfix_id)
    
    if worker#worker_is_stop() == 1
        call PrintMsg("file", "worker stoped")
        return {}
    endif

    let work_index = worker#work_index_alloc(a:module, qfix_id)    
    call worker#work_fill(work_index, "read", a:mode, "dic", a:file, a:line_num, 0, {})
    while worker#work_status(work_index) != 2
        call PrintMsg("file", "read_dict sleep: 50ms")
        silent! execute 'sleep 50m'
    endwhile

    let data = worker#work_data(work_index, "dic")
    call PrintDict("file", "read_dic result", data) 
    return data
endfunction

function! sync#read_list(module, file, mode, line_num) abort
    let id_dic = getqflist({'id' : 0})
    if has_key(id_dic, 'id')
        let qfix_id = id_dic.id
    else
        let qfix_id = -1
    endif
    call PrintArgs("file", "read_list", a:module, a:file, a:mode, a:line_num, "qfix_id=".qfix_id)

    if worker#worker_is_stop() == 1
        call PrintMsg("file", "worker stoped")
        return {}
    endif

    let work_index = worker#work_index_alloc(a:module, qfix_id)    
    call worker#work_fill(work_index, "read", a:mode, "list", a:file, a:line_num, 0, [])
    while worker#work_status(work_index) != 2
        call PrintMsg("file", "read_list sleep: 50ms")
        silent! execute 'sleep 50m'
    endwhile
    
    let data = worker#work_data(work_index, "list")
    call PrintList("file", "read_list result", data) 
    return data 
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
