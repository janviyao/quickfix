" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

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
            let retCode = setqflist([item], 'a')
            if retCode != 0
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
    let loadIndex = a:index
    if loadIndex < 0 
        "first load
        let indexFile = GetVimDir(1,"quickfix").'/index.'.a:module
        if filereadable(indexFile)
            let data = sync#read_list(a:module, indexFile, 'b', 1)
            let loadIndex = str2nr(get(data, 0, ''))
            "let loadIndex = str2nr(get(readfile(indexFile, 'b', 1), 0, ''))
        else
            let loadIndex = 0
        endif

        let s:qfix_index_all = []
        let infoList = systemlist("ls ".GetVimDir(1,"quickfix")."/info.".a:module.".*")
        for infoFile in infoList
            if filereadable(infoFile)
                let indexVal = str2nr(matchstr(infoFile, '\v\d+$'))
                if index(s:qfix_index_all, indexVal) < 0 
                    call add(s:qfix_index_all, indexVal)
                endif
            endif
        endfor
        call PrintMsg("file", a:module." load index list: ".string(s:qfix_index_all))
    endif

    call PrintMsg("file", a:module." load index: ".loadIndex)
    let listFile = GetVimDir(1,"quickfix").'/list.'.a:module.".".loadIndex
    if filereadable(listFile) 
        let indexVal = index(s:qfix_index_all, loadIndex)
        if indexVal < 0 
            call PrintMsg("error", "index(".len(s:qfix_index_all).") all: ".string(s:qfix_index_all)." not contain: ".loadIndex)
        endif

        let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".loadIndex
        if filereadable(infoFile)
            let data = sync#read_list(a:module, infoFile, 'b', 1)
            let infoDic = eval(get(data, 0, ''))
            "let infoDic = eval(get(readfile(infoFile, 'b', 1), 0, ''))
        else
            let infoDic = { "pick": 1, "title": "!anon!" } 
        endif
        call PrintMsg("file", a:module." load key: ".string(infoDic))

        let s:qfix_pick = infoDic.pick
        let s:qfix_title = infoDic.title
        let s:qfix_index_prev = infoDic.index_prev
        let s:qfix_index = infoDic.index
        if s:qfix_index != loadIndex
            call PrintMsg("error", a:module." load index not consistent: ".s:qfix_index." != ".loadIndex)
            call s:quick_dump_info(a:module)
        endif
        let s:qfix_index_next = copy(infoDic.index_next)

        call setqflist([], "r")
        let qflist = sync#read_list(a:module, listFile, '', 9999999)
        "let qflist = readfile(listFile, "")
        for item in qflist
            let dicTmp = eval(item)
            let retCode = setqflist([dicTmp], 'a')
            if retCode != 0
                call PrintMsg("error", a:module." item invalid: ".item)
                call s:quick_dump_info(a:module)
            endif
        endfor

        if a:module == "csfind"
            call setqflist([], 'a', {'quickfixtextfunc': 's:csfind_format'})
        elseif a:module == "grep"
            call setqflist([], 'a', {'quickfixtextfunc': 's:grep_format'})
        endif

        let retCode = setqflist([], 'a', {'idx': s:qfix_pick})
        if retCode != 0
            call PrintMsg("error", a:module." idx invalid: ".s:qfix_pick)
        endif

        let retCode = setqflist([], 'a', {'title': s:qfix_title})
        if retCode != 0
            call PrintMsg("error", a:module." title invalid: ".s:qfix_title)
        endif

        call PrintMsg("file", a:module." set idx: ".s:qfix_pick." get: ".string(getqflist({'idx' : 0})))
        call PrintMsg("file", a:module." set title: ".string(getqflist({'title' : 0})))

        let s:qfix_size = getqflist({'size' : 1}).size
        let s:qfix_title = getqflist({'title' : 1}).title

        let fname = fnamemodify(bufname("%"), ':p:.') 
        if fname != infoDic.fname
            silent! execute "buffer! ".infoDic.fname
        endif

        call cursor(infoDic.fline, infoDic.fcol)

        "save the newest index
        let indexFile = GetVimDir(1,"quickfix").'/index.'.a:module
        call async#write_list(a:module, indexFile, 'b', [s:qfix_index])
        "call writefile([s:qfix_index], indexFile, 'b')

        call s:quick_dump_info(a:module)
        return 0
    endif

    return -1
endfunction

function! s:quick_persist_info(module, index, key="", value="")
    let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".a:index

    let infoDic = {}
    if strlen(a:key) == 0
        let infoDic['time'] = localtime() 
        let infoDic['index_prev'] = s:qfix_index_prev
        let infoDic['index'] = s:qfix_index
        let infoDic['index_next'] = s:qfix_index_next
        let infoDic['pick'] = s:qfix_pick
        let infoDic['size'] = s:qfix_size
        let infoDic['title'] = s:qfix_title
        let infoDic['fname'] = expand("%:p:.") 
        let infoDic['fline'] = line(".")
        let infoDic['fcol'] = col(".")
    else
        if filereadable(infoFile)
            let data = sync#read_list(a:module, infoFile, 'b', 1)
            let infoDic = eval(get(data, 0, ''))
            "let infoDic = eval(get(readfile(infoFile, 'b', 1), 0, ''))
            if strlen(a:value) <= 0
                if a:key == "time"
                    let infoDic['time'] = localtime() 
                elseif a:key == "index_prev"
                    let infoDic['index_prev'] = s:qfix_index_prev
                elseif a:key == "index"
                    let infoDic['index'] = s:qfix_index
                elseif a:key == "index_next"
                    let infoDic['index_next'] = s:qfix_index_next
                elseif a:key == "pick"
                    let infoDic['pick'] = s:qfix_pick
                elseif a:key == "size"
                    let infoDic['size'] = s:qfix_size
                elseif a:key == "title"
                    let infoDic['title'] = s:qfix_title
                elseif a:key == "fname"
                    let infoDic['fname'] = expand("%:p:.") 
                elseif a:key == "fline"
                    let infoDic['fline'] = line(".")
                elseif a:key == "fcol"
                    let infoDic['fcol'] = col(".")
                endif
            else
                let infoDic[a:key] = eval(a:value) 
            endif
        endif
    endif

    call PrintMsg("file", a:module." save info: ".string(infoDic))
    call async#write_dic(a:module, infoFile, 'b', infoDic)
    "call writefile([string(infoDic)], infoFile, 'b')
endfunction

function! s:quick_persist_list(module, index, qflist)
    if a:module == "csfind"
        call sort(a:qflist, "s:csfind_compare")
    endif

    let listFile = GetVimDir(1,"quickfix").'/list.'.a:module.".".a:index
    call writefile([], listFile, 'r')
    call async#write_list(a:module, listFile, 'a', a:qflist)
    "for item in a:qflist
    "    let fname=fnamemodify(bufname(item.bufnr), ':p:.') 
    "    let item["filename"]=fname
    "    let item["bufnr"]=0

    "    if has_key(item, "end_lnum")
    "        unlet item["end_lnum"]
    "    endif
    "    if has_key(item, "end_col")
    "        unlet item["end_col"]
    "    endif

    "    call writefile([string(item)], listFile, 'a')
    "endfor
endfunction

function! s:quick_save(module, index)
    let qflist = getqflist()
    if !empty(qflist)
        if s:qfix_index != a:index
            call PrintMsg("error", a:module." save index not consistent: ".s:qfix_index." != ".a:index)
            call s:quick_dump_info(a:module)
            call s:quick_load(a:module, a:index)
        endif

        let indexFile = GetVimDir(1,"quickfix").'/index.'.a:module
        call async#write_list(a:module, indexFile, 'b', [a:index])
        "call writefile([a:index], indexFile, 'b')

        call s:quick_persist_info(a:module, a:index)
        call s:quick_persist_list(a:module, a:index, qflist)

        if index(s:qfix_index_all, str2nr(a:index)) < 0 
            call add(s:qfix_index_all, str2nr(a:index))
            call PrintMsg("file", "index(".len(s:qfix_index_all).") all: ".string(s:qfix_index_all))
        endif
        return 0
    endif
    return -1
endfunction

function! s:quick_delete(module, index)
    call PrintMsg("file", a:module." delete index: ".a:index)
    let listFile = GetVimDir(1,"quickfix").'/list.'.a:module.".".a:index
    if filereadable(listFile)
        call delete(listFile)
        call PrintMsg("file", a:module." delete success: list".a:index)
    endif

    let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".a:index
    if filereadable(infoFile)
        let data = sync#read_list(a:module, infoFile, 'b', 1)
        let infoDic = eval(get(data, 0, ''))
        "let infoDic = eval(get(readfile(infoFile, 'b', 1), 0, ''))
        let index_prev = infoDic.index_prev
        let index_next = infoDic.index_next

        if infoDic.index != a:index 
            call PrintMsg("error", a:module." index(".a:index.") != info index(".infoDic.index.") info: ".string(infoDic))
            call s:quick_dump_info(a:module)
        endif

        let homeIndex = 0
        while homeIndex < g:quickfix_index_max
            if homeIndex == a:index
                let homeIndex += 1
                continue
            endif

            let errHappen = 0
            let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".homeIndex
            if filereadable(infoFile)
                let isWrite = 0
                let data = sync#read_list(a:module, infoFile, 'b', 1)
                let infoDic = eval(get(data, 0, ''))
                "let infoDic = eval(get(readfile(infoFile, 'b', 1), 0, ''))

                let indexVal = index(infoDic.index_next, a:index)    
                if indexVal >= 0 
                    call remove(infoDic.index_next, indexVal)
                    let infoDic.index_next += index_next

                    let indexVal = index(infoDic.index_next, infoDic.index)    
                    if indexVal >= 0 
                        let errHappen = 1
                        call PrintMsg("error", a:module." index(".infoDic.index.") in index_next(".string(infoDic.index_next).") info: ".string(infoDic))
                        call s:quick_dump_info(a:module)
                        let infoDic.index_next = [g:quickfix_index_max] 
                    endif
                    let isWrite = 1
                endif    

                if infoDic.index_prev == a:index 
                    let infoDic.index_prev = index_prev
                    if infoDic.index == infoDic.index_prev
                        let errHappen = 1
                        call PrintMsg("error", a:module." index(".infoDic.index.") = index_prev(".infoDic.index_prev.") info: ".string(infoDic))
                        call s:quick_dump_info(a:module)
                        let infoDic.index_prev = g:quickfix_index_max 
                    endif
                    let isWrite = 1
                endif

                if isWrite == 1
                    call async#write_dic(a:module, infoFile, 'b', infoDic)
                    "call writefile([string(infoDic)], infoFile, 'b')
                endif
            endif

            let homeIndex += 1
            if errHappen == 1
                call s:quick_dump_info(a:module)
            endif
        endwhile

        let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".a:index
        call delete(infoFile)
        call PrintMsg("file", a:module." delete success: info".a:index)
    endif

    let indexVal = index(s:qfix_index_all, str2nr(a:index))
    if indexVal >= 0 
        call remove(s:qfix_index_all, indexVal)
    endif
 
    return 0
endfunction

function! s:quick_get_index(module, mode, index)
    let retIndex = []
    let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".a:index
    if filereadable(infoFile)
        let data = sync#read_list(a:module, infoFile, 'b', 1)
        let infoDic = eval(get(data, 0, ''))
        "let infoDic = eval(get(readfile(infoFile, 'b', 1), 0, ''))

        if a:mode == "index"
            call add(retIndex, infoDic.index)
        elseif a:mode == "index_next"
            call extend(retIndex, infoDic.index_next)
        elseif a:mode == "index_prev"
            call add(retIndex, infoDic.index_prev)
        endif
    endif

    call PrintMsg("file", a:module." get from info.".a:index." mode: ".a:mode." return: ".string(retIndex))
    return retIndex
endfunction

function! s:quick_info_seek(module, mode, index)
    let retIndex = -1
    let infoList = systemlist("ls ".GetVimDir(1,"quickfix")."/info.".a:module.".*")
    for infoFile in infoList
        if filereadable(infoFile)
            let data = sync#read_list(a:module, infoFile, 'b', 1)
            let infoDic = eval(get(data, 0, ''))
            "let infoDic = eval(get(readfile(infoFile, 'b', 1), 0, ''))
            call PrintMsg("file", a:module." seek: ".string(infoDic))

            if a:mode == "index"
                if infoDic.index == a:index 
                    let retIndex = infoDic.index
                    break
                endif
            elseif a:mode == "index_next"
                let indexVal = index(infoDic.index_next, a:index)    
                if indexVal >= 0 
                    let retIndex = infoDic.index
                    break
                endif
            elseif a:mode == "index_prev"
                if infoDic.index_prev == a:index 
                    let retIndex = infoDic.index
                    break
                endif 
            endif
        endif
    endfor

    call PrintMsg("file", a:module." seek from info.".a:index." mode: ".a:mode." return: ".retIndex)
    return retIndex
endfunction

function! s:quick_find_oldest(module, indexList)
    call PrintMsg("file", a:module." find oldest from ".string(a:indexList))
    let timeMin = localtime()
    let retIndex = -1
    let timeIndex = 0 
    for timeIndex in a:indexList
        let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".timeIndex
        if filereadable(infoFile)
            let data = sync#read_list(a:module, infoFile, 'b', 1)
            let infoDic = eval(get(data, 0, ''))
            "let infoDic = eval(get(readfile(infoFile, 'b', 1), 0, ''))
            if timeMin > infoDic.time 
                let timeMin = infoDic.time
                let retIndex = timeIndex
            endif
        endif
    endfor

    call PrintMsg("file", a:module." find oldest: ".retIndex)
    return retIndex
endfunction

function! s:quick_find_newest(module, indexList)
    call PrintMsg("file", a:module." find newest from ".string(a:indexList))

    let timeMax = 0 
    let retIndex = -1
    let timeIndex = 0 
    for timeIndex in a:indexList
        let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".timeIndex
        if filereadable(infoFile)
            let data = sync#read_list(a:module, infoFile, 'b', 1)
            let infoDic = eval(get(data, 0, ''))
            "let infoDic = eval(get(readfile(infoFile, 'b', 1), 0, ''))
            if timeMax < infoDic.time 
                let timeMax = infoDic.time
                let retIndex = timeIndex
            endif
        endif
    endfor

    call PrintMsg("file", a:module." find newest: ".retIndex)
    return retIndex
endfunction

function! s:quick_new_index(module, start, exclude)
    call PrintMsg("file", a:module." new start: ".a:start." exclude: ".string(a:exclude))
    let siteIndex = g:quickfix_index_max
    let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".a:start
    if filereadable(infoFile)
        let data = sync#read_list(a:module, infoFile, 'b', 1)
        let infoDic = eval(get(data, 0, ''))
        "let infoDic = eval(get(readfile(infoFile, 'b', 1), 0, ''))
        let indexList = copy(infoDic.index_next)
        while len(indexList) > 0
            let siteIndex = indexList[0] 
            let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".siteIndex
            if filereadable(infoFile)
                call remove(indexList, 0)
            else
                break
            endif
        endwhile 

        if index(a:exclude, siteIndex) >= 0 
            let siteIndex = g:quickfix_index_max
        else
            if len(indexList) == 0
                let siteIndex = g:quickfix_index_max
            else
                call PrintMsg("file", a:module." new find: ".siteIndex." because info next")
            endif
        endif
    endif

    if siteIndex == g:quickfix_index_max
        let siteIndex = 0
        while siteIndex < g:quickfix_index_max
            if index(a:exclude, siteIndex) >= 0 
                let siteIndex += 1
                continue
            endif

            let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".siteIndex
            if !filereadable(infoFile)
                break
            endif
            let siteIndex += 1
        endwhile

        if siteIndex != g:quickfix_index_max 
            call PrintMsg("file", a:module." new find: ".siteIndex." because info file")
        endif
    endif

    if siteIndex == g:quickfix_index_max
        let siteIndex = s:quick_find_oldest(a:module, s:qfix_index_all)
        if siteIndex < 0
            let siteIndex = g:quickfix_index_max
        endif

        if siteIndex != g:quickfix_index_max 
            call PrintMsg("file", a:module." new find: ".siteIndex." because time oldest")
        endif
    endif

    if siteIndex == g:quickfix_index_max 
        let siteIndex = a:start + 1
        if siteIndex == g:quickfix_index_max
            let siteIndex = 0 
        endif
    endif

    call s:quick_delete(a:module, siteIndex)
    return siteIndex
endfunction

function! s:quick_find_home(module)
    let homeIndex = 0
    let newTitle = getqflist({'title' : 1}).title
    while homeIndex < g:quickfix_index_max
        let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".homeIndex
        if filereadable(infoFile)
            let data = sync#read_list(a:module, infoFile, 'b', 1)
            let infoDic = eval(get(data, 0, ''))
            "let infoDic = eval(get(readfile(infoFile, 'b', 1), 0, ''))
            if infoDic.title == newTitle 
                call PrintMsg("file", a:module." find home: ".string(infoDic))
                return homeIndex
            endif    
        endif
        let homeIndex += 1
    endwhile
    return -1
endfunction

function! s:quick_dump_info(module)
    if !exists("g:quickfix_dump_enable") || g:quickfix_dump_enable == 0
        return
    endif

    let maxNextLen = 0
    let maxTitleLen = 0
    let homeIndex = 0
    while homeIndex < g:quickfix_index_max
        let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".homeIndex
        if filereadable(infoFile) 
            let data = sync#read_list(a:module, infoFile, 'b', 1)
            let infoDic = eval(get(data, 0, ''))
            "let infoDic = eval(get(readfile(infoFile, 'b', 1), 0, ''))
            if empty(infoDic)
                call PrintMsg("error", "info empty: ".infoFile)
                let homeIndex += 1
                continue
            endif

            if len(string(infoDic.index_next)) > maxNextLen
                let maxNextLen = len(string(infoDic.index_next))
            endif

            if len(string(infoDic.title)) > maxTitleLen
                let maxTitleLen = len(string(infoDic.title))
            endif
        endif
        let homeIndex += 1
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

    let homeIndex = 0
    while homeIndex < g:quickfix_index_max
        let infoFile = GetVimDir(1,"quickfix").'/info.'.a:module.".".homeIndex
        if filereadable(infoFile)
            let data = sync#read_list(a:module, infoFile, 'b', 1)
            let infoDic = eval(get(data, 0, ''))
            "let infoDic = eval(get(readfile(infoFile, 'b', 1), 0, ''))
            
            let indexInfo = printf("prev: %-2d index: %-2d ".nextFormat, infoDic.index_prev, infoDic.index, string(infoDic.index_next))
            let cursorInfo = printf("cursor: %d/%d", infoDic.fline, infoDic.fcol)
            let pickInfo = printf("pick: %-4d %-18s", infoDic.pick, cursorInfo)
            let fileInfo = printf(titleFormat." file: %s", infoDic.title, infoDic.fname)
            call PrintMsg("file", "map ".indexInfo." ".pickInfo." ".fileInfo)
        endif
        let homeIndex += 1
    endwhile
    call PrintMsg("file", "")
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

function! qfix#ctrl_main(module, mode)
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
            call qfix#ctrl_main(a:module, "close")        
        else
            call qfix#ctrl_main(a:module, "open")        
        endif
    elseif a:mode == "clear"
        call setqflist([], "r")
    elseif a:mode == "recover"
        silent! execute 'cc!'
    elseif a:mode == "recover-next"
        call s:quick_dump_info(a:module)
        call qfix#ctrl_main(a:module, "save")
        let nextIndex = s:quick_info_seek(a:module, "index_prev", s:qfix_index)
        if nextIndex >= 0
            call s:quick_load(a:module, nextIndex)
            return 0
        endif
        return -1
    elseif a:mode == "recover-prev"
        call s:quick_dump_info(a:module)
        call qfix#ctrl_main(a:module, "save")
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

        let homeIndex = s:quick_find_home(a:module)
        if homeIndex >= 0
            call s:quick_save(a:module, homeIndex)
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
        let retCode = s:quick_delete(a:module, s:qfix_index)
        if retCode == 0
            call s:quick_dump_info(a:module)
            call setqflist([], "r")

            let loadIndex = s:quick_info_seek(a:module, "index", s:qfix_index_prev)
            if loadIndex >= 0
                call s:quick_load(a:module, loadIndex)
                return 0
            else
                let indexList = copy(s:qfix_index_next)
                while len(indexList) > 0
                    let nextIndex = s:quick_find_newest(a:module, indexList)
                    if nextIndex < 0
                        call filter(indexList, 0)
                        break
                    endif

                    let loadIndex = s:quick_info_seek(a:module, "index", nextIndex)
                    if loadIndex < 0
                        let index = index(indexList, nextIndex)    
                        call remove(indexList, index)
                    else
                        call s:quick_load(a:module, loadIndex)
                        return 0
                    endif
                endwhile

                if len(indexList) == 0
                    let arrIndex = s:quick_get_index(a:module, "index_prev", s:qfix_index_prev)
                    while len(arrIndex) > 0
                        let loadIndex = s:quick_get_index(a:module, "index", arrIndex[0])
                        if len(loadIndex) > 0
                            call s:quick_load(a:module, loadIndex[0])
                            return 0
                        endif

                        let arrIndex = s:quick_get_index(a:module, "index_prev", arrIndex[0])
                    endwhile

                    let tmpList = []
                    let indexList = copy(s:qfix_index_next)
                    call PrintMsg("file", "start next: ".string(indexList))

                    while len(indexList) > 0
                        let nextIndex = s:quick_find_newest(a:module, indexList)
                        if nextIndex < 0
                            call filter(indexList, 0)
                            break
                        endif

                        let index = index(indexList, nextIndex)    
                        call remove(indexList, index)

                        let arrIndex = s:quick_get_index(a:module, "index_next", nextIndex)
                        while len(arrIndex) > 0
                            let newest = s:quick_find_newest(a:module, arrIndex)
                            if newest < 0
                                call filter(arrIndex, 0)
                                break
                            endif

                            let loadIndex = s:quick_get_index(a:module, "index", newest)
                            if len(loadIndex) <= 0
                                let index = index(arrIndex, newest)    
                                call remove(arrIndex, index)
                                call extend(tmpList, s:quick_get_index(a:module, "index_next", newest))
                            else
                                call s:quick_load(a:module, loadIndex[0])
                                return 0
                            endif
                        endwhile
                        
                        if len(indexList) == 0
                            call extend(indexList, tmpList)
                            call PrintMsg("file", "extend next: ".string(indexList))
                            call filter(tmpList, 0)
                        endif
                    endwhile
                endif
            endif

            let infoList = systemlist("ls ".GetVimDir(1,"quickfix")."/info.".a:module.".*")
            let tmpList = copy(infoList)
            for infoFile in infoList
                if !filereadable(infoFile)
                    let index = index(tmpList, infoFile)    
                    call remove(tmpList, index)
                endif
            endfor

            if len(tmpList) == 0 
                let indexFile = GetVimDir(1,"quickfix").'/index.'.a:module
                if filereadable(indexFile)
                    call delete(indexFile)
                endif
                return 0
            endif

            call PrintMsg("error", "index: ".s:qfix_index." is bad")
            return -1
        endif
    elseif a:mode == "home"
        call s:quick_dump_info(a:module)
        let homeIndex = s:quick_find_home(a:module)
        if homeIndex >= 0
            call s:quick_persist_list(a:module, homeIndex, getqflist())
            call s:quick_load(a:module, homeIndex)
            return homeIndex
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
function! qfix#csfind(ccmd)
    let csarg = expand('<cword>')
    call PrintMsg("file", "CSFind: ".csarg)
    call ToggleWindow("allclose")
    call qfix#ctrl_main(g:quickfix_module, "save")
    call qfix#ctrl_main(g:quickfix_module, "clear")
    if g:quickfix_module != "csfind"
        let g:quickfix_module = "csfind"
        if exists("s:qfix_index")
            unlet s:qfix_index
        endif
        call qfix#ctrl_main(g:quickfix_module, "load")
        call qfix#ctrl_main(g:quickfix_module, "clear")
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
    call qfix#ctrl_main(g:quickfix_module, "home")
    call qfix#ctrl_main(g:quickfix_module, "open")
endfunction

function! qfix#grep_find()
    let csarg = expand('<cword>')
    silent! normal! mX

    call PrintMsg("file", "GrepFind: ".csarg)
    call ToggleWindow("allclose")
    call qfix#ctrl_main(g:quickfix_module, "save")
    call qfix#ctrl_main(g:quickfix_module, "clear")
    if g:quickfix_module != "grep"
        let g:quickfix_module = "grep"
        if exists("s:qfix_index")
            unlet s:qfix_index
        endif
        call qfix#ctrl_main(g:quickfix_module, "load")
        call qfix#ctrl_main(g:quickfix_module, "clear")
    endif

    silent! normal! g`X
    silent! delmarks X
    execute "Rgrep"

    if empty(getqflist())
        return
    endif

    call setqflist([], 'a', {'quickfixtextfunc': 's:grep_format'}) 
    call qfix#ctrl_main(g:quickfix_module, "home")
    call qfix#ctrl_main(g:quickfix_module, "open")
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
