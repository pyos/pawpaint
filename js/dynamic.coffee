class Dynamic
  constructor: (options) ->
    @options = jQuery.extend(@options or {}, options)

  reset: (ctx) ->
  start: (ctx, tool, dx, dy, steps) ->
  step:  (ctx) ->
  stop:  (ctx) ->


class MovingAverageLinearDynamic extends Dynamic
  constructor: (options) ->
    @options = jQuery.extend(@options or {}, k: 0.05, a: 1, min: 0, max: 1, avgOf: 75)
    super

  reset: (ctx) ->
    @_v = 0
    @_c = 0
    @_n = []

  start: (ctx, tool, dx, dy, steps) ->
    v = pow(pow(dx, 2) + pow(dy, 2), 0.5)
    d = @options.avgOf

    if @_n.length == d
      @_v += (v - @_n[@_c % d]) / d
      @_n[@_c % d] = v
    else
      @_n.push(v)
      @_v += (v - @_v) / @_n.length
    @_c++

    max(@options.min, min(@options.max, @_v * @options.k + @options.a))


class OptionDynamic extends MovingAverageLinearDynamic
  constructor: (options) ->
    @options = jQuery.extend(@options or {}, option: 'size', prop: 'lineWidth')
    super

  start: (ctx, tool, dx, dy, steps) ->
    @_value = super * tool.options[@options.option]
    @_delta = (@_value - ctx[@options.prop]) / steps

  step:  (ctx) -> ctx[@options.prop] += @_delta
  stop:  (ctx) -> ctx[@options.prop]  = @_value
  reset: (ctx) -> super; ctx[@options.prop] = @options.min


@Canvas.Dynamic = Dynamic
@Canvas.Dynamic.Option = OptionDynamic
