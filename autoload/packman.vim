vim9script

# --------------------------------------------
# vim9-packman: Vim9script package manager
# Async (parallel) git operations via job_start
# --------------------------------------------

g:packman_pending_jobs = 0
g:packman_lock = {}

# --------------------------------------------
# Job callbacks (must be global for job_start to access)
# --------------------------------------------

export def JobExit(job: job, status: number): void
  g:packman_pending_jobs -= 1

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
    var name = packman#plugin#PluginName(repo)
    try
      execute 'packadd ' .. name
    catch
    endtry
  endfor

  system('helptags ' .. shellescape(g:packman_plugin_dir .. '/*/doc'))

  packman#notify#Notify('plugins ready')
enddef

# --------------------------------------------
# Install plugins (parallel)
# --------------------------------------------

export def PackmanInstall(plugins: list<string> = g:packman_plugins): void
  packman#git#CheckGit()
  packman#plugin#EnsurePluginDir()
  packman#lockfile#LockfileRead()

  var to_install: list<string> = []
  for repo in plugins
    var path = packman#plugin#PluginPath(repo)
    if !isdirectory(path)
      to_install->add(repo)
    endif
  endfor

  if to_install->empty()
    packman#notify#Notify('all plugins already installed')
    Reinit()
    return
  endif

  for repo in to_install
    var url = packman#git#GitUrl(repo)
    var path = packman#plugin#PluginPath(repo)
    var cmd = 'git clone --depth 1 ' .. shellescape(url) .. ' ' .. shellescape(path)
    packman#notify#Notify('installing ' .. repo)
    g:packman_pending_jobs += 1

    job_start(cmd, {
      exit_cb: function('packman#JobExit'),
      in_io: 'null',
      out_io: 'null',
      err_io: 'null',
    })
  endfor
enddef

# --------------------------------------------
# Sync init: install missing plugins + load all plugins
# --------------------------------------------

export def PackmanInit(plugins: list<string> = g:packman_plugins): void
  packman#git#CheckGit()
  packman#plugin#EnsurePluginDir()
  packman#lockfile#LockfileRead()

  var to_install: list<string> = []
  for repo in plugins
    var path = packman#plugin#PluginPath(repo)
    if !isdirectory(path)
      to_install->add(repo)
    endif
  endfor

  if to_install->empty()
    packman#notify#Notify('all plugins already installed')
    Reinit()
    return
  endif

  for repo in to_install
    var url = packman#git#GitUrl(repo)
    var path = packman#plugin#PluginPath(repo)
    var cmd = 'git clone --depth 1 ' .. shellescape(url) .. ' ' .. shellescape(path)
    packman#notify#Notify('installing ' .. repo)
    system(cmd)
    if v:shell_error != 0
      packman#notify#Notify('failed to install ' .. repo)
    endif
  endfor
  Reinit()
enddef

# --------------------------------------------
# Deprecated: use PackmanInit() instead
# --------------------------------------------

export def PackmanInstallSync(plugins: list<string> = g:packman_plugins): void
  PackmanInit(plugins)
enddef

# --------------------------------------------
# Update plugins (parallel)
# --------------------------------------------

export def PackmanUpdate(plugins: list<string> = g:packman_plugins): void
  packman#git#CheckGit()
  packman#lockfile#LockfileRead()

  var to_update: list<string> = []
  for repo in plugins
    var path = packman#plugin#PluginPath(repo)
    if isdirectory(path)
      to_update->add(repo)
    endif
  endfor

  if to_update->empty()
    packman#notify#Notify('no plugins to update')
    return
  endif

  for repo in to_update
    var path = packman#plugin#PluginPath(repo)
    var cmd = 'git -C ' .. shellescape(path) .. ' pull --ff-only'
    packman#notify#Notify('updating ' .. repo)
    g:packman_pending_jobs += 1

    job_start(cmd, {
      exit_cb: function('packman#JobExit'),
      in_io: 'null',
      out_io: 'null',
      err_io: 'null',
    })
  endfor

  timer_start(100, function('packman#UpdateLockfile'))
enddef

export def UpdateLockfile(timer: number): void
  if g:packman_pending_jobs > 0
    timer_start(100, function('packman#UpdateLockfile'))
    return
  endif

  for repo in g:packman_plugins
    var hash = packman#lockfile#GetCommitHash(repo)
    if !empty(hash)
      g:packman_lock[repo] = hash
    endif
  endfor

  packman#lockfile#LockfileWrite()
  packman#notify#Notify('lockfile updated')
enddef

# --------------------------------------------
# Clean unused plugins
# --------------------------------------------

export def PackmanClean(): void
  if !isdirectory(g:packman_plugin_dir)
    return
  endif

  var installed = glob(g:packman_plugin_dir .. '/*', v:true, v:true)
  var allowed = {}
  for repo in g:packman_plugins
    allowed[packman#plugin#PluginName(repo)] = v:true
  endfor

  var removed = 0
  for dir in installed
    var name = fnamemodify(dir, ':t')
    if !allowed->has_key(name)
      packman#notify#Notify('removing ' .. name)
      delete(dir, 'rf')
      removed += 1
    endif
  endfor

  if removed == 0
    packman#notify#Notify('nothing to clean')
  else
    packman#notify#Notify('removed ' .. removed .. ' plugin(s)')
  endif
enddef

# --------------------------------------------
# Show plugin status
# --------------------------------------------

export def PackmanStatus(): void
  packman#lockfile#LockfileRead()

  echo printf('%-40s %-10s %s', 'Plugin', 'Status', 'Commit')
  echo printf('%-40s %-10s %s', '------', '------', '------')

  for repo in g:packman_plugins
    var name = packman#plugin#PluginName(repo)
    var path = packman#plugin#PluginPath(repo)
    var status = 'missing'
    var commit = ''

    if isdirectory(path)
      status = 'installed'
      commit = packman#lockfile#GetCommitHash(repo)[0:7]
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

export def PackmanLock(): void
  packman#lockfile#LockfileRead()

  for repo in g:packman_plugins
    var hash = packman#lockfile#GetCommitHash(repo)
    if !empty(hash)
      g:packman_lock[repo] = hash
    endif
  endfor

  packman#lockfile#LockfileWrite()
  packman#notify#Notify('lockfile written to ' .. g:packman_lockfile)
enddef
