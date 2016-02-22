function! s:append_buf(expr, text)
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
  call setpos('.', pos)

  exec oldnr.'wincmd w'
  if mode =~# '[sSvV]'
    silent! normal gv
  endif
  redraw
endfunction

function! s:initialize() abort
  let wn = bufwinnr('__TAIL__')
  if wn != -1
    if wn != winnr()
      exe wn 'wincmd w'
    endif
    silent! %d _
  else
    silent exec 'rightbelow vnew __TAIL__'
  endif
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodified
  setlocal nomodifiable
  augroup Tail
    au!
    autocmd BufWipeout <buffer> call s:terminate()
  augroup END
  wincmd p
  set lazyredraw
endfunction

function! s:terminate() abort
  if exists('s:handle')
    silent! call ch_close(s:handle)
    unlet s:handle
  endif
  if exists('s:job')
    silent! call job_stop(s:job, 'kill')
    unlet s:job
  endif
  augroup Tail
    au!
  augroup END
endfunction

function! tail#callback(id, msg)
  for line in split(a:msg, '\r\?\n')
    call s:append_buf('__TAIL__', line)
  endfor
endfunction

function! tail#exitcb(id, msg)
  call s:append_buf('__TAIL__', 'EXITED')
endfunction

function! tail#file(arg) abort
  call s:terminate()
  call s:initialize()
  let s:job = job_start('tail -f ' . shellescape(a:arg))
  call job_setoptions(s:job, {'exit-cb': 'tail#exitcb', 'stoponexit': 'kill'})
  let s:handle = job_getchannel(s:job)
  call ch_setoptions(s:handle, {'out-cb': 'tail#callback'})
endfunction

function! tail#cmd(arg) abort
  call s:terminate()
  call s:initialize()
  let s:job = job_start(a:arg)
  call job_setoptions(s:job, {'exit-cb': 'tail#exitcb', 'stoponexit': 'kill'})
  let s:handle = job_getchannel(s:job)
  call ch_setoptions(s:handle, {'out-cb': 'tail#callback'})
endfunction
