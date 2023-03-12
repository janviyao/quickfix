" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

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
    autocmd CursorMoved * if exists("s:qfix_opened") && &buftype != 'quickfix' | call quickfix#ctrl_main(g:quickfix_module, "close") | endif
augroup END

let s:qfix_index_list = []

function! s:quick_dump_info(module)
    if !exists("g:quickfix_dump_enable") || g:quickfix_dump_enable == 0
        return
    endif

    let maxNextLen = 0
    let maxTitleLen = 0
    let home_index = 0
    while home_index < g:quickfix_index_max
        let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".home_index
        if filereadable(info_file) 
            let data = sync#read_list(a:module, info_file, 'b', 1)
            let info_dic = eval(get(data, 0, ''))
            "let info_dic = eval(get(readfile(info_file, 'b', 1), 0, ''))
            if empty(info_dic)
                call PrintMsg("error", "info empty: ".info_file)
                let home_index += 1
                continue
            endif

            if len(string(info_dic.index_next)) > maxNextLen
                let maxNextLen = len(string(info_dic.index_next))
            endif

            if len(string(info_dic.title)) > maxTitleLen
                let maxTitleLen = len(string(info_dic.title))
            endif
        endif
        let home_index += 1
    endwhile
    let maxNextLen += 2
    if maxTitleLen > 2
        let maxTitleLen -= 2
    endif

    let nextFormat = "next: %-".maxNextLen."s"
    let titleFormat = "title: %-".maxTitleLen."s"

    call PrintMsg("file", "")
    let currIndex = printf("prev: %-2d index: %-2d ".nextFormat, s:qfix_index_prev, s:qfix_index, string(s:qfix_index_next))
    let currCursor = printf("cursor: %d/%d", line("."), col("."))
    let currPick = printf("pick: %-4d %-18s", s:qfix_pick, currCursor)
    let currFile = printf(titleFormat." file: %s", s:qfix_title, fnamemodify(bufname("%"), ':p:.'))
    call PrintMsg("file", "now ".currIndex." ".currPick. " ".currFile)

    let home_index = 0
    while home_index < g:quickfix_index_max
        let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".home_index
        if filereadable(info_file)
            let data = sync#read_list(a:module, info_file, 'b', 1)
            let info_dic = eval(get(data, 0, ''))
            "let info_dic = eval(get(readfile(info_file, 'b', 1), 0, ''))
            
            let indexInfo = printf("prev: %-2d index: %-2d ".nextFormat, info_dic.index_prev, info_dic.index, string(info_dic.index_next))
            let cursorInfo = printf("cursor: %d/%d", info_dic.fline, info_dic.fcol)
            let pickInfo = printf("pick: %-4d %-18s", info_dic.pick, cursorInfo)
            let fileInfo = printf(titleFormat." file: %s", info_dic.title, info_dic.fname)
            call PrintMsg("file", "map ".indexInfo." ".pickInfo." ".fileInfo)
        endif
        let home_index += 1
    endwhile
    call PrintMsg("file", "")
endfunction

function! s:csfind_compare(item1, item2)
    let fname1 = fnamemodify(bufname(a:item1.bufnr), ':p:.')
    let fname2 = fnamemodify(bufname(a:item2.bufnr), ':p:.')

    if fname1 == fname2 
        let lnum1 = str2nr(a:item1.lnum) 
        let lnum2 = str2nr(a:item2.lnum) 
        if lnum1 == lnum2 
            return 0
        elseif lnum1 < lnum2
            return -1
        else
            return 1
        endif
    else
        let nameList1 = split(fname1, "/")
        let nameList2 = split(fname2, "/")
        
        let minVal = min([len(nameList1), len(nameList2)])
        let startIndx = 0
        while startIndx < minVal
            if trim(nameList1[startIndx]) == trim(nameList2[startIndx])
                let startIndx += 1
            elseif trim(nameList1[startIndx]) < trim(nameList2[startIndx])
                return -1
            else
                return 1
            endif
        endwhile

        if startIndx == minVal
            return 0
        endif
    endif
    return 0
endfunction

function! s:quick_neat_show(module)
    if a:module == "csfind"
        let qflist = getqflist()
        call sort(qflist, "s:csfind_compare")

        call setqflist([], "r", {'items' : []})
        for item in qflist
            let res_code = setqflist([item], 'a')
            if res_code != 0
                call PrintMsg("error", a:module." item invalid: ".item)
                call s:quick_dump_info(a:module)
            endif
        endfor
    endif
endfunction

function! s:csfind_format(info)
    "get information about a range of quickfix entries
    let items = getqflist({'id' : a:info.id, 'items' : 1}).items
    let newList = []
    for idx in range(a:info.start_idx - 1, a:info.end_idx - 1)
        "use the simplified file name
        let lnctn = fnamemodify(bufname(items[idx].bufnr), ':p:.')."| ".items[idx].lnum." | ".items[idx].text
        call add(newList, lnctn)
    endfor
    
    return newList
endfunc

function! s:quick_load(module, index)
    let load_index = a:index
    if load_index < 0 
        "first load
        let index_file = GetVimDir(1, "quickfix").'/index.'.a:module
        if filereadable(index_file)
            let data = sync#read_list(a:module, index_file, 'b', 1)
            let load_index = str2nr(get(data, 0, ''))
            "let load_index = str2nr(get(readfile(index_file, 'b', 1), 0, ''))
        else
            let load_index = 0
        endif

        call filter(s:qfix_index_list, 0)
        let info_list = systemlist("ls ".GetVimDir(1, "quickfix")."/info.".a:module.".*")
        for info_file in info_list
            if filereadable(info_file)
                let index_val = str2nr(matchstr(info_file, '\v\d+$'))
                if index(s:qfix_index_list, index_val) < 0 
                    call add(s:qfix_index_list, index_val)
                endif
            endif
        endfor
        call Quickfix_rebuild(a:module, s:qfix_index_list)
    endif

    call PrintMsg("file", a:module." load index: ".load_index)
    let list_file = GetVimDir(1, 'quickfix').'/list.'.a:module.'.'.load_index
    if filereadable(list_file) 
        let index_val = index(s:qfix_index_list, load_index)
        if index_val < 0 
            if empty(s:qfix_index_list)
                call PrintMsg("error", "all: ".string(s:qfix_index_list)." not contain: ".load_index)
                return -1
            else
                call PrintMsg("file", "change load_index from ".load_index." to ".s:qfix_index_list[0])
                load_index = s:qfix_index_list[0]
            endif
        endif

        let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".load_index
        if filereadable(info_file)
            let info_dic = sync#read_dict(a:module, info_file, 'b', 1)
            "let info_dic = eval(get(readfile(info_file, 'b', 1), 0, ''))
        else
            let info_dic = { "pick": 1, "title": "!anon!" } 
        endif
        call PrintDict("file", a:module." load key: ", info_dic)

        let s:qfix_index = info_dic.index
        let s:qfix_pick  = info_dic.pick
        let s:qfix_title = info_dic.title
        let s:qfix_index_prev = info_dic.index_prev
        if s:qfix_index != load_index
            call PrintMsg("error", a:module." load index not consistent: ".s:qfix_index." != ".load_index)
            call s:quick_dump_info(a:module)
        endif
        let s:qfix_index_next = copy(info_dic.index_next)

        call setqflist([], "r")
        let qflist = sync#read_list(a:module, list_file, '', 9999999)
        "let qflist = readfile(list_file, "")
        for item in qflist
            let tmp_dic = eval(item)
            let res_code = setqflist([tmp_dic], 'a')
            if res_code != 0
                call PrintMsg("error", a:module." item invalid: ".item)
                call s:quick_dump_info(a:module)
            endif
        endfor

        if a:module == "csfind"
            call setqflist([], 'a', {'quickfixtextfunc': 's:csfind_format'})
        elseif a:module == "grep"
            call setqflist([], 'a', {'quickfixtextfunc': 's:grep_format'})
        endif

        let res_code = setqflist([], 'a', {'idx': s:qfix_pick})
        if res_code != 0
            call PrintMsg("error", a:module." idx invalid: ".s:qfix_pick)
        endif

        let res_code = setqflist([], 'a', {'title': s:qfix_title})
        if res_code != 0
            call PrintMsg("error", a:module." title invalid: ".s:qfix_title)
        endif

        call PrintMsg("file", a:module." set idx: ".s:qfix_pick." get: ".string(getqflist({'idx' : 0})))
        call PrintMsg("file", a:module." set title: ".string(getqflist({'title' : 0})))

        let s:qfix_size = getqflist({'size' : 1}).size
        let s:qfix_title = getqflist({'title' : 1}).title

        let fname = fnamemodify(bufname("%"), ':p:.') 
        if fname != info_dic.fname
            silent! execute "buffer! ".info_dic.fname
        endif
        call cursor(info_dic.fline, info_dic.fcol)

        "save the newest index
        let index_file = GetVimDir(1, "quickfix").'/index.'.a:module
        call async#write_list(a:module, index_file, 'b', [s:qfix_index])
        "call writefile([s:qfix_index], index_file, 'b')
        call s:quick_dump_info(a:module)
        return 0
    endif

    return -1
endfunction

function! s:quick_persist_info(module, index, key="", value="")
    let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".a:index

    let info_dic = {}
    if strlen(a:key) == 0
        let info_dic['time'] = localtime() 
        let info_dic['index_prev'] = s:qfix_index_prev
        let info_dic['index'] = s:qfix_index
        let info_dic['index_next'] = s:qfix_index_next
        let info_dic['pick'] = s:qfix_pick
        let info_dic['size'] = s:qfix_size
        let info_dic['title'] = s:qfix_title
        let info_dic['fname'] = expand("%:p:.") 
        let info_dic['fline'] = line(".")
        let info_dic['fcol'] = col(".")
    else
        if filereadable(info_file)
            let info_dic = sync#read_dict(a:module, info_file, 'b', 1)
            "let info_dic = eval(get(readfile(info_file, 'b', 1), 0, ''))
            if strlen(a:value) <= 0
                if a:key == "time"
                    let info_dic['time'] = localtime() 
                elseif a:key == "index_prev"
                    let info_dic['index_prev'] = s:qfix_index_prev
                elseif a:key == "index"
                    let info_dic['index'] = s:qfix_index
                elseif a:key == "index_next"
                    let info_dic['index_next'] = s:qfix_index_next
                elseif a:key == "pick"
                    let info_dic['pick'] = s:qfix_pick
                elseif a:key == "size"
                    let info_dic['size'] = s:qfix_size
                elseif a:key == "title"
                    let info_dic['title'] = s:qfix_title
                elseif a:key == "fname"
                    let info_dic['fname'] = expand("%:p:.") 
                elseif a:key == "fline"
                    let info_dic['fline'] = line(".")
                elseif a:key == "fcol"
                    let info_dic['fcol'] = col(".")
                endif
            else
                let info_dic[a:key] = eval(a:value) 
            endif
        endif
    endif

    call PrintMsg("file", a:module." save info: ")
    call async#write_dic(a:module, info_file, 'b', info_dic)
    "call writefile([string(info_dic)], info_file, 'b')
endfunction

function! s:quick_persist_list(module, index, qflist)
    if a:module == "csfind"
        call sort(a:qflist, "s:csfind_compare")
    endif

    for item in a:qflist
        let fname=fnamemodify(bufname(item.bufnr), ':p:.') 
        let item["filename"]=fname
        let item["bufnr"]=0

        if has_key(item, "end_lnum")
            unlet item["end_lnum"]
        endif
        if has_key(item, "end_col")
            unlet item["end_col"]
        endif
        "call writefile([string(item)], list_file, 'a')
    endfor

    let list_file = GetVimDir(1, "quickfix").'/list.'.a:module.".".a:index
    call writefile([], list_file, 'r')
    call async#write_list(a:module, list_file, 'a', a:qflist)
endfunction

function! s:quick_save(module, index)
    let qflist = getqflist()
    if !empty(qflist)
        if s:qfix_index != a:index
            call PrintMsg("error", a:module." save index not consistent: ".s:qfix_index." != ".a:index)
            call s:quick_dump_info(a:module)
            call s:quick_load(a:module, a:index)
        endif

        let index_file = GetVimDir(1, "quickfix").'/index.'.a:module
        call async#write_list(a:module, index_file, 'b', [a:index])
        "call writefile([a:index], index_file, 'b')

        call s:quick_persist_info(a:module, a:index)
        call s:quick_persist_list(a:module, a:index, qflist)

        if index(s:qfix_index_list, str2nr(a:index)) < 0 
            call add(s:qfix_index_list, str2nr(a:index))
            call PrintMsg("file", "index(".len(s:qfix_index_list).") all: ".string(s:qfix_index_list))
        endif
        return 0
    endif
    return -1
endfunction

function! s:quick_delete(module, index)
    call PrintMsg("file", a:module." delete index: ".a:index)
    let list_file = GetVimDir(1, "quickfix").'/list.'.a:module.".".a:index
    if filereadable(list_file)
        call delete(list_file)
        call PrintMsg("file", a:module." delete success: list".a:index)
    endif

    let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".a:index
    if filereadable(info_file)
        let data = sync#read_list(a:module, info_file, 'b', 1)
        let info_dic = eval(get(data, 0, ''))
        "let info_dic = eval(get(readfile(info_file, 'b', 1), 0, ''))
        let index_prev = info_dic.index_prev
        let index_next = info_dic.index_next

        if info_dic.index != a:index 
            call PrintMsg("error", a:module." index(".a:index.") != info index(".info_dic.index.") info: ".string(info_dic))
            call s:quick_dump_info(a:module)
        endif

        let home_index = 0
        while home_index < g:quickfix_index_max
            if home_index == a:index
                let home_index += 1
                continue
            endif

            let errHappen = 0
            let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".home_index
            if filereadable(info_file)
                let isWrite = 0
                let data = sync#read_list(a:module, info_file, 'b', 1)
                let info_dic = eval(get(data, 0, ''))
                "let info_dic = eval(get(readfile(info_file, 'b', 1), 0, ''))

                let index_val = index(info_dic.index_next, a:index)    
                if index_val >= 0 
                    call remove(info_dic.index_next, index_val)
                    let info_dic.index_next += index_next

                    let index_val = index(info_dic.index_next, info_dic.index)    
                    if index_val >= 0 
                        let errHappen = 1
                        call PrintMsg("error", a:module." index(".info_dic.index.") in index_next(".string(info_dic.index_next).") info: ".string(info_dic))
                        call s:quick_dump_info(a:module)
                        let info_dic.index_next = [g:quickfix_index_max] 
                    endif
                    let isWrite = 1
                endif    

                if info_dic.index_prev == a:index 
                    let info_dic.index_prev = index_prev
                    if info_dic.index == info_dic.index_prev
                        let errHappen = 1
                        call PrintMsg("error", a:module." index(".info_dic.index.") = index_prev(".info_dic.index_prev.") info: ".string(info_dic))
                        call s:quick_dump_info(a:module)
                        let info_dic.index_prev = g:quickfix_index_max 
                    endif
                    let isWrite = 1
                endif

                if isWrite == 1
                    call async#write_dic(a:module, info_file, 'b', info_dic)
                    "call writefile([string(info_dic)], info_file, 'b')
                endif
            endif

            let home_index += 1
            if errHappen == 1
                call s:quick_dump_info(a:module)
            endif
        endwhile

        let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".a:index
        call delete(info_file)
        call PrintMsg("file", a:module." delete success: info".a:index)
    endif

    let index_val = index(s:qfix_index_list, str2nr(a:index))
    if index_val >= 0 
        call remove(s:qfix_index_list, index_val)
    endif
 
    return 0
endfunction

function! s:quick_get_index(module, mode, index)
    let retIndex = []
    let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".a:index
    if filereadable(info_file)
        let data = sync#read_list(a:module, info_file, 'b', 1)
        let info_dic = eval(get(data, 0, ''))
        "let info_dic = eval(get(readfile(info_file, 'b', 1), 0, ''))

        if a:mode == "index"
            call add(retIndex, info_dic.index)
        elseif a:mode == "index_next"
            call extend(retIndex, info_dic.index_next)
        elseif a:mode == "index_prev"
            call add(retIndex, info_dic.index_prev)
        endif
    endif

    call PrintMsg("file", a:module." get from info.".a:index." mode: ".a:mode." return: ".string(retIndex))
    return retIndex
endfunction

function! s:quick_info_seek(module, mode, index)
    let retIndex = -1
    let info_list = systemlist("ls ".GetVimDir(1, "quickfix")."/info.".a:module.".*")
    for info_file in info_list
        if filereadable(info_file)
            let data = sync#read_list(a:module, info_file, 'b', 1)
            let info_dic = eval(get(data, 0, ''))
            "let info_dic = eval(get(readfile(info_file, 'b', 1), 0, ''))
            call PrintMsg("file", a:module." seek: ".string(info_dic))

            if a:mode == "index"
                if info_dic.index == a:index 
                    let retIndex = info_dic.index
                    break
                endif
            elseif a:mode == "index_next"
                let index_val = index(info_dic.index_next, a:index)    
                if index_val >= 0 
                    let retIndex = info_dic.index
                    break
                endif
            elseif a:mode == "index_prev"
                if info_dic.index_prev == a:index 
                    let retIndex = info_dic.index
                    break
                endif 
            endif
        endif
    endfor

    call PrintMsg("file", a:module." seek from info.".a:index." mode: ".a:mode." return: ".retIndex)
    return retIndex
endfunction

function! s:quick_find_oldest(module, index_list)
    call PrintMsg("file", a:module." find oldest from ".string(a:index_list))
    let timeMin = localtime()
    let retIndex = -1
    let timeIndex = 0 
    for timeIndex in a:index_list
        let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".timeIndex
        if filereadable(info_file)
            let info_dic = sync#read_dict(a:module, info_file, 'b', 1)
            "let info_dic = eval(get(readfile(info_file, 'b', 1), 0, ''))
            if timeMin > info_dic.time 
                let timeMin = info_dic.time
                let retIndex = timeIndex
            endif
        endif
    endfor

    call PrintMsg("file", a:module." find oldest: ".retIndex)
    return retIndex
endfunction

function! s:quick_find_newest(module, index_list)
    call PrintMsg("file", a:module." find newest from ".string(a:index_list))

    let timeMax = 0 
    let retIndex = -1
    let timeIndex = 0 
    for timeIndex in a:index_list
        let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".timeIndex
        if filereadable(info_file)
            let data = sync#read_list(a:module, info_file, 'b', 1)
            let info_dic = eval(get(data, 0, ''))
            "let info_dic = eval(get(readfile(info_file, 'b', 1), 0, ''))
            if timeMax < info_dic.time 
                let timeMax = info_dic.time
                let retIndex = timeIndex
            endif
        endif
    endfor

    call PrintMsg("file", a:module." find newest: ".retIndex)
    return retIndex
endfunction

function! s:quick_new_index(module, start, exclude)
    call PrintMsg("file", a:module." new start: ".a:start." exclude: ".string(a:exclude))
    let site_index = g:quickfix_index_max
    let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".a:start
    if filereadable(info_file)
        let info_dic = sync#read_dict(a:module, info_file, 'b', 1)
        "let info_dic = eval(get(readfile(info_file, 'b', 1), 0, ''))
        let index_list = copy(info_dic.index_next)
        while len(index_list) > 0
            let site_index = index_list[0] 
            let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".site_index
            if filereadable(info_file)
                call remove(index_list, 0)
            else
                break
            endif
        endwhile 

        if index(a:exclude, site_index) >= 0 
            let site_index = g:quickfix_index_max
        else
            if len(index_list) == 0
                let site_index = g:quickfix_index_max
            else
                call PrintMsg("file", a:module." new find: ".site_index." because info next")
            endif
        endif
    endif

    if site_index == g:quickfix_index_max
        let site_index = 0
        while site_index < g:quickfix_index_max
            if index(a:exclude, site_index) >= 0 
                let site_index += 1
                continue
            endif

            let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".site_index
            if !filereadable(info_file)
                break
            endif
            let site_index += 1
        endwhile

        if site_index != g:quickfix_index_max 
            call PrintMsg("file", a:module." new find: ".site_index." because info file")
        endif
    endif

    if site_index == g:quickfix_index_max
        let site_index = s:quick_find_oldest(a:module, s:qfix_index_list)
        if site_index < 0
            let site_index = g:quickfix_index_max
        endif

        if site_index != g:quickfix_index_max 
            call PrintMsg("file", a:module." new find: ".site_index." because time oldest")
        endif
    endif

    if site_index == g:quickfix_index_max 
        let site_index = a:start + 1
        if site_index == g:quickfix_index_max
            let site_index = 0 
        endif
    endif

    call s:quick_delete(a:module, site_index)
    return site_index
endfunction

function! s:quick_find_home(module)
    let home_index = 0
    let newTitle = getqflist({'title' : 1}).title
    while home_index < g:quickfix_index_max
        let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".home_index
        if filereadable(info_file)
            let data = sync#read_list(a:module, info_file, 'b', 1)
            let info_dic = eval(get(data, 0, ''))
            "let info_dic = eval(get(readfile(info_file, 'b', 1), 0, ''))
            if info_dic.title == newTitle 
                call PrintMsg("file", a:module." find home: ".string(info_dic))
                return home_index
            endif    
        endif
        let home_index += 1
    endwhile
    return -1
endfunction

function! s:grep_format(info)
    "get information about a range of quickfix entries
    let items = getqflist({'id' : a:info.id, 'items' : 1}).items
    let newList = []
    for idx in range(a:info.start_idx - 1, a:info.end_idx - 1)
        "call PrintMsg("file", string(items[idx]))
        if items[idx].lnum == 0
            call add(newList, "|| ".items[idx].text)
        else
            "use the simplified file name
            let lnctn = fnamemodify(bufname(items[idx].bufnr), ':p:.')."| ".items[idx].lnum." | ".items[idx].text
            call add(newList, lnctn)
        endif
    endfor
    
    return newList
endfunc

function! quickfix#ctrl_main(module, mode)
    call PrintMsg("file", a:module." mode: ".a:mode)
    if a:mode == "open"
        call PrintMsg("file", a:module." pick state: ".string(getqflist({'idx': 0})))
        if !empty(getqflist())
            let height = winheight(0)/2
            silent! execute 'copen '.height
            let s:qfix_opened = bufnr("$")
        endif
    elseif a:mode == "close"
        if exists("s:qfix_opened")
            silent! execute 'cclose'
            unlet! s:qfix_opened
        endif
    elseif a:mode == "toggle"
        if exists("s:qfix_opened")
            call quickfix#ctrl_main(a:module, "close")        
        else
            call quickfix#ctrl_main(a:module, "open")        
        endif
    elseif a:mode == "clear"
        call setqflist([], "r")
    elseif a:mode == "recover"
        silent! execute 'cc!'
    elseif a:mode == "recover-next"
        call s:quick_dump_info(a:module)
        call quickfix#ctrl_main(a:module, "save")
        let nextIndex = s:quick_info_seek(a:module, "index_prev", s:qfix_index)
        if nextIndex >= 0
            call s:quick_load(a:module, nextIndex)
            return 0
        endif
        return -1
    elseif a:mode == "recover-prev"
        call s:quick_dump_info(a:module)
        call quickfix#ctrl_main(a:module, "save")
        let prevIndex = s:quick_info_seek(a:module, "index_next", s:qfix_index)
        if prevIndex >= 0
            call s:quick_load(a:module, prevIndex)
            return 0
        endif
        return -1
    elseif a:mode == "next"
        silent! execute 'cn!'
        let s:qfix_pick = getqflist({'idx' : 0}).idx
    elseif a:mode == "prev"
        silent! execute 'cp!'
        let s:qfix_pick = getqflist({'idx' : 0}).idx
    elseif a:mode == "save"
        if empty(getqflist())
            return 0
        endif
        call s:quick_dump_info(a:module)

        let home_index = s:quick_find_home(a:module)
        if home_index >= 0
            call s:quick_save(a:module, home_index)
        else 
            call s:quick_save(a:module, s:qfix_index)
        endif
    elseif a:mode == "load"
        if !exists("s:qfix_index")
            "first load
            let s:qfix_index = -1 
        endif
        call s:quick_load(a:module, s:qfix_index)

        "when quickfix load empty and then first save, var not exist
        if !exists("s:qfix_pick")
            let s:qfix_index_prev = g:quickfix_index_max - 2
            let s:qfix_index = g:quickfix_index_max - 1
            let s:qfix_index_next = [0]

            let s:qfix_pick = 1
            let s:qfix_title = "!anon!" 
            let s:qfix_size = 0 
        endif
        call s:quick_dump_info(a:module)
    elseif a:mode == "delete"
        call s:quick_dump_info(a:module)
        let res_code = s:quick_delete(a:module, s:qfix_index)
        if res_code == 0
            call s:quick_dump_info(a:module)
            call setqflist([], "r")

            let load_index = s:quick_info_seek(a:module, "index", s:qfix_index_prev)
            if load_index >= 0
                call s:quick_load(a:module, load_index)
                return 0
            else
                let index_list = copy(s:qfix_index_next)
                while len(index_list) > 0
                    let nextIndex = s:quick_find_newest(a:module, index_list)
                    if nextIndex < 0
                        call filter(index_list, 0)
                        break
                    endif

                    let load_index = s:quick_info_seek(a:module, "index", nextIndex)
                    if load_index < 0
                        let index = index(index_list, nextIndex)    
                        call remove(index_list, index)
                    else
                        call s:quick_load(a:module, load_index)
                        return 0
                    endif
                endwhile

                if len(index_list) == 0
                    let arrIndex = s:quick_get_index(a:module, "index_prev", s:qfix_index_prev)
                    while len(arrIndex) > 0
                        let load_index = s:quick_get_index(a:module, "index", arrIndex[0])
                        if len(load_index) > 0
                            call s:quick_load(a:module, load_index[0])
                            return 0
                        endif

                        let arrIndex = s:quick_get_index(a:module, "index_prev", arrIndex[0])
                    endwhile

                    let tmpList = []
                    let index_list = copy(s:qfix_index_next)
                    call PrintMsg("file", "start next: ".string(index_list))

                    while len(index_list) > 0
                        let nextIndex = s:quick_find_newest(a:module, index_list)
                        if nextIndex < 0
                            call filter(index_list, 0)
                            break
                        endif

                        let index = index(index_list, nextIndex)    
                        call remove(index_list, index)

                        let arrIndex = s:quick_get_index(a:module, "index_next", nextIndex)
                        while len(arrIndex) > 0
                            let newest = s:quick_find_newest(a:module, arrIndex)
                            if newest < 0
                                call filter(arrIndex, 0)
                                break
                            endif

                            let load_index = s:quick_get_index(a:module, "index", newest)
                            if len(load_index) <= 0
                                let index = index(arrIndex, newest)    
                                call remove(arrIndex, index)
                                call extend(tmpList, s:quick_get_index(a:module, "index_next", newest))
                            else
                                call s:quick_load(a:module, load_index[0])
                                return 0
                            endif
                        endwhile
                        
                        if len(index_list) == 0
                            call extend(index_list, tmpList)
                            call PrintMsg("file", "extend next: ".string(index_list))
                            call filter(tmpList, 0)
                        endif
                    endwhile
                endif
            endif

            let info_list = systemlist("ls ".GetVimDir(1, "quickfix")."/info.".a:module.".*")
            let tmpList = copy(info_list)
            for info_file in info_list
                if !filereadable(info_file)
                    let index = index(tmpList, info_file)    
                    call remove(tmpList, index)
                endif
            endfor

            if len(tmpList) == 0 
                let index_file = GetVimDir(1, "quickfix").'/index.'.a:module
                if filereadable(index_file)
                    call delete(index_file)
                endif
                return 0
            endif

            call PrintMsg("error", "index: ".s:qfix_index." is bad")
            return -1
        endif
    elseif a:mode == "home"
        call s:quick_dump_info(a:module)
        let home_index = s:quick_find_home(a:module)
        if home_index >= 0
            call s:quick_persist_list(a:module, home_index, getqflist())
            call s:quick_load(a:module, home_index)
            return home_index
        else
            call s:quick_neat_show(a:module)

            let new_index_prev = s:qfix_index
            let new_index = s:quick_new_index(a:module, s:qfix_index, [new_index_prev]) 
            let new_index_next = [ s:quick_new_index(a:module, s:qfix_index, [new_index, new_index_prev]) ]

            if index(s:qfix_index_next, new_index) < 0
                call add(s:qfix_index_next, new_index)
                call s:quick_persist_info(a:module, s:qfix_index, "index_next", string(s:qfix_index_next))
            endif

            let s:qfix_index_prev = new_index_prev
            let s:qfix_index = new_index
            let s:qfix_index_next = new_index_next

            let s:qfix_pick = getqflist({'idx' : 0}).idx
            let s:qfix_title = getqflist({'title' : 1}).title
            let s:qfix_size = getqflist({'size' : 1}).size

            call s:quick_dump_info(a:module)
            return -1
        endif
    endif

    return 0
endfunction

"CS命令
function! quickfix#csfind(ccmd)
    let csarg = expand('<cword>')
    call PrintMsg("file", "CSFind: ".csarg)
    call ToggleWindow("allclose")
    call quickfix#ctrl_main(g:quickfix_module, "save")
    call quickfix#ctrl_main(g:quickfix_module, "clear")
    if g:quickfix_module != "csfind"
        let g:quickfix_module = "csfind"
        if exists("s:qfix_index")
            unlet s:qfix_index
        endif
        call quickfix#ctrl_main(g:quickfix_module, "load")
        call quickfix#ctrl_main(g:quickfix_module, "clear")
    endif

    if a:ccmd == "fs"
        execute "cs find s ".csarg 
    elseif a:ccmd == "fg"
        silent! execute "cs find g ".csarg 
    elseif a:ccmd == "fc"
        silent! execute "cs find c ".csarg 
    elseif a:ccmd == "fd"
        silent! execute "cs find d ".csarg 
    elseif a:ccmd == "ft"
        silent! execute "cs find t ".csarg 
    elseif a:ccmd == "fe"
        silent! execute "cs find e ".csarg 
    elseif a:ccmd == "ff"
        let csarg=expand('<cfile>')
        silent! execute "cs find f ".csarg 
    elseif a:ccmd == "fi"
        let csarg=expand('<cfile>')
        silent! execute "cs find i ".csarg 
    endif

    if empty(getqflist())
        return
    endif

    call setqflist([], 'a', {'quickfixtextfunc': 's:csfind_format'}) 
    call quickfix#ctrl_main(g:quickfix_module, "home")
    call quickfix#ctrl_main(g:quickfix_module, "open")
endfunction

function! quickfix#grep_find()
    let csarg = expand('<cword>')
    silent! normal! mX

    call PrintMsg("file", "GrepFind: ".csarg)
    call ToggleWindow("allclose")
    call quickfix#ctrl_main(g:quickfix_module, "save")
    call quickfix#ctrl_main(g:quickfix_module, "clear")
    if g:quickfix_module != "grep"
        let g:quickfix_module = "grep"
        if exists("s:qfix_index")
            unlet s:qfix_index
        endif
        call quickfix#ctrl_main(g:quickfix_module, "load")
        call quickfix#ctrl_main(g:quickfix_module, "clear")
    endif

    silent! normal! g`X
    silent! delmarks X
    execute "Rgrep"

    if empty(getqflist())
        return
    endif

    call setqflist([], 'a', {'quickfixtextfunc': 's:grep_format'}) 
    call quickfix#ctrl_main(g:quickfix_module, "home")
    call quickfix#ctrl_main(g:quickfix_module, "open")
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
