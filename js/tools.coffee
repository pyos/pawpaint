---
---

# Something to draw with.
#
# Options::
#
#   dynamic :: Canvas.Dynamic -- see `dynamic.coffee`
#   opacity :: float -- 0 to 1, transparent to opaque
#   size    :: float -- greater than 0
#   H, S, L :: int -- same ranges as in CSS3 `hsl` function. Same purpose, too.
#
# Tool :: Object -> Canvas.Tool
#
class Tool
  name: 'Tool'
  icon: null

  defaults:
    dynamic: []
    opacity: 1
    size:    1
    H: 0
    S: 0
    L: 0

  constructor: (options) ->
    @options = jQuery.extend {}, @defaults
    @setOptions options

  # Change some of the values. The rest remain intact.
  #
  # setOptions :: Object -> Object
  #
  setOptions: (options) ->
    @options = jQuery.extend @options, options

  # Lifecycle of a tool::
  #
  #   * When some options are modified, `crosshair` is called with a context of a
  #     `options.size`x`options.size` canvas. The tool must use it to draw something
  #     that represents the outline of whatever it will paint onto the layer.
  #   * `symbol` is basically the same thing, but requires a filled shape at specific
  #     center coordinates. That shape will be displayed as an "icon" for that tool.
  #   * At the start of a single stroke, `start` is called.
  #   * Then `move` is called for each movement event. (All positions are absolute.)
  #   * When the mouse button is released, `stop` is called.
  #
  crosshair: (ctx) ->
  start: (ctx, x, y, pressure, rotation) ->
  move:  (ctx, x, y, pressure, rotation) ->
  stop:  (ctx, x, y) ->

  symbol: (ctx, x, y) ->
    if @icon
      img  = Canvas.getResourceWithTint @icon, @options.H, @options.S, @options.L
      size = @options.size
      Canvas.drawImageSmooth ctx, img, x - size / 2, y - size / 2, size, size
    else
      _x = @options.dynamic
      @options.dynamic = []
      @start ctx, x,     y, 1, 0
      @move  ctx, x + 1, y, 1, 0
      @stop  ctx, x + 1, y
      @options.dynamic = _x


class Pen extends Tool
  name: 'Pen'

  crosshair: (ctx) ->
    ctx.lineWidth   = 1
    ctx.strokeStyle = "#000"
    ctx.beginPath()
    ctx.arc(@options.size / 2, @options.size / 2, @options.size / 2, 0, 2 * PI, false)
    ctx.stroke()
    ctx.strokeStyle = "#fff"
    ctx.beginPath()
    ctx.arc(@options.size / 2, @options.size / 2, max(0, @options.size / 2 - 1), 0, 2 * PI, false)
    ctx.stroke()

  start: (ctx, x, y, pressure, rotation) ->
    ctx.save()
    ctx.lineCap     = "round"
    ctx.lineJoin    = "round"
    ctx.lineWidth   = @options.size
    ctx.globalAlpha = @options.opacity
    ctx.strokeStyle = "hsl(#{@options.H}, #{@options.S}%, #{@options.L}%)"
    dyn.reset ctx, x, y, pressure, rotation for dyn in @options.dynamic
    @lastX = x
    @lastY = y

  move: (ctx, x, y, pressure, rotation) ->
    steps = 10
    dx = (x - @lastX) / steps
    dy = (y - @lastY) / steps
    dyn.start ctx, @, x - @lastX, y - @lastY, pressure, rotation, steps for dyn in @options.dynamic
    for i in [0...steps]
      dyn.step ctx for dyn in @options.dynamic
      ctx.beginPath()
      ctx.moveTo((@lastX),       (@lastY))
      ctx.lineTo((@lastX += dx), (@lastY += dy))
      ctx.stroke()
    dyn.stop ctx for dyn in @options.dynamic

  stop: (ctx, x, y) ->
    ctx.restore()


class Stamp extends Pen
  name: 'Stamp'
  img:  null

  start: ->
    @pattern = Canvas.scale @img, @options.size, @options.size
    super

  move: (ctx, x, y, pressure, rotation) ->
    dx    = x - @lastX
    dy    = y - @lastY
    steps = ceil(pow(pow(dx, 2) + pow(dy, 2), 0.5) / (@options.size / 3))
    dyn.start ctx, @, x - @lastX, y - @lastY, pressure, rotation, steps for dyn in @options.dynamic

    dx /= steps
    dy /= steps
    ds  = ctx.lineWidth / 2
    for i in [0...steps]
      dyn.step ctx for dyn in @options.dynamic
      ctx.drawImage(@pattern, (@lastX += dx) - ds, (@lastY += dy) - ds, ds * 2, ds * 2)
    dyn.stop ctx for dyn in @options.dynamic


class Resource extends Stamp
  rsrc: null

  start: ->
    @img = Canvas.getResourceWithTint @rsrc, @options.H, @options.S, @options.L
    super


class Eraser extends Pen
  name: 'Eraser'
  icon: 'icon-eraser'

  start: (ctx) ->
    super
    ctx.globalCompositeOperation = "destination-out"


@Canvas.Tool          = Tool
@Canvas.Tool.Pen      = Pen
@Canvas.Tool.Eraser   = Eraser
@Canvas.Tool.Stamp    = Stamp
@Canvas.Tool.Resource = Resource

@Canvas.Tool.Stamp.make = (img) -> class P extends this
  img: img
@Canvas.Tool.Resource.make = (rsrc) -> class R extends this
  rsrc: rsrc
