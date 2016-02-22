function! s:append_line(expr, text) abort
  if bufnr(a:expr) == -1
    return
  endif
  let mode = mode()
  let oldnr = winnr()
  let winnr = bufwinnr(a:expr)

  if oldnr != winnr
    if winnr == -1
      silent exec "sp ".escape(bufname(bufnr(a:expr)), ' \')
      setlocal modifiable | call append('$', a:text) | setlocal nomodifiable
      silent hide
    else
      exec winnr.'wincmd w'
      setlocal modifiable | call append('$', a:text) | setlocal nomodifiable
    endif
  else
    setlocal modifiable | call append('$', a:text) | setlocal nomodifiable
  endif
  let pos = getpos('.')
  let pos[1] = line('$')
  let pos[2] = 9999
  call setpos('.', pos)

  exec oldnr.'wincmd w'
  if mode =~# '[sSvV]'
    silent! normal gv
  endif
  if mode !~# '[cC]'
    redraw
  endif
endfunction

function! s:append_part(expr, text) abort
  if bufnr(a:expr) == -1
    return
  endif
  let mode = mode()
  let oldnr = winnr()
  let winnr = bufwinnr(a:expr)
  if winnr == -1
    return
  endif

  if oldnr != winnr
    exec winnr.'wincmd w'
  endif
  let text = a:text
  if a:text =~ "\<c-l>.*$"
    let text = substitute(text, ".*\<c-l>", '', 'g')
    %d _
    redraw
  endif
  call setline('.', split(getline('.') . text, '\r\?\n', 1))

  let pos = getpos('.')
  let pos[1] = line('$')
  let pos[2] = 9999
  call setpos('.', pos)
  let b:line = getline('.')

  exec oldnr.'wincmd w'
  if mode =~# '[sSvV]'
    silent! normal gv
  endif
  if mode !~# '[cC]'
    redraw
  endif
endfunction

function! s:initialize_tail(job, handle) abort
  let wn = bufwinnr('__TERMINAL__')
  if wn != -1
    if wn != winnr()
      exe wn 'wincmd w'
    endif
  else
    silent exec 'rightbelow new __TERMINAL__'
  endif
  silent! %d _
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodified
  setlocal nomodifiable
  augroup Terminal
    au!
    autocmd BufWipeout <buffer> call s:terminate()
  augroup END
  let b:job = a:job
  let b:handle = a:handle
  nnoremap <buffer> <c-c> :<c-u>call job_stop(b:job)<cr>
  nnoremap <buffer> i :<c-u>call ch_sendraw(b:handle, input('INPUT: ') . "\n")<cr>
  wincmd p
  set lazyredraw
endfunction

function! s:sendkey(c) abort
  call ch_sendraw(b:handle, a:c, {'callback': 'terminal#partcb_out'})
  return ''
endfunction

function! s:sendcr() abort
  call setline('.', b:line)
  call ch_sendraw(b:handle, "\n", {'callback': 'terminal#partcb_out'})
  return ''
endfunction

function! s:sendcc() abort
  call job_stop(b:job)
  return ''
endfunction

function! s:initialize_terminal(job, handle) abort
  let wn = bufwinnr('__TERMINAL__')
  if wn != -1
    if wn != winnr()
      exe wn 'wincmd w'
    endif
  else
    silent exec 'rightbelow new __TERMINAL__'
  endif
  silent! %d _
  setlocal buftype=nofile bufhidden=wipe noswapfile
  augroup Terminal
    au!
    autocmd BufWipeout <buffer> call s:terminate()
    autocmd InsertCharPre <buffer> call s:sendkey(v:char)
  augroup END
  let b:job = a:job
  let b:handle = a:handle
  let b:line = ''
  inoremap <buffer> <silent> <c-c> <C-R>=<SID>sendcc()<cr>
  inoremap <buffer> <silent> <cr> <C-R>=<SID>sendcr()<cr>
  inoremap <buffer> <silent> <tab> <C-R>=<SID>sendkey("\t")<cr>
  inoremap <buffer> <silent> <bs> <C-R>=<SID>sendkey("\<bs>")<cr>
  startinsert!
  set lazyredraw
endfunction

function! s:terminate() abort
  if exists('b:handle')
    silent! call ch_close(b:handle)
    unlet b:handle
  endif
  if exists('b:job')
    silent! call job_stop(b:job, 'kill')
    unlet b:job
  endif
  augroup Terminal
    au!
  augroup END
endfunction

function! terminal#linecb(id, msg)
  for line in split(a:msg, '\r\?\n')
    call s:append_line('__TERMINAL__', line)
  endfor
endfunction

function! terminal#partcb_out(id, msg)
  let msg = substitute(a:msg, "\r", "", "g")
  call s:append_part('__TERMINAL__', msg)
endfunction

function! terminal#partcb_err(id, msg)
  let line = b:line
  call setline('.', '')
  let msg = substitute(a:msg, "\r", "", "g")
  call s:append_part('__TERMINAL__', msg)
  call s:append_part('__TERMINAL__', line)
endfunction

function! terminal#exitcb(job, code)
  call s:append_line('__TERMINAL__', string(a:job) . " with exit code " . string(a:code))
  augroup Terminal
    au!
  augroup END
endfunction

function! terminal#quickfix(id, msg)
  for line in split(a:msg, '\r\?\n')
    silent! caddexpr line
  endfor
endfunction

function! terminal#tail_file(arg) abort
  let job = job_start('tail -f ' . shellescape(a:arg))
  call job_setoptions(job, {'exit-cb': 'terminal#exitcb', 'stoponexit': 'kill'})
  let handle = job_getchannel(job)
  call ch_setoptions(handle, {'out-cb': 'terminal#linecb', 'mode': 'raw'})
  call s:initialize_tail(job, handle)
endfunction

function! terminal#tail_cmd(arg) abort
  let job = job_start(a:arg)
  call job_setoptions(job, {'exit-cb': 'terminal#exitcb', 'stoponexit': 'kill'})
  let handle = job_getchannel(job)
  call ch_setoptions(handle, {'out-cb': 'terminal#linecb', 'err-cb': 'terminal#linecb', 'mode': 'raw'})
  call s:initialize_tail(job, handle)
endfunction

function! terminal#quickfix_cmd(arg) abort
  let job = job_start(a:arg)
  call job_setoptions(job, {'exit-cb': 'terminal#exitcb', 'stoponexit': 'kill'})
  let handle = job_getchannel(job)
  call ch_setoptions(handle, {'out-cb': 'terminal#linecb', 'err-cb': 'terminal#linecb', 'mode': 'raw'})
  copen
  wincmd p
endfunction

function! terminal#cmd(arg) abort
  let job = job_start(a:arg)
  call job_setoptions(job, {'exit-cb': 'terminal#exitcb', 'stoponexit': 'kill'})
  let handle = job_getchannel(job)
  call ch_setoptions(handle, {'out-cb': 'terminal#partcb_out', 'err-cb': 'terminal#partcb_err', 'mode': 'raw'})
  call s:initialize_terminal(job, handle)
endfunction

