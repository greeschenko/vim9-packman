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
# Notifications (popup or message history)
# --------------------------------------------

var notifications: list<string> = []

def Notify(msg: string): void
  # Add to list for later display
  notifications->add(msg)

  # Schedule display after VimEnter if not already scheduled
  if notifications->len() == 1
    timer_start(100, function('ShowNotifications'))
  endif
enddef

def ShowNotifications(timer: number): void
  if notifications->empty()
    return
  endif

  var text = notifications->copy()
  notifications = []

  # Create popup if Vim supports it
  if exists('*popup_create')
    var max_width = 0
    for line in text
      if line->strlen() > max_width
        max_width = line->strlen()
      endif
    endfor

    var opts: dict<any> = {
      line: 1,
      col: &columns - max_width - 3,
      minwidth: max_width + 2,
      minheight: text->len(),
      time: 5000,  # Auto-close after 5 seconds
      border: [],
      borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
      highlight: 'Comment',
    }

    popup_create(text, opts)
  else
    # Fallback: use echomsg
    for line in text
      echomsg 'packman: ' .. line
    endfor
  endif
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
    var name = PluginName(repo)
    try
      execute 'packadd ' .. name
    catch
    endtry
  endfor

  # Generate help tags for all pack plugins
  system('helptags ' .. shellescape(g:packman_plugin_dir .. '/*/doc'))

  Notify('plugins ready')
enddef

# --------------------------------------------
# Install plugins (parallel)
# --------------------------------------------

export def PackmanInstall(plugins: list<string> = g:packman_plugins): void
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
    Notify('all plugins already installed')
    Reinit()
    return
  endif

  for repo in to_install
    var url = GitUrl(repo)
    var path = PluginPath(repo)
    var cmd = 'git clone --depth 1 ' .. shellescape(url) .. ' ' .. shellescape(path)
    Notify('installing ' .. repo)
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
    Notify('all plugins already installed')
    Reinit()
    return
  endif

  for repo in to_install
    var url = GitUrl(repo)
    var path = PluginPath(repo)
    var cmd = 'git clone --depth 1 ' .. shellescape(url) .. ' ' .. shellescape(path)
    Notify('installing ' .. repo)
    system(cmd)
    if v:shell_error != 0
      Notify('failed to install ' .. repo)
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
    Notify('no plugins to update')
    return
  endif

  for repo in to_update
    var path = PluginPath(repo)
    var cmd = 'git -C ' .. shellescape(path) .. ' pull --ff-only'
    Notify('updating ' .. repo)
    g:packman_pending_jobs += 1
  
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

export def UpdateLockfile(timer: number): void
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
  Notify('lockfile updated')
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
    allowed[PluginName(repo)] = v:true
  endfor

  var removed = 0
  for dir in installed
    var name = fnamemodify(dir, ':t')
    if !allowed->has_key(name)
      Notify('removing ' .. name)
      delete(dir, 'rf')
      removed += 1
    endif
  endfor

  if removed == 0
    Notify('nothing to clean')
  else
    Notify('removed ' .. removed .. ' plugin(s)')
  endif
enddef

# --------------------------------------------
# Show plugin status
# --------------------------------------------

export def PackmanStatus(): void
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

export def PackmanLock(): void
  LockfileRead()

  for repo in g:packman_plugins
    var hash = GetCommitHash(repo)
    if !empty(hash)
      g:packman_lock[repo] = hash
    endif
  endfor

  LockfileWrite()
  Notify('lockfile written to ' .. g:packman_lockfile)
enddef
