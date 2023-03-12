" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

" Location of the grep utility
if !exists("quickfix_map")
    let quickfix_map = 1
else
    let quickfix_map += 1
endif

let s:map_table = {
            \   'csfind' : [
            \   {
            \     'qfix_id'   : 0,
            \     'qfix_tag'  : '',
            \     'work_idx'  : 0,
            \     'map_prev'  : 0,
            \     'map_next'  : 0,
            \     'invalid'   : 1
            \   }
            \   ],
            \   'grep' : [
            \   {
            \     'qfix_id'   : 0,
            \     'qfix_tag'  : '',
            \     'work_idx'  : 0,
            \     'map_prev'  : 0,
            \     'map_next'  : 0,
            \     'invalid'   : 1
            \   }
            \   ]
            \ }

function! map#work_index(module, qfix_id) abort
    let info_list = s:map_table[a:module]

    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["invalid"] == 1
            call map#set(a:module, a:qfix_id, item["work_idx"], item["map_prev"], item["map_next"], 0)
            return item["work_idx"]
        endif
        let index += 1
    endwhile

    return -1
endfunction

function! map#set(module, qfix_id, work_idx, map_prev, map_next, invalid) abort
    "call PrintArgs("file", "map_set", "module=".a:module, "qfix_id=".a:qfix_id, "work_idx=".a:work_idx, "map_prev=".a:map_prev, "map_next=".a:map_next, "invalid=".a:invalid)
    let info_list = s:map_table[a:module]

    let length = len(info_list)
    let index =0
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["work_idx"] == a:work_idx 
            let item["qfix_id"]   = a:qfix_id
            let item["work_idx"] = a:work_idx
            let item["map_prev"]  = a:map_prev
            let item["map_next"]  = a:map_next
            let item["invalid"]   = a:invalid
            call PrintDict("file", "map_table[".index."]", item)
            return index
        endif
        let index += 1
    endwhile
    
    let info_dic = {}
    let info_dic["qfix_id"]   = a:qfix_id
    let info_dic["work_idx"] = a:work_idx
    let info_dic["map_prev"]  = a:map_prev
    let info_dic["map_next"]  = a:map_next
    let info_dic["invalid"]   = a:invalid

    call insert(info_list, info_dic, length)
    call PrintDict("file", "map_table[".length."]", info_dic)
    return length
endfunction

function! map#delete(module, qfix_id, work_idx) abort
    call PrintArgs("file", "map_del", a:module, a:qfix_id, a:work_idx)
    let info_list = s:map_table[a:module]

    let length = len(info_list)
    let index =0
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["map_next"] == a:work_idx 
           let item["map_next"] = -1
           break
        endif
        let index += 1
    endwhile

    let index =0
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["work_idx"] == a:work_idx 
            call remove(info_list, index)
            call async#map_del(a:module, a:qfix_id, item["map_next"])
            return
        endif
        let index += 1
    endwhile
endfunction

function! map#next(module, qfix_id, work_index) abort
    call PrintArgs("file", "map_next", a:module, a:qfix_id, a:work_index)
    let info_list = s:map_table[a:module]

    let map_next = -1
    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["work_idx"] == a:work_index 
            let map_next = item["map_next"] 
            break
        endif
        let index += 1
    endwhile

    if map_next >= 0
        let data_next = info_list[map_next]["work_idx"]
        return data_next
    else
        call PrintMsg("error", "map_next module: ".a:module." qfix_id: ".a:qfix_id." work_idx: ".a:work_idx." fail")
        return -1
    endif
endfunction

function! map#prev(module, qfix_id, work_index) abort
    call PrintArgs("file", "map_prev", a:module, a:qfix_id, a:work_index)
    let info_list = s:map_table[a:module]

    let map_prev = -1
    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["work_idx"] == a:work_index 
            let map_prev = item["map_prev"] 
            break
        endif
        let index += 1
    endwhile
    
    if map_prev >= 0
        let data_prev = info_list[map_prev]["work_idx"]
        return data_prev
    else
        call PrintMsg("error", "map_prev module: ".a:module." qfix_id: ".a:qfix_id." work_idx: ".a:work_idx." fail")
        return -1
    endif
endfunction

function! map#list(module, qfix_id) abort
    call PrintArgs("file", "map_list", a:module, a:qfix_id)
    let info_list = s:map_table[a:module]

    let first_index = -1
    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["map_prev"] == index
            if item["invalid"] == 0 
                let first_index = index
                break
            endif
        endif
        let index += 1
    endwhile
    
    let res_list = []
    if first_index >= 0
        let cur_index = first_index
        call add(res_list, cur_index)
        let data_next = map#next(a:module, a:qfix_id, cur_index)
        while data_next >= 0
            call add(res_list, data_next)
            let data_next = map#next(a:module, a:qfix_id, data_next)
        endwhile
    endif

    call PrintMsg("file", "map_list module: ".a:module." qfix_id: ".a:qfix_id." list: ".string(res_list))
    return res_list
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
