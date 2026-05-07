# vim9-packman
A minimal, fast Vim9script package manager with parallel git operations.

## Aim

The aim of vim9-packman is to provide the possibility to have a **minimal vimrc** and automatically deploy your entire Vim working environment on the first start. Just define your plugin list, add the bootstrap snippet, and vim9-packman will:

- Install all missing plugins synchronously on first run
- Load all plugins before your vimrc continues executing
- Allow plugin-specific configuration immediately after `packman#PackmanInit()`
- Work identically across machines with the same vimrc

## Features
- Parallel plugin install/update via Vim's `job_start()` API
- Synchronous init function (`PackmanInit`) to block vimrc until plugins are installed and loaded
- Vim-script lockfile for reproducible plugin installs
- Plugin status overview (installed/outdated/missing)

## Installation

### Step 1: Remove old plugin code from `~/.vimrc`

### Step 2: Add bootstrap snippet

Add this bootstrap snippet to the **very top** of your `~/.vimrc` (before any other configuration):

```vim
vim9script

# Plugin list (supports "user/repo" format)
g:packman_plugins = [
  'greeschenko/vim9-packman',  # Self-update support
  'greeschenko/cyberpunk99.vim',
  'yegappan/lsp',
  #...
]

# vim9-packman auto initialization
const P = expand('~/.vim/pack/plugins/opt/vim9-packman')
if !isdirectory(P) && executable('git')
  mkdir(P, 'p')
  system('git clone --depth 1 ' .. shellescape('https://github.com/greeschenko/vim9-packman.git') .. ' ' .. shellescape(P))
endif

execute 'packadd vim9-packman'
packman#PackmanInit()
```
**Note:** All other options (`g:packman_plugin_dir`, `g:packman_lockfile`, etc.) are optional and have sensible defaults.

### Step 3: Restart Vim

Save your `~/.vimrc` and restart Vim. Plugins will be installed and loaded automatically.

## Commands
All commands use the `Packman` prefix:

| Command | Description |
|---------|-------------|
| `:PackmanInit [plugin...]` | Sync init: install missing + load plugins (blocks vimrc) |
| `:PackmanInstall [plugin...]` | Install all/missing/specified plugins (parallel, async) |
| `:PackmanInstallSync [plugin...]` | Deprecated: use PackmanInit instead |
| `:PackmanUpdate [plugin...]` | Update all/specified plugins (parallel, shows per-plugin result) |
| `:PackmanClean` | Remove plugins not in `g:packman_plugins` |
| `:PackmanStatus` | Show plugin state (installed/outdated/missing/commit) |
| `:PackmanLock` | Generate/update lockfile with current commit hashes |

**Package management commands (manual use):**
- `:PackmanUpdate` - Update plugins (async, shows per-plugin result)
- `:PackmanClean` - Remove unused plugins
- `:PackmanStatus` - Show plugin status
- `:PackmanLock` - Generate/update lockfile

## Lockfile
The lockfile (`~/.vim/packman.lock`) pins plugins to exact commits for reproducible environments. It is automatically updated after `:PackmanUpdate` completes and can be manually generated with `:PackmanLock`.

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
