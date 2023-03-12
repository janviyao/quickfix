" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

" Location of the grep utility
if !exists("quickfix_worker")
    let quickfix_worker = 1
endif

let s:map_table = {
            \   'csfind' : [
            \   {
            \     'qfix_id'   : 0,
            \     'work_idx'  : 0,
            \     'map_prev'  : 0,
            \     'map_next'  : 0,
            \     'invalid'   : 1
            \   }
            \   ],
            \   'grep' : [
            \   {
            \     'qfix_id'   : 0,
            \     'work_idx'  : 0,
            \     'map_prev'  : 0,
            \     'map_next'  : 0,
            \     'invalid'   : 1
            \   }
            \   ]
            \ }

let s:work_table = [
            \   {
            \     'cmd_time' : 0,
            \     'cmd_type' : 'write',
            \     'cmd_mode' : 'b',
            \     'line_nr'  : 0,
            \     'dat_type' : 'list',
            \     'filepath' : '',
            \     'dat_list' : [],
            \     'dat_dict' : {},
            \     'status'   : 2
            \   },
            \   {
            \     'cmd_time' : 0,
            \     'cmd_type' : 'read',
            \     'cmd_mode' : 'b',
            \     'line_nr'  : 0,
            \     'dat_type' : 'dict',
            \     'filepath' : '',
            \     'dat_list' : [],
            \     'dat_dict' : {},
            \     'status'   : 2
            \   },
            \   {
            \     'cmd_time' : 0,
            \     'cmd_type' : 'delete',
            \     'cmd_mode' : '',
            \     'line_nr'  : 0,
            \     'dat_type' : '',
            \     'filepath' : '',
            \     'dat_list' : [],
            \     'dat_dict' : {},
            \     'status'   : 2
            \   }
            \ ]

let s:worker_table_index = 0

function! worker#map_set(module, qfix_id, work_idx, map_prev, map_next, invalid) abort
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

function! worker#map_del(module, qfix_id, work_idx) abort
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

function! worker#map_next(module, qfix_id, work_index) abort
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

function! worker#map_prev(module, qfix_id, work_index) abort
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

function! worker#map_list(module, qfix_id) abort
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
        let data_next = worker#map_next(a:module, a:qfix_id, cur_index)
        while data_next >= 0
            call add(res_list, data_next)
            let data_next = worker#map_next(a:module, a:qfix_id, data_next)
        endwhile
    endif

    call PrintMsg("file", "map_list module: ".a:module." qfix_id: ".a:qfix_id." list: ".string(res_list))
    return res_list
endfunction

function! worker#work_index_alloc(module, qfix_id) abort
    "call PrintArgs("file", "work_index_alloc", "module=".a:module, "qfix_id=".a:qfix_id)
    let info_list = s:map_table[a:module]

    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["invalid"] == 1
            call worker#map_set(a:module, a:qfix_id, item["work_idx"], item["map_prev"], item["map_next"], 0)
            return item["work_idx"]
        endif
        let index += 1
    endwhile
    
    let work_index = s:worker_table_index
    let s:worker_table_index += 1
    if s:worker_table_index > 5000
        let s:worker_table_index = 0
    endif

    call worker#map_set(a:module, a:qfix_id, work_index, length, length, 0)
    return work_index
endfunction

function! worker#work_index_get() abort
    let length = len(s:work_table)
    let index =0
    while index < length
        let item = get(s:work_table, index)
        if has_key(item, "status")
            if item["status"] == 0 
                call PrintMsg("file", "******worker_index******: ".index)
                return index
            endif
        endif
        let index += 1
    endwhile

    return -1
endfunction

function! worker#work_status(work_index) abort
    let info_dic = s:work_table[a:work_index]
    return info_dic["status"]
endfunction

function! worker#work_data(work_index, dat_type) abort
    let info_dic = s:work_table[a:work_index]

    if a:dat_type == "dict"
        return info_dic["dat_dict"]
    elseif a:dat_type == "list"
        return info_dic["dat_list"]
    endif
endfunction

function! worker#work_fill(work_index, cmd_type, cmd_mode, dat_type, filepath, line_nr, status, data) abort
    call PrintArgs("file", "work_fill", a:work_index, a:cmd_type, a:cmd_mode, a:dat_type, a:filepath, a:line_nr, a:status)
    if !empty(a:data)
        if a:dat_type == "dict"
            call PrintDict("file", "arg[8] dict", a:data) 
        elseif a:dat_type == "list"
            call PrintList("file", "arg[8] list", a:data) 
        endif
    endif

    if a:work_index >= len(s:work_table)
        call insert(s:work_table, {}, a:work_index)
    endif

    let info_dic = s:work_table[a:work_index]

    let info_dic['cmd_time'] = localtime() 
    let info_dic["cmd_type"] = a:cmd_type
    let info_dic["cmd_mode"] = a:cmd_mode
    let info_dic["dat_type"] = a:dat_type
    let info_dic["filepath"] = a:filepath
    let info_dic["line_nr"]  = a:line_nr
    let info_dic["dat_dict"] = {}
    let info_dic["dat_list"] = []

    if a:dat_type == "dict"
        call extend(info_dic["dat_dict"], a:data)
    elseif a:dat_type == "list"
        call extend(info_dic["dat_list"], a:data)
    endif
    
    "star to handle work
    let info_dic["status"] = a:status
endfunction

function! worker#worker_is_stop()
    let info = get(timer_info(g:quickfix_timer), 0) 
    "call PrintMsg("file", "timer: ".string(info)) 
    if info["paused"] == 1
        return 1
    endif
    return 0
endfunction

function! worker#work_newest(cmd_type, dat_type, filepath) abort
    "call PrintArgs("file", "work_fill", a:work_index, a:cmd_type, a:cmd_mode, a:dat_type, a:filepath)
    let time_newest = 0
    let res_index = -1

    let length = len(s:work_table)
    let index =0
    while index < length
        let item = get(s:work_table, index)
        if has_key(item, "status")
            if item["status"] == 2 && item["cmd_type"] == a:cmd_type 
                if item["dat_type"] == a:dat_type && item["filepath"] == a:filepath 
                    if item["cmd_time"] > time_newest 
                        let time_newest = item["cmd_time"]
                        let res_index = index
                    endif
                endif
            endif
        endif
        let index += 1
    endwhile
    return res_index 
endfunction

function! worker#work_handler(work_index) abort
    call PrintArgs("file", "work_handler", a:work_index)
    let info_dic = s:work_table[a:work_index]
    let info_dic['status'] = 1
    call PrintDict("file", "work_table[".a:work_index."]", info_dic)

    let cmd_type = info_dic['cmd_type'] 
    let cmd_mode = info_dic['cmd_mode'] 
    let dat_type = info_dic['dat_type'] 
    let filepath = info_dic['filepath'] 
    let line_nr  = info_dic['line_nr'] 

    if cmd_type == "write"
        if dat_type == "list"
            let data_list = info_dic['dat_list'] 
            for item in data_list
                call writefile([string(item)], filepath, cmd_mode)
            endfor
        elseif dat_type == "dict"
            let data_dic  = info_dic['dat_dict'] 
            call writefile([string(data_dic)], filepath, cmd_mode)
        endif
    elseif cmd_type == "read"
        let cache_index = worker#work_newest("write", dat_type, filepath)
        if cache_index >= 0
            let cache_dic = s:work_table[cache_index]
            if dat_type == "list"
                let data_list = info_dic['dat_list'] 
                call extend(data_list, cache_dic['dat_list'])
            elseif dat_type == "dict"
                let data_dic  = info_dic['dat_dict'] 
                call extend(data_dic, cache_dic['dat_dict'])
            endif
            let info_dic['status'] = 2
            return
        endif

        if dat_type == "list"
            let data_list = info_dic['dat_list'] 
            if ! empty(data_list)
                let count = len(data_list)
                call remove(data_list, 0, count - 1)
            endif

            if filereadable(filepath)
                let read_list = readfile(filepath, cmd_mode, line_nr)
                call extend(data_list, read_list)
                "for item in read_list
                ""    call add(data_list, item)
                "endfor
            endif
        elseif dat_type == "dict"
            let data_dic  = info_dic['dat_dict'] 
            if filereadable(filepath)
                let read_dic = eval(get(readfile(filepath, cmd_mode, line_nr), 0, ''))
                call extend(data_dic, read_dic)
                "for [key, value] in items(read_dic)
                "    data_dic[key] = value
                "endfor
            endif
        endif
    endif
    let info_dic['status'] = 2
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
