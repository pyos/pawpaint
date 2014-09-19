---
---

@min   = Math.min
@max   = Math.max
@sin   = Math.sin
@cos   = Math.cos
@atan2 = Math.atan2
@abs   = Math.abs
@pow   = Math.pow
@exp   = Math.exp
@sqrt  = Math.sqrt
@round = Math.round
@ceil  = Math.ceil
@floor = Math.floor
@PI    = Math.PI

@CTRL  = 1 << 11
@SHIFT = 1 << 10
@ALT   = 1 << 9
@META  = 1 << 8


# A shortcut for creating <canvas> elements.
#
# Canvas :: int int -> Canvas
#
@Canvas = (width, height) -> $ "<canvas width='#{floor(width)}' height='#{floor(height)}'>"


# Listen for key events and react to certain combinations::
#
#   element.keymap {key: CTRL | Z, fn: undo}, ...
#
# Mostly useless since browsers hog key combos for themselves.
#
# keymap :: *KeySpec -> jQuery
#
$.fn.keymap = (maps...) ->
  this.on 'keydown', (ev) ->
    k = ev.ctrlKey * CTRL | ev.shiftKey * SHIFT | ev.altKey * ALT | ev.metaKey * META | ev.keyCode
    for spec in maps
      return spec.f() if k == spec.key
