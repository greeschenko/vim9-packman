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

### Step 1: Remove old plugin code from `~/.vimrc`

Remove any old plugin management functions like `CheckGit()`, `InstallPlugin()`, `UpdatePlugin()`, `LoadPlugin()`, `SetupPlugins()`, `UpdatePlugins()` and commands like `PluginsInstall`, `PluginsUpdate`.

### Step 2: Add bootstrap snippet

Add this bootstrap snippet to the **very top** of your `~/.vimrc` (before any other configuration):

```vim
vim9script
const P = expand('~/.vim/pack/plugins/opt/vim9-packman')
if !isdirectory(P) && executable('git')
  mkdir(P, 'p')
  system('git clone --depth 1 ' .. shellescape('https://github.com/greeschenko/vim9-packman.git') .. ' ' .. shellescape(P))
endif

execute 'packadd vim9-packman'
```

This handles first-time install on fresh systems and always loads vim9-packman on subsequent starts.

### Step 3: Add configuration after bootstrap

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

### Step 4: Restart Vim

Save your `~/.vimrc` and restart Vim. Plugins will be installed automatically on startup.

## Commands
All commands use the `Packman` prefix:

| Command | Description |
|---------|-------------|
| `:PackmanInit [plugin...]` | Sync init: install missing + load plugins (blocks vimrc) |
| `:PackmanInstall [plugin...]` | Install all/missing/specified plugins (parallel, async) |
| `:PackmanInstallSync [plugin...]` | Deprecated: use PackmanInit instead |
| `:PackmanUpdate [plugin...]` | Update all/specified plugins (parallel, updates lockfile) |
| `:PackmanClean` | Remove plugins not in `g:packman_plugins` |
| `:PackmanStatus` | Show plugin state (installed/outdated/missing/commit) |
| `:PackmanLock` | Generate/update lockfile with current commit hashes |

## Sync Init (Block Vimrc Until Plugins Are Installed)

Use `PackmanInit()` to synchronously install missing plugins and load all plugins. This blocks vimrc execution until complete, ensuring plugins are available for subsequent configuration:

```vim
# Complete vimrc example with sync init:
vim9script

g:mapleader = ' '
g:maplocalleader = ','

# Bootstrap vim9-packman (install if missing, always load)
const P = expand('~/.vim/pack/plugins/opt/vim9-packman')
if !isdirectory(P) && executable('git')
  mkdir(P, 'p')
  system('git clone --depth 1 ' .. shellescape('https://github.com/greeschenko/vim9-packman.git') .. ' ' .. shellescape(P))
endif

execute 'packadd vim9-packman'

# Plugin manager config
g:packman_plugin_dir = expand('~/.vim/pack/plugins/opt')
g:packman_lockfile = expand('~/.vim/packman.lock')
g:packman_plugins = [
  'greeschenko/vim9-packman',
  'greeschenko/cyberpunk99.vim',
  'yegappan/lsp',
  'greeschenko/vim9-fuzzy',
  'greeschenko/vim9-ollama',
  'greeschenko/vimsidian',
]

# Block until all plugins are installed and loaded
packman#PackmanInit()

# Plugin-specific configuration below - plugins are now guaranteed to exist
# e.g., LSP settings, ollama config, etc.
```

**Note:** `PackmanInstallSync()` is deprecated. Use `PackmanInit()` instead.

**Package management commands (manual use):**
- `:PackmanUpdate` - Update plugins (async, manual only)
- `:PackmanClean` - Remove unused plugins
- `:PackmanStatus` - Show plugin status
- `:PackmanLock` - Generate/update lockfile

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
