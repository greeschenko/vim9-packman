vim9script

# Git helper functions

def CheckGitLocal(): void
  if !executable('git')
    echoerr 'Git is required to install plugins'
  endif
enddef

def GitUrlLocal(repo: string): string
  return 'https://github.com/' .. repo .. '.git'
enddef

# Public API
export def CheckGit(): void
  CheckGitLocal()
enddef

export def GitUrl(repo: string): string
  return GitUrlLocal(repo)
enddef
