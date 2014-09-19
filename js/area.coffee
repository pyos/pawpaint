---
---

evdev =
  # When using tablets, evdev may bug and send the cursor jumping when doing
  # fine movements. To prevent this, we're going to ignore extremely fast
  # mouse movement events.
  lastX: 0
  lastY: 0

  reset: (ev) ->
    @lastX = ev.pageX
    @lastY = ev.pageY
    true

  ok: (ev, reset) ->
    ok = abs(ev.pageX - @lastX) + abs(ev.pageY - @lastY) < 200
    @lastX = ev.pageX
    @lastY = ev.pageY
    ok


# The main object. Allows the user to draw stuff on an element with either
# a mouse, a touchscreen, or a pen tablet.
#
# WARNING: DO NOT change the element's dimensions after creating an instance
#   of this type. This will cause the old layers to appear distorted (new ones will be fine).
#
# Area :: (Either str jQuery Node) (Optional [Type extends Canvas.Tool]) -> Canvas.Area
#
class Area
  UNDO_DRAW:       0
  UNDO_ADD_LAYER:  1
  UNDO_DEL_LAYER:  2
  UNDO_MOVE_LAYER: 3

  constructor: (selector, tools) ->
    # The main canvas container. Also fires some events; use `.element.on` to react.
    #
    # Drawing-related:
    #   stroke:begin (ev: Event, layer: Canvas, index: int) - before drawing
    #   stroke:end   (ev: Event, layer: Canvas, index: int) - after drawing
    #   refresh      (ev: Event, layer: Canvas, index: int) - when using `drawImage`
    #
    # Configuration:
    #   tool:kind    (ev: Event, kind: Class, opts: Object) - when a new tool is assigned
    #   tool:<name>  (ev: Event, value: any, opts: Object) - when a setting is modified
    #
    # Layers:
    #   layer:add    (ev: Event, layer: jQuery[Canvas])
    #   layer:del    (ev: Event, index: int)
    #   layer:set    (ev: Event, index: int)
    #   layer:toggle (ev: Event, index: int)
    #   layer:move   (ev: Event, old: int, delta: int)
    #
    @element = $(selector).eq(0)

    # A list of subclasses of `Canvas.Tool`.
    # You may use whatever tool you want through `setTool`, but only
    # these will be displayed in the options window.
    @tools = tools || [Canvas.Tool.Pen, Canvas.Tool.Eraser]

    # A complete list of layers ordered by z-index; each one is a `jQuery` object
    # wrapping a single `Canvas`.
    @layers = []
    @layer  = 0

    # An undo is a complete snapshot of a layer as a {layer: int, canvas: str}
    # object, where `canvas` is a PNG data URL.
    @undos = []
    @redos = []
    @undoLimit = 25

    # This canvas follows the mouse cursor around. Tools may
    # display something on it.
    @crosshair = crosshair = $('<canvas class="crosshair">').appendTo(@element)[0]

    # CoffeeScript's `=>` results in an ugly `__bind` wrapper.
    @onMouseMove  = @onMouseMove  .bind @
    @onMouseDown  = @onMouseDown  .bind @
    @onMouseUp    = @onMouseUp    .bind @
    @onTouchStart = @onTouchStart .bind @
    @onTouchMove  = @onTouchMove  .bind @
    @onTouchEnd   = @onTouchEnd   .bind @

    @element[0].addEventListener 'touchstart', @onTouchStart
    @element[0].addEventListener 'touchstart', (ev) ->
      # Hide the crosshair, it's useless.
      crosshair.style.left = '-100%'
      crosshair.style.top  = '-100%'

    @element[0].addEventListener 'mousedown', @onMouseDown
    @element[0].addEventListener 'mousemove', (ev) ->
      crosshair.style.left = (ev.offsetX || ev.layerX) + 'px'
      crosshair.style.top  = (ev.offsetY || ev.layerY) + 'px'

  # Save a snapshot of a single layer in the undo stack.
  #
  # snap :: int (Optional Object) -> a
  #
  snap: (layer, options = {}) ->
    if @layers.length > layer >= 0
      @redos = []
      @undos.splice 0, 0, jQuery.extend({
          action: @UNDO_DRAW,
          canvas: @layers[layer][0].toDataURL()
          layer:  layer
        }, options)
      @undos.splice @undoLimit

  # Load a layer from a data URL.
  #
  # load :: int str -> a
  #
  load: (layer, data, noSnapshot) ->
    img = new Image
    img.src = data
    @snap layer, action: @UNDO_DRAW unless noSnapshot
    ctx = @layers[layer][0].getContext '2d'
    ctx.clearRect(0, 0, @layers[layer][0].width, @layers[layer][0].height)
    ctx.drawImage(img, 0, 0)
    @element.trigger 'refresh', [@layers[layer][0], layer]

  # Restore the previous `snap`ped state.
  #
  # undo :: -> a
  #
  undo: (reverse = false) ->
    redos = @redos
    undos = if reverse then @redos else @undos

    for data in undos.splice(0, 1)
      switch data.action
        when @UNDO_DRAW       then @load data.layer, data.canvas
        when @UNDO_DEL_LAYER  then @addLayer data.layer; @load data.layer, data.canvas, true
        when @UNDO_ADD_LAYER  then @delLayer data.layer
        when @UNDO_MOVE_LAYER then @moveLayer data.layer + data.delta, -data.delta

    # The above operations all call `@snap`, which resets the redo stack and adds something
    # to `@undos`. We don't want the former, and possibly the latter, too.
    @redos = redos
    @redos.splice(0, 0, @undos.splice(0, 1)[0]) if @undos.length and not reverse

  # Cancel an `undo`.
  #
  # redo :: -> a
  #
  redo: -> @undo true

  onMouseDown: (ev) ->
    # FIXME this next line prevents unwanted selection, but breaks focusing.
    ev.preventDefault()
    if 0 <= @layer < @layers.length and @tool and ev.button == 0 and evdev.reset ev
      @context = @layers[@layer][0].getContext '2d'
      if @tool.start(@context, ev.offsetX || ev.layerX, ev.offsetY || ev.layerY)
        @snap @layer
        @element.trigger 'stroke:begin', [@layers[@layer][0], @layer]
        @element[0].addEventListener 'mousemove',  @onMouseMove
        @element[0].addEventListener 'mouseleave', @onMouseUp
        @element[0].addEventListener 'mouseup',    @onMouseUp

  onMouseMove: (ev) -> @tool.move(@context, ev.offsetX || ev.layerX, ev.offsetY || ev.layerY) if evdev.ok ev
  onMouseUp:   (ev) ->
    if evdev.ok ev
      @tool.stop(@context, ev.offsetX || ev.layerX, ev.offsetY || ev.layerY)
      @element[0].removeEventListener 'mousemove',  @onMouseMove
      @element[0].removeEventListener 'mouseleave', @onMouseUp
      @element[0].removeEventListener 'mouseup',    @onMouseUp
      @element.trigger 'stroke:end', [@layers[@layer][0], @layer]

  onTouchStart: (ev) ->
    # FIXME this one is even worse depending on the device.
    #   On Chromium OS, this will prevent "back/forward" gestures from
    #   interfering with drawing, but will not focus the broswer window
    #   if the user taps the canvas.
    ev.preventDefault()
    if 0 <= @layer < @layers.length and @tool and ev.which == 0
      @context = @layers[@layer][0].getContext '2d'
      @offsetX = @element.offset().left
      @offsetY = @element.offset().top
      if @tool.start @context, ev.touches[0].pageX - @offsetX, ev.touches[0].pageY - @offsetY
        @snap @layer
        @element.trigger 'stroke:begin', [@layers[@layer][0], @layer]
        @element[0].addEventListener 'touchmove', @onTouchMove
        @element[0].addEventListener 'touchend',  @onTouchEnd

  onTouchMove: (ev) ->
    if ev.which == 0
      # TODO multitouch drawing?
      @tool.move @context, ev.touches[0].clientX - @offsetX, ev.touches[0].clientY - @offsetY

  onTouchEnd: (ev) ->
    if ev.touches.length == 0
      @tool.stop @context, @tool.lastX, @tool.lastY
      @element[0].removeEventListener 'touchmove', @onTouchMove
      @element[0].removeEventListener 'touchend',  @onTouchEnd
      @element.trigger 'stroke:end', [@layers[@layer][0], @layer]

  # Add an empty layer at the end of the stack. Emits `layer:add`.
  #
  # addLayer :: (Optional int) -> a
  #
  addLayer: (index = -1) ->
    index = @layers.length if index < 0
    layer = $ "<canvas class='layer'
      width='#{@element.innerWidth()}'
      height='#{@element.innerHeight()}'>"
    layer.appendTo @element.trigger('layer:add', [layer])

    @layers.splice(index, 0, layer)
    @setLayer(index)
    @snap index, action: @UNDO_ADD_LAYER

  # Switch to a different layer; all drawing events will go to it. Emits `layer:set`.
  #
  # setLayer :: int -> a
  #
  setLayer: (i) ->
    if 0 <= i < @layers.length
      @layer = i
      @element.trigger 'layer:set', [i]
    x.css('z-index', i - @layers.length) for i, x of @layers

  # Remove a layer. Emits `layer:del`.
  #
  # delLayer :: int -> a
  #
  delLayer: (i) ->
    if 0 <= i < @layers.length
      @snap i, action: @UNDO_DEL_LAYER
      @layers.splice(i, 1)[0].remove()
      @element.trigger 'layer:del', [i]
      @setLayer min(@layer, @layers.length - 1)

  # Move a layer `delta` items closer to the top of the stack. Emits `layer:move`.
  #
  # moveLayer :: int int -> a
  #
  moveLayer: (i, delta) ->
    if 0 <= i < @layers.length and 0 <= i + delta < @layers.length
      @snap i, action: @UNDO_MOVE_LAYER, delta: delta
      @layers.splice(i + delta, 0, @layers.splice(i, 1)[0])
      @element.trigger 'layer:move', [i, delta]
      @setLayer(i + delta)

  # Toggle the visibility of a single layer. Does not actually affect its contents.
  # Emits `layer:toggle`.
  #
  # TODO: an easy way to check whether a layer is visible.
  #
  # toggleLayer :: int -> a
  #
  toggleLayer: (i) ->
    if 0 <= i < @layers.length
      @layers[i].toggle()
      @element.trigger 'layer:toggle', [i]

  # Use a different tool. Tools must implement the `Canvas.Tool` interface
  # (see `tools.coffee`). Emits `tool:kind` and option-change events.
  #
  # setTool :: (Type extends Canvas.Tool) Object -> a
  #
  setTool: (kind, options) ->
    @tool = new kind(options)
    @setToolOptions @tool.options
    @element.trigger 'tool:kind', [kind, @tool.options]

  # Copy some options from an object over to the currently selected tool.
  # Emits various events that begin with `tool:` and end with the name of the option
  # that was changed.
  #
  # setToolOptions :: Object -> a
  #
  setToolOptions: (options) ->
    return if not @tool
    @tool.setOptions options
    @element.trigger('tool:' + k, [v, @tool.options]) for k, v of options
    @crosshair.setAttribute 'width',  @tool.options.size
    @crosshair.setAttribute 'height', @tool.options.size
    @crosshair.style.marginLeft = -@tool.options.size / 2 + 'px'
    @crosshair.style.marginTop  = -@tool.options.size / 2 + 'px'
    @crosshair.style.display = if @tool.options.size > 5 then '' else 'none'
    @tool.crosshair @crosshair.getContext('2d')


@Canvas.Area = Area
