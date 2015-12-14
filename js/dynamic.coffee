---
---

# A way to change some parameters based on some other parameters.
#
# Options::
#   max  -- each result (in 0..1) is scaled to fit into this range
#   min  --
#   type -- which parameter to use (velocity, direction, pressure, rotation, random)
#   fn   -- a function that returns a function that normalizes the current value in some way
#
# Dynamic :: Object -> Canvas.Dynamic
#
@Canvas.Dynamic = class Dynamic
  constructor: (options) ->
    @options = jQuery.extend(@options or {}, {
      type: 0
      min:  0
      max:  1
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
  start: (ctx, tool, dx, dy, pressure, rotation) ->
    v = switch @options.type
      when 1 then atan2(dy, dx) / 2 / PI + 0.5
      when 2 then pressure
      when 3 then rotation / 2 / PI
      when 4 then Math.random()
      else pow(pow(dx, 2) + pow(dy, 2), 0.5) / 20
    @options.min + (@options.max - @options.min) * min 1, max 0, @_f(v)

  step:  (ctx, tool, total) ->
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

  start: (ctx, tool, dx, dy, pressure, rotation) ->
    @_value = super * @_scache
    if @_first
      @stop ctx, tool
      @_delta = 0
      @_first = false
    else
      @_delta = @_value - (ctx[@_target] or tool.options[@_tgcopy])

  step: (ctx, tool, total) ->
    tool.options[@_tgcopy] += @_delta / total if @_tgcopy
    ctx[@_target] += @_delta / total if @_target

  stop: (ctx, tool) ->
    tool.options[@_tgcopy] = @_value if @_tgcopy
    ctx[@_target] = @_value if @_target

  reset: (ctx, tool) ->
    super
    @_scache = if @options.source then tool.options[@options.source] else 1
    @_cache  = tool.options[@options.tgcopy]
    @_target = @options.target
    @_tgcopy = @options.tgcopy
    @_first  = true
    @stop ctx, tool

  restore: (ctx, tool) ->
    tool.options[@options.tgcopy] = @_cache if @options.tgcopy


# A normalizing function that returns a value that is a moving average of the previous values.
#
# Options::
#   avgOf -- size of the average window
#
# movingAverage :: -> float -> float
#
Dynamic.movingAverage = ->
  limit = @avgOf || 10
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
