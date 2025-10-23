" Integration between Vim and its environment.
"
" Author: Peter Odding <peter@peterodding.com>
" Last Change: June 19, 2013
" URL: http://peterodding.com/code/vim/misc/

let s:enoimpl = "vim-misc %s: %s() hasn't been implemented for your platform! If you have suggestions, please get in touch at https://github.com/vmisc/vim-misc/issues"
let s:handlers = ['gnome-open', 'kde-open', 'exo-open', 'xdg-open', 'cygstart']

function! vmisc#misc#open#file(location, ...) " {{{1
  " Given a pathname or URL as the first argument, this opens the file with
  " the program associated with the file type. So for example a text file
  " might open in Vim, an `*.html` file would probably open in your web
  " browser and a media file would open in a media player.
  "
  " This should work on Windows, Mac OS X and most Linux distributions. If
  " this fails to find a file association, you can pass one or more external
  " commands to try as additional arguments. For example:
  "
  "     :call vmisc#misc#open#file('/path/to/my/file', 'firefox', 'google-chrome')
  "
  " This generally shouldn't be necessary but it might come in handy now and
  " then.
  if vmisc#misc#os#is_win()
    try
      call vmisc#shell#open_with_windows_shell(a:location)
    catch /^Vim\%((\a\+)\)\=:E117/
      let command = '!start CMD /C START "" %s'
      silent execute printf(command, vmisc#misc#escape#shell(a:location))
    endtry
    return
  elseif vmisc#misc#os#is_mac()
    call vmisc#misc#msg#debug("vim-misc %s: Detected Mac OS X, using 'open' command to open %s ..", g:vmisc#misc#version, string(a:location))
    let cmd = 'open ' . shellescape(a:location) . ' 2>&1'
    call s:handle_error(cmd, system(cmd))
    return
  else
    for handler in s:handlers + a:000
      if executable(handler)
        call vmisc#misc#msg#debug("vim-misc %s: Using '%s' to open '%s'.", g:vmisc#misc#version, handler, a:location)
        let cmd = shellescape(handler) . ' ' . shellescape(a:location) . ' 2>&1'
        call s:handle_error(cmd, system(cmd))
        return
      endif
    endfor
  endif
  throw printf(s:enoimpl, g:vmisc#misc#version, 'vmisc#misc#open#file')
endfunction

function! vmisc#misc#open#url(url) " {{{1
  " Given a URL as the first argument, this opens the URL in your preferred or
  " best available web browser:
  "
  " - In GUI environments a graphical web browser will open (or a new tab will
  "   be created in an existing window)
  " - In console Vim without a GUI environment, when you have any of `lynx`,
  "   `links` or `w3m` installed it will launch a command line web browser in
  "   front of Vim (temporarily suspending Vim)
  let url = a:url
  if url !~ '^\w\+://'
    call vmisc#misc#msg#debug("vim-misc %s: The URL %s doesn't contain a scheme, improvising ..", g:vmisc#misc#version, string(url))
    if url !~ '@'
      call vmisc#misc#msg#debug("vim-misc %s: Defaulting to http:// URL scheme ..", g:vmisc#misc#version)
      let url = 'http://' . url
    elseif url !~ '^mailto:'
      call vmisc#misc#msg#debug("vim-misc %s: Defaulting to mailto: URL scheme ..", g:vmisc#misc#version)
      let url = 'mailto:' . url
    endif
  endif
  let on_unix = has('unix')
  let not_on_mac = !vmisc#misc#os#is_mac()
  let no_gui_available = (has('gui_running') == 0 && $DISPLAY == '')
  if on_unix && not_on_mac && no_gui_available
    call vmisc#misc#msg#debug("vim-misc %s: Using command line web browser because no GUI seems to be available ..", g:vmisc#misc#version)
    for browser in ['lynx', 'links', 'w3m']
      call vmisc#misc#msg#debug("vim-misc %s: Checking whether %s command line web browser is installed ..", g:vmisc#misc#version, string(browser))
      if executable(browser)
        call vmisc#misc#msg#debug("vim-misc %s: Found %s, using it to open %s ..", g:vmisc#misc#version, string(browser), string(url))
        execute '!' . browser fnameescape(url)
        call s:handle_error(browser . ' ' . url, '')
        return
      endif
    endfor
  endif
  call vmisc#misc#msg#debug("vim-misc %s: Defaulting to GUI web browser to open %s ..", g:vmisc#misc#version, string(url))
  call vmisc#misc#open#file(url, 'firefox', 'google-chrome')
endfunction

function! s:handle_error(cmd, output) " {{{1
  if v:shell_error
    let message = "vim-misc %s: Failed to execute program! (command line: %s%s)"
    let output = strtrans(vmisc#misc#str#trim(a:output))
    if output != ''
      let output = ", output: " . string(output)
    endif
    throw printf(message, g:vmisc#misc#version, a:cmd, output)
  endif
endfunction

" vim: et ts=2 sw=2 fdm=marker
