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
    _x = @options.dynamic
    @options.dynamic = []
    @start ctx, x,     y, 1, 0
    @move  ctx, x + 1, y, 1, 0
    @stop  ctx, x + 1, y
    @options.dynamic = _x


class Move extends Tool
  name: 'Move'

  symbol: (ctx, x, y) ->
    sz = @options.size
    ctx.save()
    ctx.translate(x, y)
    ctx.fillStyle = "hsl(#{@options.H},#{@options.S}%,#{@options.L}%)"
    ctx.globalAlpha = @options.opacity
    ctx.beginPath()
    for q in [0...4]
      ctx.rotate(PI / 2)
      ctx.moveTo(0, -0.03 * sz)
      ctx.lineTo(-0.3 * sz, -0.03 * sz)
      ctx.lineTo(-0.3 * sz, -0.10 * sz)
      ctx.lineTo(-0.5 * sz, 0)
      ctx.lineTo(-0.3 * sz, +0.10 * sz)
      ctx.lineTo(-0.3 * sz, +0.03 * sz)
      ctx.lineTo(0, +0.03 * sz)
    ctx.fill()
    ctx.restore()

  start: (ctx, x, y) ->
    @layer = @area.layers[@area.layer]
    @startX = @lastX = x
    @startY = @lastY = y
    @startX -= @layer.x
    @startY -= @layer.y
    true

  move: (ctx, x, y) ->
    @lastX = x
    @lastY = y
    @layer.move(x - @startX, y - @startY)


class Selection extends Tool
  name: 'Selection'

  start: (ctx, x, y) ->
    @oldsel = @area.selection
    @startX = @lastX = x
    @startY = @lastY = y
    true

  move: (ctx, x, y) ->
    @lastX = x
    @lastY = y
    dx = x - @startX
    dy = y - @startY
    if SHIFT
      if abs(dy) > abs(dx)
        dy = dy / abs(dy) * abs(dx)
      else
        dx = dx / abs(dx) * abs(dy)
    path = new Path2D
    @select path, @startX + min(0, dx), @startY + min(0, dy), abs(dx), abs(dy)
    if CTRL and @oldsel.length
      paths = []
      if ALT
        paths.push(p) for p in @oldsel
        paths.push(path)
      else for p in @oldsel
        npath = new Path2D
        npath.addPath(path)
        npath.addPath(p)
        paths.push(npath)
    else if ALT
      npath = new Path2D
      npath.rect 0, 100000, 100000, -100000
      npath.addPath(path)
      paths = []
      paths.push(p) for p in @oldsel
      paths.push(npath)
    else
      paths = [path]
    @area.setSelection paths

  stop: (ctx) ->
    if abs(@lastX - @startX) + abs(@lastY - @startY) < 5 and not (SHIFT and @oldsel)
      @area.setSelection []

  symbol: (ctx, x, y) ->
    ctx.save()
    ctx.lineWidth = 1
    ctx.globalAlpha = @options.opacity
    ctx.setLineDash([5, 5])
    ctx.strokeStyle = "hsl(#{@options.H},#{@options.S}%,#{@options.L}%)"
    ctx.beginPath()
    @select(ctx, x - @options.size / 2, y - @options.size / 2, @options.size, @options.size)
    ctx.stroke()
    ctx.restore()


class SelectRect extends Selection
  name: 'Rectangular Selection'

  select: (path, x, y, dx, dy) -> path.rect x, y, dx, dy


class SelectEllipse extends Selection
  name: 'Elliptical Selection'

  select: (path, x, y, dx, dy) ->
    path.ellipse x + dx / 2, y + dy / 2, dx / 2, dy / 2, 0, 0, PI * 2


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

  symbol: (ctx, x, y) ->
    img  = Canvas.getResourceWithTint 'icon-eraser', @options.H, @options.S, @options.L
    size = @options.size
    Canvas.drawImageSmooth ctx, img, x - size / 2, y - size / 2, size, size

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


@Canvas.Tool           = Tool
@Canvas.Tool.Move      = Move
@Canvas.Tool.Pen       = Pen
@Canvas.Tool.Eraser    = Eraser
@Canvas.Tool.Stamp     = Stamp
@Canvas.Tool.Resource  = Resource
@Canvas.Tool.Selection = Selection
@Canvas.Tool.Selection.Rect    = SelectRect
@Canvas.Tool.Selection.Ellipse = SelectEllipse

@Canvas.Tool.Stamp.make = (img) -> class P extends this
  img: img
@Canvas.Tool.Resource.make = (rsrc) -> class R extends this
  rsrc: rsrc
