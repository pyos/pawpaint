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

@Canvas = (width, height) -> $ "<canvas width='#{floor(width)}' height='#{floor(height)}'>"


@CTRL  = 1 << 11
@SHIFT = 1 << 10
@ALT   = 1 << 9
@META  = 1 << 8

$.fn.keymap = (maps...) ->
  this.on 'keydown', (ev) ->
    k = ev.ctrlKey * CTRL | ev.shiftKey * SHIFT | ev.altKey * ALT | ev.metaKey * META | ev.keyCode
    for spec in maps
      return spec.f() if k == spec.key
