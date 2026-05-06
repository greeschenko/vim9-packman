vim9script

# Lockfile operations

def LockfileReadLocal(): void
  if filereadable(g:packman_lockfile)
    execute 'source ' .. shellescape(g:packman_lockfile)
  endif
enddef

def LockfileWriteLocal(): void
  var lines = ['vim9script', '', 'g:packman_lock = {']
  for repo in sort(keys(g:packman_lock))
    lines->add('  ' .. string(repo) .. ': ' .. string(g:packman_lock[repo]) .. ',')
  endfor
  lines->add('}')
  writefile(lines, g:packman_lockfile)
enddef

def GetCommitHashLocal(repo: string): string
  var path = packman#plugin#PluginPath(repo)
  if !isdirectory(path)
    return ''
  endif
  var result = system('git -C ' .. shellescape(path) .. ' rev-parse HEAD')
  return result->trim()
enddef

# Public API
export def LockfileRead(): void
  LockfileReadLocal()
enddef

export def LockfileWrite(): void
  LockfileWriteLocal()
enddef

export def GetCommitHash(repo: string): string
  return GetCommitHashLocal(repo)
enddef
