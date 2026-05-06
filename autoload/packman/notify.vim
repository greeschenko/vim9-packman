vim9script

# Notification module – copy-paste friendly
# To reuse in another plugin, change the plugin_name variable below.

var plugin_name = 'packman'
var notifications: list<string> = []

def NotifyLocal(msg: string): void
  notifications->add(msg)
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
      time: 5000,
      border: [],
      borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
      highlight: 'Comment',
    }

    popup_create(text, opts)
  else
    for line in text
      echomsg plugin_name .. ': ' .. line
    endfor
  endif
enddef

# Public API
export def Notify(msg: string): void
  NotifyLocal(msg)
enddef
