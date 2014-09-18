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


class Area
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
    @undoLimit = 10

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

    # These are used to handle touch events since `Touch`es do not have
    # `offsetX`/`offsetY` attributes. (Don't move the area around the page.)
    @offsetX = @element.offset().left
    @offsetY = @element.offset().top

    @element[0].addEventListener 'touchstart', @onTouchStart
    @element[0].addEventListener 'touchstart', (ev) ->
      # Hide the crosshair, it's useless.
      crosshair.style.left = '-100%'
      crosshair.style.top  = '-100%'

    @element[0].addEventListener 'mousedown', @onMouseDown
    @element[0].addEventListener 'mousemove', (ev) ->
      crosshair.style.left = ev.offsetX + 'px'
      crosshair.style.top  = ev.offsetY + 'px'

  # Save a snapshot of a single layer in the undo stack.
  #
  # snap :: int -> a
  #
  snap: (layer) ->
    if @layers.length > layer
      @undos.splice(@undos.length, 0, layer: layer, canvas: @layers[layer][0].toDataURL())
      @undos.splice(0, @undos.length - @undoLimit) if @undos.length > @undoLimit
      @redos = []

  # Load a layer from a data URL.
  #
  # load :: int str -> a
  #
  load: (layer, data) ->
    img = new Image
    img.onload = =>
      lo  = @layers[layer]
      ctx = lo[0].getContext '2d'
      ctx.clearRect(0, 0, lo.innerWidth(), lo.innerHeight())
      ctx.drawImage(img, 0, 0)
      @element.trigger 'refresh', [lo[0], layer]
    img.src = data

  # Restore the previous `snap`ped state.
  #
  # undo :: -> a
  #
  undo: (reverse = false) ->
    if reverse then from = @redos; to = @undos else
                    from = @undos; to = @redos

    if from.length
      data = from.splice(from.length - 1, 1)[0]
      to.push layer: data.layer, canvas: @layers[data.layer][0].toDataURL()
      @load data.layer, data.canvas

  # Cancel an `undo`.
  #
  # redo :: -> a
  #
  redo: -> @undo true

  onMouseDown: (ev) ->
    @element.focus()
    if ev.button == 0 and evdev.reset ev
      # FIXME this next line prevents unwanted selection, but breaks focusing.
      ev.preventDefault()
      if @tool.start @context, ev.offsetX, ev.offsetY
        @element.trigger 'stroke:begin', [@layers[@layer][0], @layer]
        @element[0].addEventListener 'mousemove',  @onMouseMove
        @element[0].addEventListener 'mouseleave', @onMouseUp
        @element[0].addEventListener 'mouseup',    @onMouseUp

  onMouseMove: (ev) -> @tool.move @context, ev.offsetX, ev.offsetY if evdev.ok ev
  onMouseUp:   (ev) ->
    if evdev.ok ev
      @tool.stop @context, ev.offsetX, ev.offsetY
      @element[0].removeEventListener 'mousemove',  @onMouseMove
      @element[0].removeEventListener 'mouseleave', @onMouseUp
      @element[0].removeEventListener 'mouseup',    @onMouseUp
      @element.trigger 'stroke:end', [@layers[@layer][0], @layer]

  onTouchStart: (ev) ->
    if ev.which == 0
      # FIXME this one is even worse depending on the device.
      #   On Chromium OS, this will prevent "back/forward" gestures from
      #   interfering with drawing, but will not focus the broswer window
      #   if the user taps the canvas.
      ev.preventDefault()
      if @tool.start @context, ev.touches[0].pageX - @offsetX, ev.touches[0].pageY - @offsetY
        @element.trigger 'stroke:begin', [@layers[@layer][0], @layer]
        @element[0].addEventListener 'touchmove', @onTouchMove
        @element[0].addEventListener 'touchend',  @onTouchEnd

  onTouchMove: (ev) ->
    if ev.which == 0
      # TODO multitouch drawing?
      @tool.move @context, ev.touches[0].pageX - @offsetX, ev.touches[0].pageY - @offsetY

  onTouchEnd: (ev) ->
    if ev.touches.length == 0
      @tool.stop @context, @tool.lastX, @tool.lastY
      @element[0].removeEventListener 'touchmove', @onTouchMove
      @element[0].removeEventListener 'touchend',  @onTouchEnd
      @element.trigger 'stroke:end', [@layers[@layer][0], @layer]

  addLayer: (name) ->
    layer = $ "<canvas class='layer'
      width='#{@element.innerWidth()}'
      height='#{@element.innerHeight()}'>"
    layer.appendTo @element.trigger('layer:add', [layer])
    @layers.push(layer)
    @setLayer(@layers.length - 1)
    @redoLayout()

  setLayer: (i) ->
    if 0 <= i < @layers.length
      @context = @layers[@layer = i][0].getContext '2d'
      @element.trigger 'layer:set', [i]

  delLayer: (i) ->
    if 0 <= i < @layers.length
      @layers.splice(i, 1)[0].remove()
      @element.trigger 'layer:del', [i]
      @addLayer null if not @layers.length
      @setLayer min(@layer, @layers.length - 1)
      @redoLayout()

  moveLayer: (i, delta) ->
    if 0 <= i < @layers.length and 0 <= i + delta < @layers.length
      @layers.splice(i + delta, 0, @layers.splice(i, 1)[0])
      @element.trigger 'layer:move', [i, delta]
      @setLayer(i + delta)
      @redoLayout()

  toggleLayer: (i) ->
    @layers[i].toggle()
    @element.trigger 'layer:toggle', [i]

  redoLayout: ->
    x.css('z-index', i - @layers.length) for i, x of @layers
    # Since these reference layers by indices, their contents are
    # most likely invalid.
    @undos = []
    @redos = []

  setTool: (kind, options) ->
    @tool = new kind(options)
    @setToolOptions @tool.options
    @element.trigger 'tool:kind', [kind, @tool.options]

  setToolOptions: (options) ->
    @tool.setOptions options
    @element.trigger('tool:' + k, [v, @tool.options]) for k, v of options
    @crosshair.setAttribute 'width',  @tool.options.size
    @crosshair.setAttribute 'height', @tool.options.size
    @crosshair.style.marginLeft = -@tool.options.size / 2 + 'px'
    @crosshair.style.marginTop  = -@tool.options.size / 2 + 'px'
    @crosshair.style.display = if @tool.options.size > 5 then '' else 'none'
    @tool.crosshair @crosshair.getContext('2d')


@Canvas.Area = Area
