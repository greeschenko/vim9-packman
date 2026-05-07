vim9script

# --------------------------------------------
# vim9-packman: Vim9script package manager
# Async (parallel) git operations via job_start
# --------------------------------------------

g:packman_pending_jobs = 0
g:packman_lock = {}

var check_results: list<dict<any>> = []
var check_pending = 0
var update_results: list<dict<any>> = []

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

  var total = to_install->len()
  var successes: list<string> = []
  var failures: list<string> = []

  # Setup status line for progress
  var saved_statusline = &statusline
  var saved_laststatus = &laststatus
  g:packman_status = 'Packman: Installing.'
  &statusline = '%{g:packman_status}'
  &laststatus = 2
  redrawstatus!

  for idx in range(total)
    var repo = to_install[idx]
    var url = packman#git#GitUrl(repo)
    var path = packman#plugin#PluginPath(repo)
    var cmd = 'git clone --depth 1 ' .. shellescape(url) .. ' ' .. shellescape(path) .. ' >/dev/null 2>&1'
    system(cmd)
    if v:shell_error != 0
      failures->add(repo)
    else
      successes->add(repo)
    endif
    g:packman_status ..= '.'
    redrawstatus!
  endfor

  # Restore status line
  &statusline = saved_statusline
  &laststatus = saved_laststatus
  unlet! g:packman_status
  redrawstatus!

  packman#notify#Notify('Packman: Installation Complete')
  packman#notify#Notify('')
  packman#notify#Notify('Success: ' .. successes->len())
  for repo in successes
    packman#notify#Notify('  ✓ ' .. repo)
  endfor
  if failures->len() > 0
    packman#notify#Notify('')
    packman#notify#Notify('Failed: ' .. failures->len())
    for repo in failures
      packman#notify#Notify('  ✗ ' .. repo)
    endfor
  endif

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

  update_results = []
  for repo in to_update
    var path = packman#plugin#PluginPath(repo)
    packman#notify#Notify('updating ' .. repo)
    g:packman_pending_jobs += 1

    var idx = update_results->len()
    update_results->add({repo: repo, status: -1, output: ''})
    var lcl_idx = idx

    job_start(['git', '-C', path, 'pull', '--ff-only'], {
      exit_cb: (j: job, status: number) => UpdateJobDone(lcl_idx, j, status),
      out_cb: (ch: channel, data: string) => CaptureUpdateOutput(lcl_idx, ch, data),
      err_cb: (ch: channel, data: string) => CaptureUpdateOutput(lcl_idx, ch, data),
      in_io: 'null',
    })
  endfor
enddef

def CaptureUpdateOutput(idx: number, channel: channel, data: string): void
  update_results[idx].output ..= data
enddef

def UpdateJobDone(idx: number, job: job, status: number): void
  update_results[idx].status = status
  g:packman_pending_jobs -= 1

  if g:packman_pending_jobs > 0
    return
  endif

  g:packman_pending_jobs = 0

  var successes: list<string> = []
  var failures: list<string> = []
  for r in update_results
    if r.status == 0
      successes->add(r.repo)
    else
      failures->add(r.repo)
    endif
  endfor

  if !empty(successes)
    packman#notify#Notify('Updated:')
    for repo in successes
      packman#notify#Notify('  ✓ ' .. repo)
    endfor
  endif

  if !empty(failures)
    packman#notify#Notify('Failed:')
    for repo in failures
      packman#notify#Notify('  ✗ ' .. repo)
    endfor
  endif

  if empty(successes) && empty(failures)
    packman#notify#Notify('nothing to update')
  endif

  var updated: dict<string> = {}
  for repo in g:packman_plugins
    var hash = packman#lockfile#GetCommitHash(repo)
    if !empty(hash)
      updated[repo] = hash
    endif
  endfor

  for [repo, hash] in items(g:packman_lock)
    if !updated->has_key(repo)
      updated[repo] = hash
    endif
  endfor

  g:packman_lock = updated

  if !empty(g:packman_lock)
    packman#lockfile#LockfileWrite()
  endif

  Reinit()
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

# --------------------------------------------
# Check for remote updates (async)
# --------------------------------------------

export def PackmanCheckUpdates(): void
  if check_pending > 0
    return
  endif

  packman#git#CheckGit()
  packman#lockfile#LockfileRead()

  check_results = []
  check_pending = 0

  for repo in g:packman_plugins
    var path = packman#plugin#PluginPath(repo)
    if !isdirectory(path)
      continue
    endif

    var local = system('git -C ' .. shellescape(path) .. ' rev-parse HEAD 2>/dev/null')->trim()
    if empty(local)
      continue
    endif

    check_pending += 1
    var idx = check_results->len()
    check_results->add({repo: repo, local: local})

    var lcl_idx = idx
    job_start(['git', '-C', path, 'ls-remote', 'origin', 'HEAD'], {
      out_cb: (ch: channel, data: string) => CaptureRemote(lcl_idx, ch, data),
      exit_cb: (j: job, status: number) => CheckRemoteDone(lcl_idx, j, status),
      err_io: 'null',
    })
  endfor

  if check_pending == 0
    packman#notify#Notify('no plugins to check')
  endif
enddef

def CaptureRemote(idx: number, channel: channel, data: string): void
  var trimmed = data->trim()
  if !empty(trimmed)
    var parts = trimmed->split('\t')
    if parts->len() >= 1
      check_results[idx].remote = parts[0]
    endif
  endif
enddef

def CheckRemoteDone(idx: number, job: job, status: number): void
  check_pending -= 1

  if check_pending > 0
    return
  endif

  var outdated: list<string> = []
  for r in check_results
    if r->has_key('remote') && !empty(r.remote)
      if r.local[ : 7] != r.remote[ : 7]
        outdated->add(r.repo)
      endif
    endif
  endfor

  if !empty(outdated)
    packman#notify#Notify('Updates available:')
    packman#notify#Notify('')
    for repo in outdated
      packman#notify#Notify('  -> ' .. repo)
    endfor
  else
    packman#notify#Notify('all plugins up to date')
  endif

  check_results = []
enddef
