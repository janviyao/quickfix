" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

" Location of the grep utility
if !exists("Grep_Path")
    let Grep_Path = 'grep'
endif

" Table containing information about various grep commands.
"   command path, option prefix character, command options and the search
"   pattern expression option
let s:cmd_table = {
            \   'csfind' : {
            \     'cmdpath' : g:Grep_Path,
            \     'expropt' : '--',
            \     'nulldev' : g:Grep_Null_Device
            \   },
            \   'Rgrep' : {
            \     'cmdpath' : g:Ucg_Path,
            \     'expropt' : '',
            \     'nulldev' : ''
            \   }
            \ }

" warnMsg
" Display a warning message
function! s:warnMsg(msg) abort
    echohl WarningMsg | echomsg a:msg | echohl None
endfunction

let s:grep_cmd_job = 0
let s:grep_tempfile = ''

" deleteTempFile()
" Delete the temporary file created on MS-Windows to run the grep command
function! s:deleteTempFile() abort
    if has('win32') && !has('win32unix') && (&shell =~ 'cmd.exe')
        if exists('s:grep_tempfile') && s:grep_tempfile != ''
            " Delete the temporary cmd file created on MS-Windows
            call delete(s:grep_tempfile)
            let s:grep_tempfile = ''
        endif
    endif
endfunction

" cmd_output_cb()
" Add output (single line) from a grep command to the quickfix list
function! cmd_output_cb(qf_id, channel, msg) abort
    let job = ch_getjob(a:channel)
    if job_status(job) == 'fail'
        call s:warnMsg('Error: Job not found in grep command output callback')
        return
    endif

    " Check whether the quickfix list is still present
    if s:Grep_Use_QfID
        let l = getqflist({'id' : a:qf_id})
        if !has_key(l, 'id') || l.id == 0
            " Quickfix list is not present. Stop the search.
            call job_stop(job)
            return
        endif

        call setqflist([], 'a', {'id' : a:qf_id,
                    \ 'efm' : '%f:%\\s%#%l:%c:%m,%f:%\s%#%l:%m',
                    \ 'lines' : [a:msg]})
    else
        let old_efm = &efm
        set efm=%f:%\\s%#%l:%c:%m,%f:%\\s%#%l:%m
        caddexpr a:msg . "\n"
        let &efm = old_efm
    endif
endfunction

" chan_close_cb
" Close callback for the grep command channel. No more grep output is
" available.
function! chan_close_cb(qf_id, channel) abort
    let job = ch_getjob(a:channel)
    if job_status(job) == 'fail'
        call s:warnMsg('Error: Job not found in grep channel close callback')
        return
    endif
    let emsg = '[Search command exited with status ' . job_info(job).exitval . ']'

    " Check whether the quickfix list is still present
    if s:Grep_Use_QfID
        let l = getqflist({'id' : a:qf_id})
        if has_key(l, 'id') && l.id == a:qf_id
            call setqflist([], 'a', {'id' : a:qf_id,
                        \ 'efm' : '%f:%\s%#%l:%m',
                        \ 'lines' : [emsg]})
        endif
    else
        caddexpr emsg
    endif
endfunction

" cmd_exit_cb()
" grep command exit handler
function! cmd_exit_cb(qf_id, job, exit_status) abort
    " Process the exit status only if the grep cmd is not interrupted
    " by another grep invocation
    if s:grep_cmd_job == a:job
        let s:grep_cmd_job = 0
        call s:deleteTempFile()
    endif
endfunction

" run_cmd_async()
" Run the grep command asynchronously
function! s:run_cmd_async(cmd, pattern, action) abort
    if s:grep_cmd_job isnot 0
        " If the job is already running for some other search, stop it.
        call job_stop(s:grep_cmd_job)
        caddexpr '[Search command interrupted]'
    endif

    let title = '[Search results for ' . a:pattern . ']'
    if a:action == 'add'
        caddexpr title . "\n"
    else
        cgetexpr title . "\n"
    endif
    "caddexpr 'Search cmd: "' . a:cmd . '"'
    call setqflist([], 'a', {'title' : title})
    " Save the quickfix list id, so that the grep output can be added to
    " the correct quickfix list
    let l = getqflist({'id' : 0})
    if has_key(l, 'id')
        let qf_id = l.id
    else
        let qf_id = -1
    endif

    if has('win32') && !has('win32unix') && (&shell =~ 'cmd.exe')
        let cmd_list = [a:cmd]
    else
        let cmd_list = [&shell, &shellcmdflag, a:cmd]
    endif
    let s:grep_cmd_job = job_start(cmd_list,
                \ {'callback' : functiontion('cmd_output_cb', [qf_id]),
                \ 'close_cb' : functiontion('chan_close_cb', [qf_id]),
                \ 'exit_cb' : functiontion('cmd_exit_cb', [qf_id]),
                \ 'in_io' : 'null'})

    if job_status(s:grep_cmd_job) == 'fail'
        let s:grep_cmd_job = 0
        call s:warnMsg('Error: Failed to start the grep command')
        call s:deleteTempFile()
        return
    endif

    " Open the grep output window
    if g:Grep_OpenQuickfixWindow == 1
        " Open the quickfix window below the current window
        botright copen
    endif
endfunction

" run_cmd()
" Run the specified grep command using the supplied pattern
function! s:run_cmd(cmd, pattern, action) abort
    if has('win32') && !has('win32unix') && (&shell =~ 'cmd.exe')
        " Windows does not correctly deal with commands that have more than 1
        " set of double quotes.  It will strip them all resulting in:
        " 'C:\Program' is not recognized as an internal or external command
        " operable program or batch file.  To work around this, place the
        " command inside a batch file and call the batch file.
        " Do this only on Win2K, WinXP and above.
        let s:grep_tempfile = fnamemodify(tempname(), ':h:8') . '\mygrep.cmd'
        call writefile(['@echo off', a:cmd], s:grep_tempfile)

        if g:Grep_Run_Async
            call s:run_cmd_async(s:grep_tempfile, a:pattern, a:action)
            return
        endif
        let cmd_output = system('"' . s:grep_tempfile . '"')

        if exists('s:grep_tempfile')
            " Delete the temporary cmd file created on MS-Windows
            call delete(s:grep_tempfile)
        endif
    else
        if g:Grep_Run_Async
            return s:run_cmd_async(a:cmd, a:pattern, a:action)
        endif
        let cmd_output = system(a:cmd)
    endif

    " Do not check for the shell_error (return code from the command).
    " Even if there are valid matches, grep returns error codes if there
    " are problems with a few input files.

    if cmd_output == ''
        call s:warnMsg('Error: Pattern ' . a:pattern . ' not found')
        return
    endif

    let tmpfile = tempname()

    let old_verbose = &verbose
    set verbose&vim

    exe 'redir! > ' . tmpfile
    silent echon '[Search results for pattern: ' . a:pattern . "]\n"
    silent echon cmd_output
    redir END

    let &verbose = old_verbose

    let old_efm = &efm
    set efm=%f:%\\s%#%l:%c:%m,%f:%\\s%#%l:%m

    if a:action == 'add'
        execute 'silent! caddfile ' . tmpfile
    else
        execute 'silent! cgetfile ' . tmpfile
    endif

    let &efm = old_efm

    " Open the grep output window
    if g:Grep_OpenQuickfixWindow == 1
        " Open the quickfix window below the current window
        botright copen
    endif

    call delete(tmpfile)
endfunction

" parse_args()
" Parse arguments to the grep command. The expected order for the various
" arguments is:
" 	<grep_option[s]> <search_pattern> <file_pattern[s]>
" grep command-line flags are specified using the "-flag" format.
" the next argument is assumed to be the pattern.
" and the next arguments are assumed to be filenames or file patterns.
function! s:parse_args(cmd_name, args) abort
    let cmdopt = ''
    let pattern = ''
    let filepattern = ''

    let optprefix = s:cmd_table[a:cmd_name].optprefix

    for one_arg in a:args
        if one_arg[0] == optprefix && pattern == ''
            " Process grep arguments at the beginning of the argument list
            let cmdopt = cmdopt . ' ' . one_arg
        elseif pattern == ''
            " Only one search pattern can be specified
            let pattern = shellescape(one_arg)
        else
            " More than one file patterns can be specified
            if filepattern != ''
                let filepattern = filepattern . ' ' . one_arg
            else
                let filepattern = one_arg
            endif
        endif
    endfor

    return [cmdopt, pattern, filepattern]
endfunction

" recursive_search_cmd
" Returns TRUE if a command recursively searches by default.
function! s:recursive_search_cmd(cmd_name) abort
    return a:cmd_name == 'ag' ||
                \ a:cmd_name == 'rg' ||
                \ a:cmd_name == 'ack' ||
                \ a:cmd_name == 'git' ||
                \ a:cmd_name == 'pt' ||
                \ a:cmd_name == 'ucg'
endfunction

" format_cmd()
" Generate the full command to run based on the user supplied command name,
" options, pattern and file names.
function! s:format_cmd(cmd_name, useropts, pattern, filenames) abort
    if !has_key(s:cmd_table, a:cmd_name)
        call s:warnMsg('Error: Unsupported command ' . a:cmd_name)
        return ''
    endif

    if has('win32')
        " On MS-Windows, convert the program pathname to 8.3 style pathname.
        " Otherwise, using a path with space characters causes problems.
        let s:cmd_table[a:cmd_name].cmdpath = fnamemodify(s:cmd_table[a:cmd_name].cmdpath, ':8')
    endif

    let cmdopt = s:cmd_table[a:cmd_name].defopts
    if s:cmd_table[a:cmd_name].opts != ''
        let cmdopt = cmdopt . ' ' . s:cmd_table[a:cmd_name].opts
    endif

    if a:useropts != ''
        let cmdopt = cmdopt . ' ' . a:useropts
    endif

    if s:cmd_table[a:cmd_name].expropt != ''
        let cmdopt = cmdopt . ' ' . s:cmd_table[a:cmd_name].expropt
    endif

    let fullcmd = s:cmd_table[a:cmd_name].cmdpath . ' ' .
                \ cmdopt . ' ' .
                \ a:pattern

    if a:filenames != ''
        let fullcmd = fullcmd . ' ' . a:filenames
    endif

    if s:cmd_table[a:cmd_name].nulldev != ''
        let fullcmd = fullcmd . ' ' . s:cmd_table[a:cmd_name].nulldev
    endif

    return fullcmd
endfunction

" quick_run()
" Run the specified grep command
function! quick_run(cmd_name, grep_cmd, action, ...) abort
    if a:0 > 0 && (a:1 == '-?' || a:1 == '-h')
        return
    endif

    " Parse the arguments and get the grep options, search pattern
    " and list of file names/patterns
    let [opts, pattern, filenames] = s:parse_args(a:grep_cmd, a:000)

    " Get the identifier and file list from user
    if pattern == '' 
        let pattern = input('Search for pattern: ', expand('<cword>'))
        if pattern == ''
            return
        endif
        let pattern = shellescape(pattern)
        echo "\r"
    endif

    if filenames == '' && !s:recursive_search_cmd(a:grep_cmd)
        let filenames = input('Search in files: ', g:Grep_Default_Filelist,
                    \ 'file')
        if filenames == ''
            return
        endif
        echo "\r"
    endif

    " Form the complete command line and run it
    let cmd = s:format_cmd(a:grep_cmd, opts, pattern, filenames)
    call s:run_cmd(cmd, pattern, a:action)
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
