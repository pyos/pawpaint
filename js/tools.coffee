class Tool
  defaults:
    dynamic: null
    opacity: 1
    size:    1
    color:   "#000000"

  constructor: (options) ->
    @options = jQuery.extend {}, @defaults
    @lastX = 0
    @lastY = 0
    @setOptions options

  setOptions: (options) ->
    @options = jQuery.extend @options, options

  crosshair: (ctx) ->
    ctx.lineWidth   = 1
    ctx.strokeStyle = "#777"
    ctx.stroke()

  start: (ctx, x, y) ->
  move:  (ctx, x, y) ->
  stop:  (ctx, x, y) ->


class Pen extends Tool
  crosshair: (ctx) ->
    ctx.beginPath()
    ctx.arc(@options.size / 2, @options.size / 2, @options.size / 2, 0, 2 * Math.PI, false)
    super

  start: (ctx, x, y) ->
    ctx.lineCap     = "round"
    ctx.lineJoin    = "round"
    ctx.lineWidth   = @options.size
    ctx.strokeStyle = @options.color
    ctx.globalAlpha = @options.opacity
    @options.dynamic?.reset ctx, x, y
    @lastX = x
    @lastY = y

  move: (ctx, x, y) ->
    steps = 10
    dx    = (x - @lastX) / steps
    dy    = (y - @lastY) / steps
    @options.dynamic?.start ctx, @lastX, @lastY, x, y, steps
    for i in [0...steps]
      @options.dynamic?.step ctx
      ctx.beginPath()
      ctx.moveTo((@lastX),       (@lastY))
      ctx.lineTo((@lastX += dx), (@lastY += dy))
      ctx.stroke()
    @options.dynamic?.stop ctx

  stop: (ctx, x, y) -> @move ctx, x, y


class Eraser extends Pen
  start: (ctx, x, y) ->
    @_old_mode = ctx.globalCompositeOperation
    ctx.globalCompositeOperation = "destination-out"
    super

  stop: (ctx, x, y) ->
    super
    ctx.globalCompositeOperation = @_old_mode


window.Canvas or= {}
window.Canvas.Tool = Tool
window.Canvas.Pen = Pen
window.Canvas.Eraser = Eraser
