---
---

# Something to draw with.
#
# Options::
#
#   dynamic :: Canvas.Dynamic -- see `dynamic.coffee`
#   size     :: float -- greater than 0
#   H, S, L  :: int -- same ranges as in CSS3 `hsl` function. Same purpose, too.
#   opacity  :: float -- 0 to 1, transparent to opaque
#   rotation :: float -- 0 to 2pi
#   spacing  :: float -- greater or equal to 1, only affects pattern brushes
#
# Tool :: Object -> Canvas.Tool
#
class Tool
  name: 'Tool'
  icon: null

  constructor: (area, options) ->
    @area = area
    @options = {}
    @setOptions
      dynamic: []
      rotation: 0
      spacing: 1
      opacity: 1
      size:    1
      H: 0
      S: 0
      L: 0
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


class SelectRect extends Tool
  name: 'Rectangular Selection'

  symbol: (ctx, x, y) ->
    ctx.save()
    ctx.translate(x, y)
    @crosshair ctx
    ctx.restore()

  crosshair: (ctx) ->
    ctx.save()
    ctx.lineWidth   = 1
    ctx.globalAlpha = 0.5
    ctx.strokeStyle = "hsl(0, 0%, 50%)"
    ctx.beginPath()
    ctx.strokeRect(-@options.size / 2, -@options.size / 2, @options.size, @options.size)
    ctx.restore()

  start: (ctx, x, y) ->
    @startX = @lastX = x
    @startY = @lastY = y

  move: (ctx, x, y) ->
    @lastX = x
    @lastY = y
    path = new Path2D
    path.rect @startX, @startY, x - @startX, y - @startY
    @area.setSelection path


class Pen extends Tool
  name: 'Pen'

  crosshair: (ctx) ->
    h = @options.H
    s = @options.S
    l = @options.L
    o = @options.opacity
    d = @options.dynamic
    @options.H = 0
    @options.S = 0
    @options.L = 50
    @options.opacity = 0.5
    @options.dynamic = []
    @start ctx, 0, 0, 1, 0
    @move  ctx, 0, 1, 1, 0
    @stop  ctx, 0, 1, 1, 0
    @options.H = h
    @options.S = s
    @options.L = l
    @options.opacity = o
    @options.dynamic = d

  start: (ctx, x, y, pressure, rotation) ->
    ctx.save()
    ctx.lineCap     = "round"
    ctx.lineJoin    = "round"
    ctx.lineWidth   = @options.size
    ctx.globalAlpha = @options.opacity
    ctx.strokeStyle = "hsl(#{@options.H}, #{@options.S}%, #{@options.L}%)"
    dyn.reset ctx, @, x, y, pressure, rotation for dyn in @options.dynamic
    @lastX = x
    @lastY = y
    @empty = true

  move: (ctx, x, y, pressure, rotation) ->
    dx = x - @lastX
    dy = y - @lastY
    if steps = floor(pow(pow(dx, 2) + pow(dy, 2), 0.5) / @options.spacing) or @empty
      dyn.start ctx, @, dx, dy, pressure, rotation, steps for dyn in @options.dynamic
      dx /= steps
      dy /= steps
      for i in [0...steps]
        dyn.step ctx, @ for dyn in @options.dynamic
        @step(ctx, @lastX, @lastY, @lastX += dx, @lastY += dy)
      dyn.stop ctx, @ for dyn in @options.dynamic
      @empty = false

  step: (ctx, x, y, nx, ny) ->
    ctx.beginPath()
    ctx.moveTo(x, y)
    ctx.lineTo(nx, ny)
    ctx.stroke()

  stop: (ctx, x, y) ->
    dyn.restore ctx, @ for dyn in @options.dynamic
    ctx.restore()


class Stamp extends Pen
  name: 'Stamp'
  img:  null

  start: ->
    @pattern = Canvas.scale @img, @options.size, @options.size
    super

  step: (ctx, x, y, nx, ny) ->
    ds = ctx.lineWidth
    ctx.save()
    ctx.translate(nx, ny)
    ctx.rotate(@options.rotation)
    ctx.drawImage(@pattern, -ds / 2, -ds / 2, ds, ds)
    ctx.restore()


class Resource extends Stamp
  rsrc: null

  start: ->
    @img = Canvas.getResourceWithTint @rsrc, @options.H, @options.S, @options.L
    super


class Eraser extends Pen
  name: 'Eraser'
  icon: 'icon-eraser'

  crosshair: (ctx) ->
    ctx.save()
    ctx.lineWidth   = 1
    ctx.globalAlpha = 0.5
    ctx.strokeStyle = "hsl(0, 0%, 50%)"
    ctx.beginPath()
    ctx.arc(0, 0, @options.size / 2, 0, 2 * PI, false)
    ctx.stroke()
    ctx.restore()

  start: (ctx) ->
    super
    ctx.globalCompositeOperation = "destination-out"


@Canvas.Tool          = Tool
@Canvas.Tool.Pen      = Pen
@Canvas.Tool.Eraser   = Eraser
@Canvas.Tool.Stamp    = Stamp
@Canvas.Tool.Resource = Resource
@Canvas.Tool.Select   = SelectRect

@Canvas.Tool.Stamp.make = (img) -> class P extends this
  img: img
@Canvas.Tool.Resource.make = (rsrc) -> class R extends this
  rsrc: rsrc
