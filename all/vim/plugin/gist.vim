"=============================================================================
" File: gist.vim
" Author: Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Last Change: 27-Jan-2009. Jan 2008
" Version: 1.8
" Usage:
"
"   :Gist
"     post whole text to gist.
"
"   :'<,'>Gist
"     post selected text to gist.
"
"   :Gist -p
"     post whole text to gist with private.
"
"   :Gist XXXXX
"     edit gist XXXXX.
"
"   :Gist -c XXXXX.
"     get gist XXXXX and put to clipboard.
"  
"   :Gist -l
"     list gists from mine.
"
"   :Gist -l mattn
"     list gists from mattn.
"
"   :Gist -la
"     list gists from all.
"
" Tips:
"   * if set g:gist_clip_command, gist.vim will copy the gist code
"       with option '-c'.
"
"     # mac
"     let g:gist_clip_command = 'pbcopy'
"
"     # linux
"     let g:gist_clip_command = 'xclip -selection clipboard'
"
"     # others(cygwin?)
"     let g:gist_clip_command = 'putclip'
"
"   * if you want to detect filetype from gist's filename...
"
"     # detect filetype if vim failed auto-detection.
"     let g:gist_detect_filetype = 1
"
"     # detect filetype always.
"     let g:gist_detect_filetype = 2
"
"   * if you want to open browser after the post...
"
"     let g:gist_open_browser_after_post = 1
"
"   * if you want to change the browser...
"
"     let g:gist_browser_command = 'w3m %URL%'
"
"       or
"
"     let g:gist_browser_command = 'opera %URL% &'
"
"     on windows, should work with your setting.
"
" GetLatestVimScripts: 2423 1 :AutoInstall: gist.vim

if &cp || (exists('g:loaded_gist_vim') && g:loaded_gist_vim)
  finish
endif
let g:loaded_gist_vim = 1

if (!exists('g:github_user') || !exists('g:github_token')) && !executable('git')
  echoerr "Gist: require 'git' command"
  finish
endif

if !executable('curl')
  echoerr "Gist: require 'curl' command"
  finish
endif

if !exists('g:gist_open_browser_after_post')
  let g:gist_open_browser_after_post = 0
endif

if !exists('g:gist_browser_command')
  if has('win32')
    let g:gist_browser_command = "!start rundll32 url.dll,FileProtocolHandler %URL%"
  else
    let g:gist_browser_command = "firefox %URL% &"
  endif
endif

if !exists('g:gist_detect_filetype')
  let g:gist_detect_filetype = 0
endif

function! s:nr2hex(nr)
  let n = a:nr
  let r = ""
  while n
    let r = '0123456789ABCDEF'[n % 16] . r
    let n = n / 16
  endwhile
  return r
endfunction

function! s:encodeURIComponent(instr)
  let instr = iconv(a:instr, &enc, "utf-8")
  let len = strlen(instr)
  let i = 0
  let outstr = ''
  while i < len
    let ch = instr[i]
    if ch =~# '[0-9A-Za-z-._~!''()*]'
      let outstr = outstr . ch
    elseif ch == ' '
      let outstr = outstr . '+'
    else
      let outstr = outstr . '%' . substitute('0' . s:nr2hex(char2nr(ch)), '^.*\(..\)$', '\1', '')
    endif
    let i = i + 1
  endwhile
  return outstr
endfunction

function! s:GistList(user, token, gistls)
  if a:gistls == '-all'
    let url = 'http://gist.github.com/gists'
  else
    let url = 'http://gist.github.com/'.a:gistls
  endif
  exec 'silent split gist:'.a:gistls
  exec 'silent 0r! curl -s '.url
  silent! %s/>/>\r/g
  silent! %s/</\r</g
  silent! %g/<pre/,/<\/pre/join!
  silent! %g/<span class="date"/,/<\/span/join
  silent! %g/^<span class="date"/s/> */>/g
  silent! %v/^\(gist:\|<pre>\|<span class="date">\)/d _
  silent! %s/<div[^>]*>/\r  /g
  silent! %s/<\/pre>/\r/g
  silent! %g/^gist:/,/<span class="date"/join
  silent! %s/<[^>]\+>//g
  silent! %s/\r//g
  silent! %s/&nbsp;/ /g
  silent! %s/&quot;/"/g
  silent! %s/&amp;/\&/g
  silent! %s/&gt;/>/g
  silent! %s/&lt;/</g
  silent! %s/&#\(\d\d\);/\=nr2char(submatch(1))/g
  setlocal nomodified
  syntax match SpecialKey /^gist: /he=e-2
  exec 'nnoremap <silent> <buffer> <cr> :call <SID>GistListAction()<cr>'
  normal! gg
endfunction

function! s:GistDetectFiletype(gistid)
  let url = 'http://gist.github.com/'.a:gistid
  let res = system('curl -s '.url)
  let res = substitute(res, '^.*<div class="meta">[\r\n ]*<div class="info">[\r\n ]*<span>\([^>]\+\)</span>.*$', '\1', '')
  let res = substitute(res, '.*\(\.[^\.]\+\)$', '\1', '')
  if res =~ '^\.'
    silent! exec "doau BufRead *".res
  else
    silent! exec "setlocal ft=".tolower(res)
  endif
endfunction

function! s:GistGet(user, token, gistid, clipboard)
  let url = 'http://gist.github.com/'.a:gistid.'.txt'
  exec 'silent split gist:'.a:gistid
  filetype detect
  exec 'silent 0r! curl -s '.url
  setlocal nomodified
  doau StdinReadPost <buffer>
  normal! gg
  if (&ft == '' && g:gist_detect_filetype == 1) || g:gist_detect_filetype == 2
    call s:GistDetectFiletype(a:gistid)
  endif
  if a:clipboard
    if exists('g:gist_clip_command')
      exec 'silent w !'.g:gist_clip_command
    else
      normal! ggVG"+y
    endif
  endif
endfunction

function! s:GistListAction()
  let line = getline('.')
  let mx = '^gist: \(\w\+\).*'
  if line =~# mx
    let gistid = substitute(line, mx, '\1', '')
    call s:GistGet(g:github_user, g:github_token, gistid, 0)
  endif
endfunction

function! s:GistPut(user, token, content, private)
  let ext = expand('%:e')
  let ext = len(ext) ? '.'.ext : ''
  let name = expand('%:t')
  let query = [
    \ 'file_ext[gistfile1]=%s',
    \ 'file_name[gistfile1]=%s',
    \ 'file_contents[gistfile1]=%s',
    \ 'login=%s',
    \ 'token=%s',
    \ ]
  if a:private
    call add(query, 'private=on')
  endif
  let squery = printf(join(query, '&'),
    \ s:encodeURIComponent(ext),
    \ s:encodeURIComponent(name),
    \ s:encodeURIComponent(a:content),
    \ s:encodeURIComponent(a:user),
    \ s:encodeURIComponent(a:token))
  unlet query

  let file = tempname()
  exec 'redir! > '.file 
  silent echo squery
  redir END
  echon " Posting it to gist... "
  let quote = &shellxquote == '"' ?  "'" : '"'
  let url = 'http://gist.github.com/gists'
  let res = system('curl -i -d @'.quote.file.quote.' '.url)
  call delete(file)
  let res = matchstr(split(res, "\n"), '^Location: ')
  let res = substitute(res, '^.*: ', '', '')
  echo 'done: '.res
  return res
endfunction

function! Gist(line1, line2, ...)
  if !exists('g:github_user')
    let g:github_user = substitute(system('git config --global github.user'), "\n", '', '')
  endif
  if !exists('g:github_token')
    let g:github_token = substitute(system('git config --global github.token'), "\n", '', '')
  endif

  let gistid = ''
  let gistls = ''
  let private = 0
  let clipboard = 0

  let args = (a:0 > 0) ? split(a:1, ' ') : []
  for arg in args
    let listmx = '^\(-l\|--list\)\s*\([^\s]\+\)\?$'
    if arg =~ '^\(-la\|--listall\)'
      let gistls = '-all'
    elseif arg =~ listmx
      let gistls = substitute(arg, listmx, '\2', '')
      if len(gistls) == 0
        let gistls = g:github_user
      endif
    elseif arg =~ '-p\|--private'
      let private = 1
    elseif arg =~ '^\w\+$'
      let gistid = arg
    elseif arg =~ '-c\|--clipboard'
      let clipboard = 1
    elseif len(arg) > 0
      echoerr 'Invalid arguments'
      unlet args
      return 0
    endif
  endfor
  unlet args
  "echo "gistid=".gistid
  "echo "gistls=".gistls
  "echo "private=".private
  "echo "clipboard=".clipboard

  if len(gistls) > 0
    call s:GistList(g:github_user, g:github_token, gistls)
  elseif len(gistid) > 0
    call s:GistGet(g:github_user, g:github_token, gistid, clipboard)
  else
    let content = join(getline(a:line1, a:line2), "\n")
    let url = s:GistPut(g:github_user, g:github_token, content, private)
    if len(url) > 0 && g:gist_open_browser_after_post
      let cmd = substitute(g:gist_browser_command, '%URL%', url, 'g')
      if cmd =~ '^!'
        silent! exec  cmd
      else
        call system(cmd)
      endif
    endif
  endif
  return 1
endfunction

command! -nargs=? -range=% Gist :call Gist(<line1>, <line2>, <f-args>)
