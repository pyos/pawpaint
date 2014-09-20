---
---

# A way to change some parameters based on some other parameters.
#
# Options::
#   k   -- every input is multiplied by this value
#   a   -- this is added to the result
#   min -- minimum returned value
#   max -- (the actual value is simply clipped to this range)
#
# Dynamic :: Object -> Canvas.Dynamic
#
class Dynamic
  VELOCITY = 0
  PRESSURE = 1
  ROTATION = 2

  constructor: (options) ->
    @options = jQuery.extend(@options or {
      computation: movingAverage,
      type: @VELOCITY
      min: 0
      max: 1
      a:   0
      k:   1
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
  reset: (ctx) -> @_f = @options.computation.apply this
  start: (ctx, tool, dx, dy, steps) ->
    v = switch @options.type
      when @VELOCITY then pow(pow(dx, 2) + pow(dy, 2), 0.5)
      when @PRESSURE then pressure
      when @ROTATION then rotation
      else 0
    min @options.max, max @options.min, @_f(v) * @options.k + @options.a

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
  reset: (ctx) -> super; ctx[@options.prop] = @options.min


# A computation that returns uniformly distributed random values in range [0..1)
#
# random :: -> float -> float
#
random = -> -> Math.random()


# A computation that returns a value that is a moving average of the previous values.
#
# Options::
#   avgOf -- size of the average window
#
# movingAverage :: -> float -> float
#
movingAverage = ->
  value = 0
  count = 0
  array = []
  limit = @options.avgOf || 75

  (current) ->
    if count >= limit
      value += (current - array[count % limit]) / limit
      array[count % limit] = current
    else
      array.push(current)
      value += (current - value) / array.length
    count++
    return value


@Canvas.Dynamic = Dynamic
@Canvas.Dynamic.Option = OptionDynamic

@Canvas.Dynamic.random        = random
@Canvas.Dynamic.movingAverage = movingAverage
