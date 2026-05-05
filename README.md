# vim9-packman
A minimal, fast Vim9script package manager with parallel git operations.

## Features
- Parallel plugin install/update via Vim's `job_start()` API
- Automatic Vim reinitialization (`packloadall!` + `packadd`) after all jobs complete
- Vim-script lockfile for reproducible plugin installs
- Auto-install missing plugins on startup
- Clean removal of unused plugins
- Plugin status overview (installed/outdated/missing)

## Installation
Add this bootstrap snippet to the **very top** of your `~/.vimrc` (before any other configuration):

```vim
vim9script
const P = expand('~/.vim/pack/plugins/opt/vim9-packman')
if !isdirectory(P) && executable('git')
  mkdir(fnamemodify(P, ':h'), 'p')
  if system('git clone --depth 1 ' .. shellescape('https://github.com/greeschenko/vim9-packman.git') .. ' ' .. shellescape(P)) == 0
    execute 'set runtimepath+=' .. escape(P, ' ,')
    execute 'packadd vim9-packman'
  endif
endif
```

This handles first-time install on fresh systems automatically.

## Configuration
Add your plugin list and settings **after the bootstrap** in `~/.vimrc`:

```vim
# Plugin list (supports "user/repo" format)
g:packman_plugins = [
  'greeschenko/vim9-packman',  # Self-update support
  'greeschenko/cyberpunk99.vim',
  'yegappan/lsp',
  'greeschenko/vim9-fuzzy',
  # Add more plugins here...
]

# Directory where plugins are stored
g:packman_plugin_dir = expand('~/.vim/pack/plugins/opt')

# Auto-install missing plugins on startup
g:packman_auto_install = v:true

# Lockfile path (Vim-script format)
g:packman_lockfile = expand('~/.vim/packman.lock')
```

## Commands
All commands use the `Packman` prefix:

| Command | Description |
|---------|-------------|
| `:PackmanInstall [plugin...]` | Install all/missing/specified plugins (parallel) |
| `:PackmanUpdate [plugin...]` | Update all/specified plugins (parallel, updates lockfile) |
| `:PackmanClean` | Remove plugins not in `g:packman_plugins` |
| `:PackmanStatus` | Show plugin state (installed/outdated/missing/commit) |
| `:PackmanLock` | Generate/update lockfile with current commit hashes |

## Lockfile
The lockfile (`~/.vim/packman.lock`) pins plugins to exact commits for reproducible environments. It is automatically updated when running `:PackmanUpdate` and can be manually generated with `:PackmanLock`.

Example lockfile:
```vim
vim9script
g:packman_lock = {
  'greeschenko/vim9-packman': 'a1b2c3d4e5f6',
  'yegappan/lsp': '1234abcd5678',
}
```

## Requirements
- Vim 9.0+ (Vim9script support)
- Git installed and available in PATH
