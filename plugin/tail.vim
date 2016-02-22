if index(map([
\ 'job_start',
\ 'job_getchannel',
\ 'job_stop',
\ 'job_setoptions',
\ 'ch_setoptions',
\], 'exists("*".v:val)'),0) != -1
  finish
endif
if executable('tail')
  command! -nargs=1 -complete=file TailFile call tail#file(<f-args>)
endif
command! -nargs=1 -complete=file TailCmd call tail#cmd(<q-args>)
command! -nargs=1 -complete=file QuickFixCmd call tail#quickfixcmd(<q-args>)
