vim9script

# --------------------------------------------
# vim9-packman: Vim9script package manager
# Async (parallel) git operations via job_start
# --------------------------------------------

g:packman_pending_jobs = 0
g:packman_lock = {}

# --------------------------------------------
# Helpers
# --------------------------------------------

def CheckGit(): void
  if !executable('git')
    echoerr 'Git is required to install plugins'
  endif
enddef

def EnsurePluginDir(): void
  if !isdirectory(g:packman_plugin_dir)
    mkdir(g:packman_plugin_dir, 'p')
  endif
enddef

def PluginName(repo: string): string
  return fnamemodify(repo, ':t')
enddef

def PluginPath(repo: string): string
  return g:packman_plugin_dir .. '/' .. PluginName(repo)
enddef

def GitUrl(repo: string): string
  return 'https://github.com/' .. repo .. '.git'
enddef

# --------------------------------------------
# Lockfile
# --------------------------------------------

def LockfileRead(): void
  if filereadable(g:packman_lockfile)
    execute 'source ' .. shellescape(g:packman_lockfile)
  endif
enddef

def LockfileWrite(): void
  var lines = ['vim9script', '', 'g:packman_lock = {']
  for repo in sort(keys(g:packman_lock))
    lines->add('  ' .. string(repo) .. ': ' .. string(g:packman_lock[repo]) .. ',')
  endfor
  lines->add('}')

  writefile(lines, g:packman_lockfile)
enddef

def GetCommitHash(repo: string): string
  var path = PluginPath(repo)
  if !isdirectory(path)
    return ''
  endif
  var result = system('git -C ' .. shellescape(path) .. ' rev-parse HEAD')
  return result->trim()
enddef

# --------------------------------------------
# Job callbacks (must be global for job_start to access)
# --------------------------------------------

def JobExit(job: job, status: number): void
  g:packman_pending_jobs -= 1

  if status != 0
    echohl ErrorMsg
    echom 'packman: job failed (exit ' .. status .. ')'
    echohl None
  endif

  if g:packman_pending_jobs <= 0
    g:packman_pending_jobs = 0
    Reinit()
  endif
enddef

# --------------------------------------------
# Reinit after all jobs complete
# --------------------------------------------

def Reinit(): void
  packloadall!

  for repo in g:packman_plugins
    var name = PluginName(repo)
    try
      execute 'packadd ' .. name
    catch
    endtry
  endfor

  # Generate help tags for all pack plugins
  system('helptags ' .. shellescape(g:packman_plugin_dir .. '/*/doc'))

  echom 'packman: plugins ready'
enddef

# --------------------------------------------
# Install plugins (parallel)
# --------------------------------------------

def PackmanInstall(plugins: list<string> = g:packman_plugins): void
  CheckGit()
  EnsurePluginDir()
  LockfileRead()

  var to_install: list<string> = []
  for repo in plugins
    var path = PluginPath(repo)
    if !isdirectory(path)
      to_install->add(repo)
    endif
  endfor

  if to_install->empty()
    echom 'packman: all plugins already installed'
    Reinit()
    return
  endif

  for repo in to_install
    var url = GitUrl(repo)
    var path = PluginPath(repo)
    var cmd = 'git clone --depth 1 ' .. shellescape(url) .. ' ' .. shellescape(path)

    g:packman_pending_jobs += 1
    echom 'packman: installing ' .. repo

    job_start(cmd, {
      exit_cb: function('packman#JobExit'),
      in_io: 'null',
      out_io: 'null',
      err_io: 'null',
    })
  endfor
enddef

# --------------------------------------------
# Update plugins (parallel)
# --------------------------------------------

def PackmanUpdate(plugins: list<string> = g:packman_plugins): void
  CheckGit()
  LockfileRead()

  var to_update: list<string> = []
  for repo in plugins
    var path = PluginPath(repo)
    if isdirectory(path)
      to_update->add(repo)
    endif
  endfor

  if to_update->empty()
    echom 'packman: no plugins to update'
    return
  endif

  for repo in to_update
    var path = PluginPath(repo)
    var cmd = 'git -C ' .. shellescape(path) .. ' pull --ff-only'

    g:packman_pending_jobs += 1
    echom 'packman: updating ' .. repo

    job_start(cmd, {
      exit_cb: function('packman#JobExit'),
      in_io: 'null',
      out_io: 'null',
      err_io: 'null',
    })
  endfor

  # After all jobs, update lockfile with new commit hashes
  timer_start(100, function('packman#UpdateLockfile'))
enddef

def UpdateLockfile(timer: number): void
  if g:packman_pending_jobs > 0
    timer_start(100, function('s:UpdateLockfile'))
    return
  endif

  for repo in g:packman_plugins
    var hash = GetCommitHash(repo)
    if !empty(hash)
      g:packman_lock[repo] = hash
    endif
  endfor

  LockfileWrite()
  echom 'packman: lockfile updated'
enddef

# --------------------------------------------
# Clean unused plugins
# --------------------------------------------

def PackmanClean(): void
  if !isdirectory(g:packman_plugin_dir)
    return
  endif

  var installed = glob(g:packman_plugin_dir .. '/*', v:true, v:true)
  var allowed = {}
  for repo in g:packman_plugins
    allowed[PluginName(repo)] = v:true
  endfor

  var removed = 0
  for dir in installed
    var name = fnamemodify(dir, ':t')
    if !allowed->has_key(name)
      echom 'packman: removing ' .. name
      delete(dir, 'rf')
      removed += 1
    endif
  endfor

  if removed == 0
    echom 'packman: nothing to clean'
  else
    echom 'packman: removed ' .. removed .. ' plugin(s)'
  endif
enddef

# --------------------------------------------
# Show plugin status
# --------------------------------------------

def PackmanStatus(): void
  LockfileRead()

  echo printf('%-40s %-10s %s', 'Plugin', 'Status', 'Commit')
  echo printf('%-40s %-10s %s', '------', '------', '------')

  for repo in g:packman_plugins
    var name = PluginName(repo)
    var path = PluginPath(repo)
    var status = 'missing'
    var commit = ''

    if isdirectory(path)
      status = 'installed'
      commit = GetCommitHash(repo)[0:7]
      if g:packman_lock->has_key(repo)
        var pinned = g:packman_lock[repo][0:7]
        if pinned != commit
          status = 'outdated'
        endif
      endif
    endif

    echo printf('%-40s %-10s %s', repo, status, commit)
  endfor
enddef

# --------------------------------------------
# Generate/update lockfile
# --------------------------------------------

def PackmanLock(): void
  LockfileRead()

  for repo in g:packman_plugins
    var hash = GetCommitHash(repo)
    if !empty(hash)
      g:packman_lock[repo] = hash
    endif
  endfor

  LockfileWrite()
  echom 'packman: lockfile written to ' .. g:packman_lockfile
enddef
