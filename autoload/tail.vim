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
  let pos[2] = 1
  call setpos('.', pos)

  exec oldnr.'wincmd w'
  if mode =~# '[sSvV]'
    silent! normal gv
  endif
  if mode !~# '[cC]'
    redraw
  endif
endfunction

function! s:initialize(job, handle) abort
  let wn = bufwinnr('__TAIL__')
  if wn != -1
    if wn != winnr()
      exe wn 'wincmd w'
    endif
  else
    silent exec 'rightbelow new __TAIL__'
  endif
  silent! %d _
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodified
  setlocal nomodifiable
  augroup Tail
    au!
    autocmd BufWipeout <buffer> call s:terminate()
  augroup END
  let b:job = a:job
  let b:handle = a:handle
  nnoremap <c-c> :<c-u>call job_stop(b:job)<cr>
  wincmd p
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
  augroup Tail
    au!
  augroup END
endfunction

function! tail#callback(id, msg)
  for line in split(a:msg, '\r\?\n')
    call s:append_buf('__TAIL__', line)
  endfor
endfunction

function! tail#exitcb(job, code)
  call s:append_buf('__TAIL__', string(a:job) . " with exit code " . string(a:code))
endfunction

function! tail#quickfix(id, msg)
  for line in split(a:msg, '\r\?\n')
    caddexpr line
  endfor
endfunction

function! tail#file(arg) abort
  let b:job = job_start('tail -f ' . shellescape(a:arg))
  call job_setoptions(b:job, {'exit-cb': 'tail#exitcb', 'stoponexit': 'kill'})
  let b:handle = job_getchannel(b:job)
  call ch_setoptions(b:handle, {'out-cb': 'tail#callback'})
  call s:initialize(b:job, b:handle)
endfunction

function! tail#cmd(arg) abort
  let b:job = job_start(a:arg)
  call job_setoptions(b:job, {'exit-cb': 'tail#exitcb', 'stoponexit': 'kill'})
  let b:handle = job_getchannel(b:job)
  call ch_setoptions(b:handle, {'out-cb': 'tail#callback'})
  call s:initialize(b:job, b:handle)
endfunction

function! tail#quickfix(arg) abort
  let b:job = job_start(a:arg)
  call job_setoptions(b:job, {'exit-cb': 'tail#exitcb', 'stoponexit': 'kill'})
  let b:handle = job_getchannel(b:job)
  call ch_setoptions(b:handle, {'out-cb': 'tail#quickfix'})
  call s:initialize(b:job, b:handle)
endfunction
