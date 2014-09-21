---
---

# A way to change some parameters based on some other parameters.
#
# Options::
#   type -- which parameter to use (VELOCITY, PRESSURE, ...)
#   k    -- every input (in range 0-1) is multiplied by this value
#   a    -- this is added to the result
#   fn   -- a function that returns a function that takes some input
#           (most likely in 0-1 range, but not guaraneed) and returns a normalized value
#
# Dynamic :: Object -> Canvas.Dynamic
#
class Dynamic
  VELOCITY: 0
  PRESSURE: 1
  ROTATION: 2

  constructor: (options) ->
    @options = jQuery.extend(@options or {
      type: @VELOCITY
      a:    0
      k:    1
      fn:   Canvas.Dynamic.movingAverage,
    }, options)

  # Lifecycle of a `Dynamic`:
  #
  #   1. When the user begins drawing: `reset(context)`
  #   2. Before a single path leg is drawn: `start(context, tool, dx, dy, steps)`
  #      where `steps` is how many times `step` will be called.
  #   3. While drawing a single path leg: `step(context)` should gradually change
  #      something to the desired value.
  #   4. After a path leg is drawn: `stop(context)`.
  #
  reset: (ctx) -> @_f = @options.fn()
  start: (ctx, tool, dx, dy, pressure, rotation, steps) ->
    v = switch @options.type
      when @VELOCITY then pow(pow(dx, 2) + pow(dy, 2), 0.5) / 20
      when @PRESSURE then pressure
      when @ROTATION then rotation / 2 / PI
      else 0
    @options.a + @options.k * min 1, max 0, @_f(v)

  step:  (ctx) ->
  stop:  (ctx) ->


# A dynamic that changes some property of the canvas that has an associated
# tool option (e.g. `context.lineWidth` <=> `tool.options.size`).
#
# Options::
#   option -- the tool side of the property (an upper limit, will not mutate)
#   prop   -- the canvas side of the property (where to store the result)
#
# OptionDynamic :: Object -> Canvas.Dynamic
#
class OptionDynamic extends Dynamic
  constructor: (options) ->
    super
    @options.option or= 'size'
    @options.prop   or= 'lineWidth'

  start: (ctx, tool, dx, dy, pressure, rotation, steps) ->
    @_value = super * tool.options[@options.option]
    @_delta = (@_value - ctx[@options.prop]) / steps

  step:  (ctx) -> ctx[@options.prop] += @_delta
  stop:  (ctx) -> ctx[@options.prop]  = @_value
  reset: (ctx) -> super; ctx[@options.prop] = @options.min || 0.01


# A normalizing function that returns uniformly distributed random values in range [0..1)
#
# random :: -> float -> float
#
Dynamic.random = -> -> Math.random()


# A normalizing function that does nothing.
#
# linear :: float -> float
#
Dynamic.linear = -> (value) -> value


# A normalizing function that returns a value that is a moving average of the previous values.
#
# Options::
#   avgOf -- size of the average window
#
# movingAverage :: -> float -> float
#
Dynamic.movingAverage = ->
  limit = @avgOf || 75
  value = 0
  count = 0
  array = []

  (current) ->
    if not count
      array.push(current) for _ in [0...limit]
      value = current
    else
      value += (current - array[count % limit]) / limit
      array[count % limit] = current
    count++
    return value


@Canvas.Dynamic = Dynamic
@Canvas.Dynamic.Option = OptionDynamic
