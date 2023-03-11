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
            \     'qfix_id' : 5,
            \     'data_id' : 8,
            \     'next_id' : 1,
            \     'invalid' : 1
            \   },
            \   {
            \     'qfix_id' : 3,
            \     'data_id' : 9,
            \     'next_id' : 0,
            \     'invalid' : 1
            \   }
            \   ],
            \   'Rgrep' : [
            \   {
            \     'qfix_id' : 0,
            \     'data_id' : 0,
            \     'next_id' : 0,
            \     'invalid' : 1
            \   }
            \   ]
            \ }

let s:data_table = [
            \   {
            \     'timer_id' : 0,
            \     'cmd_type' : 'write',
            \     'cmd_mode' : 'b',
            \     'line_nr'  : 0,
            \     'dat_type' : 'list',
            \     'filepath' : '',
            \     'dat_list' : [],
            \     'dat_dic'  : {},
            \     'status'   : 0
            \   },
            \   {
            \     'timer_id' : 0,
            \     'cmd_type' : 'read',
            \     'cmd_mode' : 'b',
            \     'line_nr'  : 0,
            \     'dat_type' : 'dic',
            \     'filepath' : '',
            \     'dat_list' : [],
            \     'dat_dic'  : {},
            \     'status'   : 0
            \   }
            \ ]

let s:data_tail_index = 0
let s:data_head_index = 0

function! worker#get_data_index() abort
    let length = len(s:data_table)
    let index =0
    while index < length
        let item = get(info_list, index)
        if item["status"] == 0 
            return index
        endif
        let index += 1
    endfor

    return -1
endfunction

function! worker#work_status(data_index) abort
    let info_dic = s:data_table[a:data_index]
    return info_dic["status"]
endfunction

function! worker#work_data(data_index, dat_type) abort
    let info_dic = s:data_table[a:data_index]

    if a:dat_type == "dic"
        return info_dic["dat_dic"]
    elseif a:dat_type == "list"
        return info_dic["dat_list"]
    endif
endfunction

function! worker#fill_worker(data_index, cmd_type, cmd_mode, dat_type, filepath, line_nr, status, data) abort
    let info_dic = s:data_table[a:data_index]

    info_dic["cmd_type"] = a:cmd_type
    info_dic["cmd_mode"] = a:cmd_mode
    info_dic["dat_type"] = a:dat_type
    info_dic["filepath"] = a:filepath
    info_dic["line_nr"]  = a:line_nr
    info_dic["status"]   = a:status
    
    if a:dat_type == "dic"
        call filter(info_dic["dat_dic"], 0)
        call extend(info_dic["dat_dic"], a:data)
    elseif a:dat_type == "list"
        call filter(info_dic["dat_list"], 0)
        call extend(info_dic["dat_list"], a:data)
    endif
endfunction

function! s:map_set(module, qfix_id, data_id, invalid) abort
    let info_list = s:map_table[a:module]

    let length = len(info_list)
    let index =0
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["data_id"] == a:data_id 
            item["invalid"] = a:invalid
            return index
        endif
        let index += 1
    endfor
    
    let info_dic = {}
    info_dic["qfix_id"] = a:qfix_id
    info_dic["data_id"] = a:data_id
    info_dic["next_id"] = -1
    info_dic["invalid"] = a:invalid
    call insert(info_list, info_dic, length)
    return length
endfunction

function! worker#map_del(module, qfix_id, data_id) abort
    let info_list = s:map_table[a:module]

    let length = len(info_list)
    let index =0
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["next_id"] == a:data_id 
           item["next_id"] = -1
           break
        endif
        let index += 1
    endfor

    let index =0
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["data_id"] == a:data_id 
            remove(info_list, index)
            call async#map_del(a:module, a:qfix_id, item["next_id"])
            return
        endif
        let index += 1
    endfor
endfunction

function! worker#map_index(module, qfix_id) abort
    let info_list = s:map_table[a:module]

    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["invalid"] == 1
            return item["data_id"]
        endif
        let index += 1
    endfor
    
    let data_index = s:data_head_index
    let s:data_head_index += 1
    call s:map_set(a:module, a:qfix_id, data_index, 0)

    return data_index
endfunction

function! worker#map_next(module, qfix_id, data_index) abort
    let info_list = s:map_table[a:module]

    let data_next = -1
    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if item["qfix_id"] == a:qfix_id && item["data_id"] == a:data_index 
            data_next = item["next_id"] 
            break
        endif
        let index += 1
    endfor
    
    if data_next >= 0
        return data_next
    else
        if index >= length
            call PrintMsg("error", "invalid data index: ".a:data_index)
            return -1
        endif
    endif

    let data_index = s:data_head_index
    let s:data_head_index += 1

    call s:map_set(a:module, a:qfix_id, data_index, 0)
    info_list[index]["next_id"] = data_index
    return data_index
endfunction

function! worker#data_handle(data_index) abort
    let info_dic = s:data_table[a:data_index]
    info_dic['status'] = 1

    let cmd_type  = info_dic['cmd_type'] 
    let cmd_mode  = info_dic['cmd_mode'] 
    let dat_type  = info_dic['dat_type'] 
    let file_path = info_dic['filepath'] 
    let line_nr   = info_dic['line_nr'] 
    call PrintMsg("file", "cmd_type: ".data_index." cmd_mode: ".cmd_mode." dat_type: ".dat_type." file_path: ".file_path." line_nr: ".line_nr)

    if cmd_type == "write"
        if dat_type == "list"
            let data_list = info_dic['dat_list'] 
            for item in data_list
                let fname=fnamemodify(bufname(item.bufnr), ':p:.') 
                let item["filename"]=fname
                let item["bufnr"]=0

                if has_key(item, "end_lnum")
                    unlet item["end_lnum"]
                endif
                if has_key(item, "end_col")
                    unlet item["end_col"]
                endif

                call writefile([string(item)], file_path, cmd_mode)
            endfor
        elseif cmd_type == "dic"
            let data_dic  = info_dic['dat_dic'] 
            call writefile([string(data_dic)], file_path, cmd_mode)
        endif
    elseif cmd_type == "read"
        if dat_type == "list"
            let data_list = info_dic['dat_list'] 
            if ! empty(data_list)
                let count = len(data_list)
                call remove(data_list, 0, count - 1)
            endif

            if filereadable(file_path)
                let read_list = readfile(file_path, cmd_mode, line_nr)
                call extend(data_list, read_list)
                "for item in read_list
                ""    call add(data_list, item)
                "endfor
            endif
        elseif cmd_type == "dic"
            let data_dic  = info_dic['dat_dic'] 
            if filereadable(file_path)
                let read_dic = eval(get(readfile(file_path, cmd_mode, line_nr), 0, ''))
                for [key, value] in items(read_dic)
                    data_dic[key] = value
                endfor
            endif
        endif
    endif
    info_dic['status'] = 2
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
