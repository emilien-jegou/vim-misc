" Manipulation of UNIX file permissions.
"
" Author: Peter Odding <peter@peterodding.com>
" Last Change: June 30, 2014
" URL: http://peterodding.com/code/vim/misc/
"
" Vim's [writefile()][] function cannot set file permissions for newly created
" files and although Vim script has a function to get file permissions (see
" [getfperm()][]) there is no equivalent for changing a file's permissions.
"
" This omission breaks the otherwise very useful idiom of updating a file by
" writing its new contents to a temporary file and then renaming the temporary
" file into place (which is as close as you're going to get to atomically
" updating a file's contents on UNIX) because the file's permissions will not
" be preserved!
"
" **Here's a practical example:** My [vim-easytags][] plug-in writes tags file
" updates to a temporary file and renames the temporary file into place. When
" I use `sudo -s` on Ubuntu Linux it preserves my environment variables so my
" `~/.vimrc` and the [vim-easytags][] plug-in are still loaded. Now when a
" tags file is written the file becomes owned by root (my effective user id in
" the `sudo` session). Once I leave the `sudo` session I can no longer update
" my tags file because it's now owned by root … ಠ_ಠ
"
" [getfperm()]: http://vimdoc.sourceforge.net/htmldoc/eval.html#getfperm()
" [vim-easytags]: http://peterodding.com/code/vim/easytags/
" [writefile()]: http://vimdoc.sourceforge.net/htmldoc/eval.html#writefile()

function! vmisc#misc#perm#update(fname, contents)
  " Atomically update a file's contents while preserving the owner, group and
  " mode. The first argument is the pathname of the file to update (a string).
  " The second argument is the list of lines to be written to the file. Writes
  " the new contents to a temporary file and renames the temporary file into
  " place, thereby preventing readers from reading a partially written file.
  " Returns 1 if the file is successfully updated, 0 otherwise.
  "
  " Note that if `vmisc#misc#perm#get()` and `vmisc#misc#perm#set()` cannot be
  " used to preserve the file owner/group/mode the file is still updated using
  " a rename (for compatibility with non-UNIX systems and incompatible
  " `/usr/bin/stat` implementations) so in that case you can still lose the
  " file's owner/group/mode.
  let starttime = vmisc#misc#timer#start()
  let temporary_file = printf('%s.tmp', a:fname)
  call vmisc#misc#msg#debug("vim-misc %s: Writing new contents of %s to temporary file %s ..", g:vmisc#misc#version, a:fname, temporary_file)
  if writefile(a:contents, temporary_file) == 0
    call vmisc#misc#perm#set(temporary_file, vmisc#misc#perm#get(a:fname))
    call vmisc#misc#msg#debug("vim-misc %s: Replacing %s with %s ..", g:vmisc#misc#version, a:fname, temporary_file)
    if rename(temporary_file, a:fname) == 0
      call vmisc#misc#timer#stop("vim-misc %s: Successfully updated %s using atomic rename in %s.", g:vmisc#misc#version, a:fname, starttime)
      return 1
    endif
  endif
  if filereadable(temporary_file)
    call delete(temporary_file)
  endif
  return 0
endfunction

function! vmisc#misc#perm#get(fname)
  " Get the owner, group and permissions of the pathname given as the first
  " argument. Returns an opaque value which you can later pass to
  " `vmisc#misc#perm#set()`.
  let pathname = vmisc#misc#path#absolute(a:fname)
  if filereadable(pathname)
    let command = printf('stat --format %s %s', '%U:%G:%a', shellescape(pathname))
    let result = vmisc#misc#os#exec({'command': command, 'check': 0})
    if result['exit_code'] == 0 && len(result['stdout']) >= 1
      let tokens = split(result['stdout'][0], ':')
      if len(tokens) == 3
        let [owner, group, mode] = tokens
        let mode = '0' . mode
        call vmisc#misc#msg#debug("vim-misc %s: File %s has owner %s, group %s, mode %s.", g:vmisc#misc#version, pathname, owner, group, mode)
        return [owner, group, mode]
      endif
    endif
  endif
  return []
endfunction

function! vmisc#misc#perm#set(fname, perms)
  " Set the permissions (the second argument) of the pathname given as the
  " first argument. Expects a permissions value created by
  " `vmisc#misc#perm#get()`.
  if !empty(a:perms)
    let pathname = vmisc#misc#path#absolute(a:fname)
    let [owner, group, mode] = a:perms
    if s:run('chown %s:%s %s', owner, group, pathname) && s:run('chmod %s %s', mode, pathname)
      call vmisc#misc#msg#debug("vim-misc %s: Successfully set %s owner to %s, group to %s and permissions to %s.", g:vmisc#misc#version, pathname, owner, group, mode)
      return 1
    endif
  endif
  return 0
endfunction

function! s:run(command, ...)
  let args = map(copy(a:000), 'shellescape(v:val)')
  call insert(args, a:command, 0)
  let result = vmisc#misc#os#exec({'command': call('printf', args), 'check': 0})
  return result['exit_code'] == 0
endfunction
