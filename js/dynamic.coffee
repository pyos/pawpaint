# A way to change some parameters based on some other parameters.
#
# Dynamic :: Object -> Canvas.Dynamic
#
class Dynamic
  constructor: (options) ->
    @options = jQuery.extend(@options or {}, options)

  # Lifecycle of a `Dynamic`:
  #
  #   1. When the user begins drawing: `reset(context)`
  #   2. Before a single path leg is drawn: `start(context, tool, dx, dy, steps)`
  #      where `steps` is how many times `step` will be called.
  #   3. While drawing a single path leg: `step(context)` should gradually change
  #      something to the desired value.
  #   4. After a path leg is drawn: `stop(context)`.
  #
  reset: (ctx) ->
  start: (ctx, tool, dx, dy, steps) ->
  step:  (ctx) ->
  stop:  (ctx) ->


# A dynamic that does something based on the average velocity of some of the latest
# strokes by applying a bounded linear relationship.
#
# Options:
#   k :: Number
#   a :: Number -- coefficients in `y = kx + a`
#   min :: Number
#   max :: Number -- lower and upper bounds
#   avgOf :: Number -- how many data points to maintain
#
# MovingAverageLinearDynamic :: Object -> Canvas.Dynamic
#
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


# A dynamic that linearly changes some property of the canvas that has an associated
# tool option (e.g. `context.lineWidth` <=> `tool.options.size`.)
#
# Options::
#   option -- the tool side of the property (an upper limit, will not mutate)
#   prop   -- the canvas side of the property (where to store the result)
#
# OptionDynamic :: Object -> Canvas.Dynamic
#
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
