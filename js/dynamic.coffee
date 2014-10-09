---
---

# A way to change some parameters based on some other parameters.
#
# Options::
#   type -- which parameter to use (VELOCITY, PRESSURE, ...)
#   kind -- the name of whatever this dynamic changes
#   k    -- every input (in range 0-1) is multiplied by this value
#   a    -- this is added to the result
#   fn   -- a function that returns a function that takes some input
#           (most likely in 0-1 range, but not guaraneed) and returns a normalized value
#
# Dynamic :: Object -> Canvas.Dynamic
#
@Canvas.Dynamic = class Dynamic
  VELOCITY:  0
  DIRECTION: 1
  PRESSURE:  2
  ROTATION:  3

  constructor: (options) ->
    @options = jQuery.extend(@options or {}, {
      type: @VELOCITY
      kind: 'none'
      a:    0
      k:    1
      fn:   Canvas.Dynamic.movingAverage,
    })
    @options = jQuery.extend(@options, options)

  # Lifecycle of a `Dynamic`:
  #
  #   1. When the user begins drawing: `reset(context)`
  #   2. Before a single path leg is drawn: `start(context, tool, dx, dy, steps)`
  #      where `steps` is how many times `step` will be called.
  #   3. While drawing a single path leg: `step(context)` should gradually change
  #      something to the desired value.
  #   4. After a path leg is drawn: `stop(context)`.
  #
  reset: (ctx, tool) -> @_f = @options.fn()
  start: (ctx, tool, dx, dy, pressure, rotation, steps) ->
    v = switch @options.type
      when @VELOCITY  then pow(pow(dx, 2) + pow(dy, 2), 0.5) / 20
      when @DIRECTION then atan2(dy, dx) / 2 / PI
      when @PRESSURE  then pressure
      when @ROTATION  then rotation / 2 / PI
      else 0
    @options.a + @options.k * min 1, max 0, @_f(v)

  step:  (ctx, tool) ->
  stop:  (ctx, tool) ->


# A dynamic that changes some property of the canvas that has an associated
# tool option (e.g. `context.lineWidth` <=> `tool.options.size`).
#
# Options::
#   source -- the option to use as an upper limit (see `Canvas.Tool.options`)
#   target -- the property of a 2d context to update with the result
#   tgcopy -- the option of the tool to update with the result
#
# OptionDynamic :: Object -> Canvas.Dynamic
#
@Canvas.Dynamic.Option = class OptionDynamic extends Dynamic
  constructor: (options) ->
    @options = jQuery.extend(@options or {}, {
      source: null
      target: null
      tgcopy: null
    })
    super

  start: (ctx, tool, dx, dy, pressure, rotation, steps) ->
    @_value = super * if @options.source then tool.options[@options.source] else 1
    @_delta = (@_value - (ctx[@_target] or tool.options[@_tgcopy])) / steps
    @stop ctx, tool if @_first
    @_first = false

  step: (ctx, tool) ->
    tool.options[@_tgcopy] += @_delta if @_tgcopy
    ctx[@_target] += @_delta if @_target

  stop: (ctx, tool) ->
    tool.options[@_tgcopy] = @_value if @_tgcopy
    ctx[@_target] = @_value if @_target

  reset: (ctx, tool) ->
    super
    @_cache  = tool.options[@options.tgcopy]
    @_target = @options.target
    @_tgcopy = @options.tgcopy
    @_first  = true
    @stop ctx, tool

  restore: (ctx, tool) ->
    tool.options[@options.tgcopy] = @_cache if @options.tgcopy


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
