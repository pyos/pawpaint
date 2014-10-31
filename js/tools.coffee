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
@Canvas.Tool = class Tool
  spacingAdjust: 0.1

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
  stop:  (ctx) ->

  symbol: (ctx, x, y) ->
    if @glyph
      ctx.save()
      ctx.rotate(@options.rotation)
      ctx.font = "#{@options.size}px FontAwesome"
      ctx.fillStyle = "hsla(#{@options.H},#{@options.S}%,#{@options.L}%,#{@options.opacity})"
      ctx.fillText(@glyph, x - @options.size / 2, y + @options.size / 2.5)
      ctx.restore()
    else
      _x = @options.dynamic
      @options.dynamic = []
      @start ctx, x,     y, 1, 0
      @move  ctx, x + 1, y, 1, 0
      @stop  ctx, x + 1, y
      @options.dynamic = _x


@Canvas.Tool.Colorpicker = class Colorpicker extends Tool
  glyph: '\uf1fb'

  start: (ctx, x, y) ->
    cnv = @area.export 'flatten'
    @rstd = cnv.width * 4
    @data = cnv.getContext('2d').getImageData(0, 0, cnv.width, cnv.height).data
    @move ctx, x, y
    true

  move: (ctx, x, y) ->
    r = @data[floor(x) * 4 + @rstd * floor(y)] / 255
    g = @data[floor(x) * 4 + @rstd * floor(y) + 1] / 255
    b = @data[floor(x) * 4 + @rstd * floor(y) + 2] / 255
    m = min(r, g, b)
    M = max(r, g, b)
    L = (m + M) / 2
    S = if (M - m) < 0.001 then 0 else (M - m) / (if L < 0.5 then M + m else 2 - M - m)
    H = if (M - m) < 0.001 then 0 else switch M
      when r then     (g - b) / (M - m)
      when g then 2 + (b - r) / (M - m)
      when b then 4 + (r - g) / (M - m)
      else 0
    @area.setToolOptions H: round(H * 60), S: round(S * 100), L: round(L * 100)

  stop: (ctx) ->
    @data = null
    @rstd = 0


@Canvas.Tool.Move = class Move extends Tool
  glyph: '\uf047'

  start: (ctx, x, y) ->
    @layer = @area.layers[@area.layer]
    @lastX = x
    @lastY = y
    true

  move: (ctx, x, y) ->
    @layer.move(x - @lastX + @layer.x, y - @lastY + @layer.y)
    @lastX = x
    @lastY = y


@Canvas.Tool.Selection = class Selection extends Tool
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


@Canvas.Tool.Selection.Rect = class _ extends Selection
  select: (path, x, y, dx, dy) -> path.rect x, y, dx, dy


@Canvas.Tool.Selection.Ellipse = class _ extends Selection
  select: (path, x, y, dx, dy) -> path.ellipse x + dx / 2, y + dy / 2, dx / 2, dy / 2, 0, 0, PI * 2


@Canvas.Tool.Pen = class Pen extends Tool
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
    ctx.lineWidth   = @options.size
    ctx.globalAlpha = @options.opacity
    ctx.strokeStyle = ctx.fillStyle = "hsl(#{@options.H}, #{@options.S}%, #{@options.L}%)"
    dyn.reset ctx, @, x, y, pressure, rotation for dyn in @options.dynamic
    @lastX = @prevX = x
    @lastY = @prevY = y
    @empty = true

  move: (ctx, x, y, pressure, rotation) ->
    dx = x - @lastX
    dy = y - @lastY
    sp = floor(@options.spacing + ctx.lineWidth * @spacingAdjust)
    dyn.start ctx, @, x - @prevX, y - @prevY, pressure, rotation for dyn in @options.dynamic
    if steps = floor(pow(pow(dx, 2) + pow(dy, 2), 0.5) / sp) or @empty
      dx /= steps
      dy /= steps
      for i in [0...steps]
        dyn.step ctx, @, steps for dyn in @options.dynamic
        @step(ctx, @lastX, @lastY, @lastX += dx, @lastY += dy)
      @empty = false
    dyn.stop ctx, @ for dyn in @options.dynamic
    @prevX = x
    @prevY = y

  step: (ctx, x, y, nx, ny) ->
    ctx.beginPath()
    ctx.arc(nx, ny, ctx.lineWidth / 2, 0, 2 * PI)
    ctx.fill()

  stop: (ctx) ->
    dyn.restore ctx, @ for dyn in @options.dynamic
    ctx.restore()


@Canvas.Tool.Eraser = class Eraser extends Pen
  glyph: '\uf12d'

  crosshair: (ctx) ->
    ctx.save()
    ctx.lineWidth   = 1
    ctx.globalAlpha = 0.5
    ctx.beginPath()
    ctx.arc(0, 0, @options.size / 2, 0, 2 * PI, false)
    ctx.stroke()
    ctx.restore()

  start: (ctx) ->
    super
    ctx.globalCompositeOperation = "destination-out"

  stop: (ctx) ->
    ctx.globalCompositeOperation = "source-over"
    super


@Canvas.Tool.FromImage = class FromImage extends Pen
  start: ->
    img = Canvas.tintImage @img, @options.H, @options.S, @options.L
    @pattern = Canvas.scale img, @options.size, @options.size
    super

  step: (ctx, x, y, nx, ny) ->
    ds = ctx.lineWidth
    ctx.save()
    ctx.translate(nx, ny)
    ctx.rotate(@options.rotation)
    ctx.drawImage(@pattern, -ds / 2, -ds / 2, ds, ds)
    ctx.restore()
