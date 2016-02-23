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
  command! -nargs=1 -complete=file TailFile call terminal#tail_file(<f-args>)
endif
command! -nargs=1 -complete=file TailCmd call terminal#tail_cmd(<q-args>)
command! -nargs=1 -complete=file QuickFixCmd call terminal#quickfix_cmd(<q-args>)
command! -nargs=1 -complete=file Terminal call terminal#term(<q-args>)
