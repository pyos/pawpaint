class Tool
  defaults:
    dynamic: null
    opacity: 1
    size:    1
    H: 0
    S: 0
    L: 0

  constructor: (options) ->
    @options = jQuery.extend {}, @defaults
    @lastX = 0
    @lastY = 0
    @setOptions options

  setOptions: (options) ->
    @options = jQuery.extend @options, options

  crosshair: (ctx) ->
  start: (ctx, x, y) ->
  move:  (ctx, x, y) ->
  stop:  (ctx, x, y) ->


class Pen extends Tool
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

  start: (ctx, x, y) ->
    ctx.save()
    ctx.lineCap     = "round"
    ctx.lineJoin    = "round"
    ctx.lineWidth   = @options.size
    ctx.globalAlpha = @options.opacity
    ctx.strokeStyle = "hsl(#{@options.H}, #{@options.S}%, #{@options.L}%)"
    @options.dynamic?.reset ctx, x, y
    @lastX = x
    @lastY = y

  move: (ctx, x, y) ->
    steps = 10
    dx = (x - @lastX) / steps
    dy = (y - @lastY) / steps
    @options.dynamic?.start ctx, @, x - @lastX, y - @lastY, steps
    for i in [0...steps]
      @options.dynamic?.step ctx
      ctx.beginPath()
      ctx.moveTo((@lastX),       (@lastY))
      ctx.lineTo((@lastX += dx), (@lastY += dy))
      ctx.stroke()
    @options.dynamic?.stop ctx

  stop: (ctx, x, y) ->
    @move ctx, x, y
    ctx.restore()


class Eraser extends Pen
  start: (ctx, x, y) ->
    super
    ctx.globalCompositeOperation = "destination-out"


@Canvas.Tool = Tool
@Canvas.Tool.Pen = Pen
@Canvas.Tool.Eraser = Eraser
