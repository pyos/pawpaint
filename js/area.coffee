---
---

# The main object. Allows the user to draw stuff on an element with either
# a mouse, a touchscreen, or a pen tablet.
#
# Events:
#
#   stroke:begin (ev: Event, layer: Canvas, index: int) -- before drawing
#   stroke:end   (ev: Event, layer: Canvas, index: int) -- after drawing
#
#   tool:kind    (ev: Event, kind: Class, opts: Object) -- when a new tool is assigned
#   tool:<name>  (ev: Event, value: any,  opts: Object) -- when a setting is modified
#
#   layer:add    (ev: Event, layer: Layer, index: int)
#   layer:redraw (ev: Event, layer: Layer, index: int)
#   layer:resize (ev: Event, layer: Layer, index: int)
#   layer:reprop (ev: Event, layer: Layer, index: int)
#   layer:move   (ev: Event, index: int, delta: int)
#   layer:set    (ev: Event, index: int)
#   layer:del    (ev: Event, index: int)
#
# Area :: (Either str jQuery Node) (Optional [Type extends Canvas.Tool]) -> Canvas.Area
#
class @Canvas.Area extends EventSystem
  UNDO_DRAW:       0
  UNDO_ADD_LAYER:  1
  UNDO_DEL_LAYER:  2
  UNDO_MOVE_LAYER: 3

  constructor: (selector, tools...) ->
    super

    @element = $('<div class="area background">').appendTo $(selector).eq(0)
    @element.data 'area', @

    # A list of subclasses of `Canvas.Tool`.
    # You may use whatever tool you want through `setTool`, but only
    # these will be displayed in the options window.
    @tools = tools

    # A complete list of layers ordered by z-index; each one is a `jQuery` object
    # wrapping a single `Canvas`.
    @layers = []
    @layer  = 0
    @scale  = 1

    # An undo is a complete snapshot of a layer as a {layer: int, canvas: str}
    # object, where `canvas` is a PNG data URL.
    @undos = []
    @redos = []
    @undoLimit = 25

    # This canvas follows the mouse cursor around. Tools may
    # display something on it.
    @crosshair = crosshair = $('<canvas class="crosshair">').appendTo('body')[0]

    # This one displays the selection.
    @selectui = $('<canvas class="hidden selection">').appendTo(@element)[0]
    @selection = []

    # CoffeeScript's `=>` results in an ugly `__bind` wrapper.
    @onMouseMove  = @onMouseMove  .bind @
    @onMouseDown  = @onMouseDown  .bind @
    @onMouseUp    = @onMouseUp    .bind @
    @onTouchStart = @onTouchStart .bind @
    @onTouchMove  = @onTouchMove  .bind @
    @onTouchEnd   = @onTouchEnd   .bind @

    # Note: we only need to update the size of the area on these events
    # because `layer:resize` implies `layer:set`.
    @on 'layer:del layer:set', =>
      ep = @element.position()
      mw = 0
      mh = 0
      for layer in @layers
        mw = max(mw, (layer.w + layer.x) * @scale - ep.left)
        mh = max(mh, (layer.h + layer.y) * @scale - ep.top)
      @element.css('width', mw).css('height', mh)
      @selectui.width  = mw
      @selectui.height = mh
      @setToolOptions {}  # rescale the crosshair
      @setSelection @selection

    # Note: this doesn't actually redraw anything, only calls
    # into appropriate event handlers.
    @on 'stroke:end', (layer) -> layer.trigger('redraw', [layer])

    @element[0].addEventListener 'mousedown', @onMouseDown
    @element[0].addEventListener 'mousemove', (ev) ->
      crosshair.style.left = ev.pageX + 'px'
      crosshair.style.top  = ev.pageY + 'px'
      crosshair.style.visibility = 'visible'
    @element[0].addEventListener 'mouseleave', (ev) -> crosshair.style.visibility = 'hidden'
    @element[0].addEventListener 'touchstart', (ev) -> crosshair.style.visibility = 'hidden'
    @element[0].addEventListener 'touchstart', @onTouchStart

  # Scale the area.
  #
  # setScale :: float -> a
  #
  setScale: (x) ->
    @scale = max(0, min(20, x))
    @changeLayer(@layer)

  # Select an area. Selecting an area clips all operations to that area.
  # It also enables copying and cutting.
  #
  # setSelection :: Path2D -> a
  #
  setSelection: (paths) ->
    @selection = paths
    if paths.length
      @selectui.className = "selection"
      context = @selectui.getContext '2d'
      context.save()
      context.fillStyle = "hsl(0, 0%, 50%)"
      context.fillRect 0, 0, @selectui.width, @selectui.height
      context.scale @scale, @scale
      context.clip(path) for path in paths
      context.clearRect 0, 0, @selectui.width, @selectui.height
      context.restore()
    else
      @selectui.className = "hidden selection"

  # Add an empty layer at the end of the stack. Emits `layer:add`.
  #
  # createLayer :: (Optional int) (Optional State) -> a
  #
  createLayer: (index = 0, state) ->
    layer = new Canvas.Layer @
    layer.on 'reprop', (layer) => @trigger 'layer:reprop', [layer, @layers.indexOf(layer)]
         .on 'redraw', (layer) => @trigger 'layer:redraw', [layer, @layers.indexOf(layer)]
         .on 'resize', (layer) => @trigger 'layer:resize', [layer, @layers.indexOf(layer)]
         .on 'resize', (layer) => @changeLayer(@layer)  # to update the element
    @layers.splice(index, 0, layer)
    @trigger 'layer:add', [layer, index]
    if state
      layer.set(state)
    else
      layer.resize 0, 0, @element.parent().innerWidth(), @element.parent().innerHeight()
      layer.replace null
    @changeLayer(index)
    @snap index, action: @UNDO_ADD_LAYER, state: null

  # Switch to a different layer; all drawing events will go to it. Emits `layer:set`.
  #
  # changeLayer :: int -> a
  #
  changeLayer: (i) ->
    layer.restyle(n, @scale) for n, layer of @layers

    if 0 <= i < @layers.length
      @layer = i
      @layers[q].element.removeClass 'active' for q of @layers
      @layers[i].element.addClass    'active'
      @trigger 'layer:set', [i]

  # Remove a layer. Emits `layer:del`.
  #
  # deleteLayer :: int -> a
  #
  deleteLayer: (i) ->
    if 0 <= i < @layers.length
      @snap i, action: @UNDO_DEL_LAYER
      @layers.splice(i, 1)[0].clear()
      @trigger 'layer:del', [i]
      @changeLayer min(@layer, @layers.length - 1)

  # Move a layer `delta` items closer to the top of the stack. Emits `layer:move`.
  #
  # moveLayer :: int int -> a
  #
  moveLayer: (i, delta) ->
    if 0 <= i < @layers.length and 0 <= i + delta < @layers.length
      @snap i, action: @UNDO_MOVE_LAYER, delta: delta
      @layers.splice(i + delta, 0, @layers.splice(i, 1)[0])
      @trigger 'layer:move', [i, delta]
      @changeLayer(i + delta)

  # Save a snapshot of a single layer in the undo stack.
  #
  # snap :: int (Optional Object) -> a
  #
  snap: (i, options = {}) ->
    if 0 <= i < @layers.length
      @redos = []
      @undos.splice 0, 0, jQuery.extend({
          index:  i
          state:  @layers[i].state()
          action: @UNDO_DRAW
        }, options)
      @undos.splice @undoLimit

  # Restore the previous `snap`ped state.
  #
  # undo :: -> a
  #
  undo: (reverse = false) ->
    redos = @redos
    undos = if reverse then @redos else @undos

    for data in undos.splice(0, 1)
      switch data.action
        when @UNDO_DRAW       then @snap(data.index); @layers[data.index].set(data.state)
        when @UNDO_DEL_LAYER  then @createLayer data.index, data.state
        when @UNDO_ADD_LAYER  then @deleteLayer data.index
        when @UNDO_MOVE_LAYER then @moveLayer   data.index + data.delta, -data.delta

    # The above operations all call `@snap`, which resets the redo stack and adds something
    # to `@undos`. We don't want the former, and possibly the latter, too.
    @redos = redos
    @redos.splice(0, 0, @undos.splice(0, 1)[0]) if @undos.length and not reverse

  # Cancel an `undo`.
  #
  # redo :: -> a
  #
  redo: -> @undo true

  # Serialize contents of the area.
  #
  # export :: str -> str
  #
  export: (type) ->
    switch type
      when "png"
        element = new Canvas(@element.innerWidth(), @element.innerHeight())[0]
        context = element.getContext('2d')
        context.drawImage layer.img(), layer.x, layer.y for layer in @layers
        return element.toDataURL("image/png")
      when "svg"
        xml = new XMLSerializer()
        element = $("<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'>")
        element.prepend(layer.svg()) for layer in @layers
        return "data:image/svg+xml;base64," + btoa(xml.serializeToString element[0])
    return null

  # Load the contents from a previously `export`ed file.
  #
  # import: str -> a
  #
  import: (data) ->
    colon = data.indexOf ":"
    semic = data.indexOf ";"
    comma = data.indexOf ","
    return false if data.slice(0,         colon) != "data"
    return false if data.slice(semic + 1, comma) != "base64"

    switch data.slice(colon + 1, semic)
      when "image/png"
        @createLayer(0, Canvas.Layer.prototype.stateFromURL(data))
        return true
      when "image/svg+xml"
        doc = $ atob(data.slice(comma + 1))
        doc.children().each (_, x) => @createLayer(0, Canvas.Layer.prototype.stateFromSVG($(x)))
        return true
    return false

  # Use a different tool. Tools must implement the `Canvas.Tool` interface
  # (see `tools.coffee`). Emits `tool:kind` and option-change events.
  #
  # setTool :: (Type extends Canvas.Tool) Object -> a
  #
  setTool: (kind, options) ->
    @tool = new kind(@, options)
    @setToolOptions @tool.options
    @trigger 'tool:kind', [kind, @tool.options]

  # Copy some options from an object over to the currently selected tool.
  # Emits various events that begin with `tool:` and end with the name of the option
  # that was changed.
  #
  # setToolOptions :: Object -> a
  #
  setToolOptions: (options) ->
    return if not @tool
    @tool.setOptions options
    @trigger('tool:' + k, [v, @tool.options]) for k, v of options

    sz = @tool.options.size * @scale
    $ @crosshair
      .attr {'width': sz, 'height': sz}
      .css  {'margin-left': -sz / 2, 'margin-top': -sz / 2}
      .css   'display', if @tool.options.size > 5 then '' else 'none'
    ctx = @crosshair.getContext('2d')
    ctx.translate sz / 2, sz / 2
    ctx.scale @scale, @scale
    @tool.crosshair ctx  # FIXME this goes out of bounds sometimes

  onMouseDown: (ev) ->
    # FIXME this next line prevents unwanted selection, but breaks focusing.
    ev.preventDefault()
    if 0 <= @layer < @layers.length and @tool and ev.button == 0 and evdev.reset ev
      @context = @layers[@layer].img().getContext '2d'
      @context.save()
      @context.clip path for path in @selection
      @context.translate -@layers[@layer].x, -@layers[@layer].y
      # TODO pressure & rotation
      if @tool.start(@context, (ev.offsetX or ev.layerX) / @scale, (ev.offsetY or ev.layerY) / @scale, 0, 0)
        @snap @layer
        @trigger 'stroke:begin', [@layers[@layer], @layer]
        @element[0].addEventListener 'mousemove',  @onMouseMove
        @element[0].addEventListener 'mouseleave', @onMouseUp
        @element[0].addEventListener 'mouseup',    @onMouseUp

  onMouseMove: (ev) ->
    if evdev.ok ev
      # TODO pressure & rotation
      @tool.move(@context, (ev.offsetX or ev.layerX) / @scale, (ev.offsetY or ev.layerY) / @scale, 0, 0)

  onMouseUp: (ev) ->
    if evdev.ok ev
      @tool.stop(@context, (ev.offsetX or ev.layerX) / @scale, (ev.offsetY or ev.layerY) / @scale)
      @element[0].removeEventListener 'mousemove',  @onMouseMove
      @element[0].removeEventListener 'mouseleave', @onMouseUp
      @element[0].removeEventListener 'mouseup',    @onMouseUp
      @trigger 'stroke:end', [@layers[@layer], @layer]
      @context.restore()

  onTouchStart: (ev) ->
    # FIXME this one is even worse depending on the device.
    #   On Chromium OS, this will prevent "back/forward" gestures from
    #   interfering with drawing, but will not focus the broswer window
    #   if the user taps the canvas.
    ev.preventDefault()
    if ev.touches.length == 1 and 0 <= @layer < @layers.length and @tool and ev.which == 0
      @context = @layers[@layer].img().getContext '2d'
      @context.save()
      @context.clip path for path in @selection
      @context.translate -@layers[@layer].x, -@layers[@layer].y
      @offsetX = @element.offset().left
      @offsetY = @element.offset().top
      t = ev.touches[0]
      x = t.clientX - @offsetX
      y = t.clientY - @offsetY
      if @tool.start @context, x / @scale, y / @scale, t.force, t.rotationAngle * PI / 180
        @snap @layer
        @trigger 'stroke:begin', [@layers[@layer], @layer]
        @element[0].addEventListener 'touchmove', @onTouchMove
        @element[0].addEventListener 'touchend',  @onTouchEnd
        true

  onTouchMove: (ev) ->
    t = ev.touches[0]
    x = t.clientX - @offsetX
    y = t.clientY - @offsetY
    @tool.move @context, x / @scale, y / @scale, t.force, t.rotationAngle * PI / 180

  onTouchEnd: (ev) ->
    if ev.touches.length == 0
      @tool.stop @context, @tool.lastX, @tool.lastY
      @element[0].removeEventListener 'touchmove', @onTouchMove
      @element[0].removeEventListener 'touchend',  @onTouchEnd
      @trigger 'stroke:end', [@layers[@layer], @layer]
      @context.restore()
