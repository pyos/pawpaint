pow = Math.pow
exp = Math.exp


class Dynamic
  defaults:
    init:     0
    offset:   5
    multiple: 0.333

  constructor: (tool, init, offset, multiple) ->
    @tool     = tool
    @init     = init     || @defaults.init
    @offset   = offset   || @defaults.offset
    @multiple = multiple || @defaults.multiple

  start: (ctx, lx, ly, x, y, steps) ->
    @target = 1 / (1 + exp(@offset - pow(pow(x - lx, 2) + pow(y - ly, 2), 0.5) * @multiple))

  stop:  (ctx) ->
  step:  (ctx) ->
  reset: (ctx) ->


class SizeDynamic extends Dynamic
  start: (ctx, lx, ly, x, y, steps) ->
    super
    @target *= @tool.options.size
    @delta   = (@target - ctx.lineWidth) / steps

  step:  (ctx) -> ctx.lineWidth += @delta
  stop:  (ctx) -> ctx.lineWidth  = @target
  reset: (ctx) -> ctx.lineWidth  = @init || 0.1


class OpacityDynamic extends Dynamic
  defaults:
    init:     1
    offset:   -5
    multiple: -0.25

  start: (ctx, lx, ly, x, y, steps) ->
    super
    @target *= @tool.options.opacity
    @delta   = (@target - ctx.globalAlpha) / steps

  step:  (ctx) -> ctx.globalAlpha += @delta
  stop:  (ctx) -> ctx.globalAlpha  = @target
  reset: (ctx) -> ctx.globalAlpha  = @init


window.Canvas or= {}
window.Canvas.Dynamic = Dynamic
window.Canvas.SizeDynamic = SizeDynamic
window.Canvas.OpacityDynamic = OpacityDynamic
