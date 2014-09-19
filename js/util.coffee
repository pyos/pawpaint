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
  iw = img.width  / 2
  ih = img.height / 2
  c1 = new Canvas(iw, ih)[0]
  c2 = new Canvas(iw, ih)[0]
  ct = c1.getContext('2d')
  cq = c2.getContext('2d')
  cq.drawImage img, 0, 0, iw, ih

  while iw < w and ih < h
    ct.clearRect(0, 0, iw, ih)
    ct.drawImage(c2, 0, 0, iw, ih)
    cp = cq; c3 = c1; iw /= 2
    cq = ct; c1 = c2; ih /= 2
    ct = cp; c2 = c3

  ctx.drawImage c2, x, y, w, h

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
