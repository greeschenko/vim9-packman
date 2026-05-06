vim9script

# Plugin name/path helpers

def PluginNameLocal(repo: string): string
  return fnamemodify(repo, ':t')
enddef

def PluginPathLocal(repo: string): string
  return g:packman_plugin_dir .. '/' .. PluginNameLocal(repo)
enddef

def EnsurePluginDirLocal(): void
  if !isdirectory(g:packman_plugin_dir)
    mkdir(g:packman_plugin_dir, 'p')
  endif
enddef

# Public API
export def PluginName(repo: string): string
  return PluginNameLocal(repo)
enddef

export def PluginPath(repo: string): string
  return PluginPathLocal(repo)
enddef

export def EnsurePluginDir(): void
  EnsurePluginDirLocal()
enddef
