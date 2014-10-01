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
@Canvas = (width, height) -> $ "<canvas width='#{width}' height='#{height}'>"


# Whether `<canvas>` is actually supported enough for this to work.
#
# Canvas.exists :: -> bool
#
@Canvas.exists = ->
  elem = document.createElement('canvas')
  return elem.getContext and elem.toDataURL('image/png').indexOf('data:image/png') == 0


# Retrieve a preloaded resource from the page.
#
# getResource :: str -> Element
#
@Canvas.getResource = (selector) -> $(".resources .#{selector}")[0]


# Take a color, apply alpha from a resource.
#
# getResourceWithColor :: str int int int -> Canvas
#
@Canvas.getResourceWithTint = (selector, h, s, l) ->
  resource = Canvas.getResource selector
  canvas   = new Canvas(resource.width, resource.height)[0]
  context  = canvas.getContext('2d')
  context.fillStyle = "hsl(#{h}, #{s}%, #{l}%)"
  context.fillRect 0, 0, resource.width, resource.height
  context.globalCompositeOperation = "destination-in"
  context.drawImage resource, 0, 0
  canvas


# Draw an image using the step-down method.
#
# drawImageSmooth :: 2DRenderingContext (Either Canvas Image) int int int int -> Canvas
#
@Canvas.drawImageSmooth = (ctx, img, x, y, w, h) ->
  # TODO something
  ctx.drawImage img, x, y, w, h


# Create a copy of an image with given dimensions.
#
# scale :: (Either Canvas Image) int int -> Canvas
#
@Canvas.scale = (img, w, h) ->
  ct = new Canvas(w, h)[0]
  Canvas.drawImageSmooth ct.getContext('2d'), img, 0, 0, w, h
  ct


# When using tablets, evdev may bug and send the cursor jumping when doing
# fine movements. To prevent this, we're going to ignore extremely fast
# mouse movement events.
@evdev =
  lastX: 0
  lastY: 0

  # Mark a start point given a mouse event.
  #
  # reset :: MouseEvent -> bool
  #
  reset: (ev) ->
    @lastX = ev.pageX
    @lastY = ev.pageY
    true

  # Check whether a mouse event is not bugged.
  #
  # ok :: MouseEvent -> bool
  #
  ok: (ev) ->
    if abs(ev.pageX - @lastX) + abs(ev.pageY - @lastY) < 200
      @lastX = ev.pageX
      @lastY = ev.pageY
      return true
    return false


# Listen for key events and emit events such as `key:ctrl+shift+127`.
# Mostly useless since browsers hog key combos for themselves.
#
# keymappable :: -> jQuery
#
$.fn.keymappable = -> @on 'keydown', (ev) ->
  n  = if ev.ctrlKey  then 'ctrl+'  else ''
  n += if ev.shiftKey then 'shift+' else ''
  n += if ev.altKey   then 'alt+'   else ''
  n += if ev.metaKey  then 'meta+'  else ''
  $(@).trigger "key:#{n}#{ev.keyCode}", [ev]


class @EventSystem
  # A simple event dispatcher, because jQuery is slow.
  constructor: -> @_events = {}

  # Add an event handler.
  #
  # on :: str (a -> b) -> c
  #
  on: (name, fn) ->
    for n in name.split(' ')
      @_events[n] or= []
      @_events[n].push(fn)
    return @

  # Call all handlers associated with an event.
  #
  # trigger :: str [a] -> b
  #
  trigger: (name, args) ->
    fn.apply @, args for fn in @_events[name] or []
    return @
