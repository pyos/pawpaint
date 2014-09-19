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


# Retrieve a preloaded resource from the page.
#
# getResource :: str -> Image
#
@Canvas.getResource = (selector) -> $(".resources img.#{selector}")[0]


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
