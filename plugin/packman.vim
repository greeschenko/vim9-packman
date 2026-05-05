vim9script

# --------------------------------------------
# vim9-packman: plugin commands + auto-install
# --------------------------------------------

# Default configuration
if !exists('g:packman_plugins')
  g:packman_plugins = []
endif

if !exists('g:packman_plugin_dir')
  g:packman_plugin_dir = expand('~/.vim/pack/plugins/opt')
endif

if !exists('g:packman_auto_install')
  g:packman_auto_install = v:false
endif

if !exists('g:packman_lockfile')
  g:packman_lockfile = expand('~/.vim/packman.lock')
endif

# --------------------------------------------
# User commands
# --------------------------------------------

command! -nargs=* -bar PackmanInit call packman#PackmanInit(<f-args>)
command! -nargs=* -bar PackmanInstall call packman#PackmanInstall(<f-args>)
command! -nargs=* -bar PackmanInstallSync call packman#PackmanInstallSync(<f-args>)
command! -nargs=* -bar PackmanUpdate call packman#PackmanUpdate(<f-args>)
command! -nargs=0 -bar PackmanClean call packman#PackmanClean()
command! -nargs=0 -bar PackmanStatus call packman#PackmanStatus()
command! -nargs=0 -bar PackmanLock call packman#PackmanLock()
