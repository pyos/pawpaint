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
# Area :: Node Type[Canvas.Tool]... -> Canvas.Area
#
@Canvas.Area = class Area extends EventSystem
  UNDO_DRAW:       0
  UNDO_ADD_LAYER:  1
  UNDO_DEL_LAYER:  2
  UNDO_MOVE_LAYER: 3
  UNDO_MERGE_DOWN: 4
  REDO_MERGE_DOWN: 5

  constructor: (@element, @tools...) ->
    super
    @palettes = {}  # :: {String: [{H, S, L}]} -- maps names to lists of colors
    @palette  = ""  # :: String -- current palette
    @scale  = 1
    @layer  = 0
    @layers = []  # :: [Canvas.Layer]
    @undos  = []
    @redos  = []
    @undoLimit = 25
    @crosshair = crosshair = Canvas(0, 0).addClass('crosshair').appendTo('body')[0]
    @selectui = Canvas(0, 0).addClass('hidden selection').appendTo(@element)[0]
    @selection = []

    @on 'layer:del layer:set', (->
      mw = 0
      mh = 0
      for layer in @layers
        mw = max(mw, layer.w + layer.x)
        mh = max(mh, layer.h + layer.y)
      @resize(mw, mh)
    ).bind(@)

    @on 'stroke:end', (layer) -> layer.trigger('redraw', layer)

    for kind in ['Mouse', 'Touch']
      for ev in ['Down', 'Move', 'Up']
        @['on' + kind + ev] = @['on' + kind + ev].bind(@)

    @element.addEventListener 'mouseleave', (ev) -> crosshair.style.display = 'none'
    @element.addEventListener 'touchstart', (ev) -> crosshair.style.display = 'none'
    @element.addEventListener 'touchstart', @onTouchDown
    @element.addEventListener 'mousedown',  @onMouseDown
    @element.addEventListener 'mousemove',  (ev) ->
      crosshair.style.left = ev.pageX + 'px'
      crosshair.style.top  = ev.pageY + 'px'
      crosshair.style.display = ''
    @resize(0, 0)

  # Change the size of the area.
  #
  # resize :: int int -> a
  #
  resize: (@w, @h) ->
    @element.style.width  = "#{@w * @scale}px"
    @element.style.height = "#{@h * @scale}px"
    @selectui.width  = @w * @scale
    @selectui.height = @h * @scale
    @setSelection @selection

  # Scale the area.
  #
  # setScale :: float -> a
  #
  setScale: (x) ->
    @scale = max(0, min(20, x))
    @resize(@w, @h)
    @setToolOptions {}  # rescale the crosshair
    @changeLayer(@layer)  # restyle all canvases

  # Select an area. Selecting an area clips all operations to that area.
  # It also enables copying and cutting.
  #
  # setSelection :: Path2D -> a
  #
  setSelection: (paths) ->
    @selection = paths
    if paths.length
      @selectui.className = "selection"
      ctx = @selectui.getContext '2d'
      ctx.save()
      ctx.fillStyle = "hsl(0, 0%, 50%)"
      ctx.fillRect 0, 0, @selectui.width, @selectui.height
      ctx.scale @scale, @scale
      ctx.clip(path) for path in paths
      ctx.clearRect 0, 0, @selectui.width / @scale, @selectui.height / @scale
      ctx.restore()
    else
      @selectui.className = "hidden selection"

  # Add an empty layer at the end of the stack. Emits `layer:add`.
  #
  # createLayer :: (Optional int) (Optional State) -> Layer
  #
  createLayer: (index = 0, state) ->
    layer = new Canvas.Layer @
    layer.on 'reprop', (layer) => @trigger('layer:reprop', layer, @layers.indexOf(layer))
         .on 'redraw', (layer) => @trigger('layer:redraw', layer, @layers.indexOf(layer))
         .on 'resize', (layer) => @trigger('layer:resize', layer, @layers.indexOf(layer))
         .on 'resize', (layer) => @changeLayer(@layer)  # to update the element
         .on 'redraw', (layer) => @changeLayer(@layer)
    @layers.splice(index, 0, layer)
    @trigger 'layer:add', layer, index
    layer.crop(0, 0, @w, @h)
    layer.set(state) if state
    @changeLayer(index)
    @snap index, action: @UNDO_ADD_LAYER, state: null
    return layer

  # Switch to a different layer; all drawing events will go to it. Emits `layer:set`.
  #
  # changeLayer :: int -> a
  #
  changeLayer: (i) ->
    if 0 <= i < @layers.length
      layer.restyle(@layers.length - n, @scale) for n, layer of @layers
      @layer = i
      @layers[q].element.removeClass 'active' for q of @layers
      @layers[i].element.addClass    'active'
      @trigger 'layer:set', i

  # Remove a layer. Emits `layer:del`.
  #
  # deleteLayer :: int -> a
  #
  deleteLayer: (i) ->
    if 0 <= i < @layers.length
      @snap i, action: @UNDO_DEL_LAYER
      @layers.splice(i, 1)[0].clear()
      @trigger 'layer:del', i
      @changeLayer min(@layer, @layers.length - 1)

  # Move a layer `delta` items closer to the top of the stack. Emits `layer:move`.
  #
  # moveLayer :: int int -> a
  #
  moveLayer: (i, delta) ->
    if 0 <= i < @layers.length and 0 <= i + delta < @layers.length
      @snap i, action: @UNDO_MOVE_LAYER, delta: delta
      @layers.splice(i + delta, 0, @layers.splice(i, 1)[0])
      @trigger 'layer:move', i, delta
      @changeLayer(i + delta)

  # Merge the layer down onto the next one, if there is one.
  #
  # mergeDown :: int -> a
  #
  mergeDown: (i) ->
    if 0 <= i < @layers.length - 1
      @snap i, action: @UNDO_MERGE_DOWN, below: @layers[i + 1].state(true)
      top = @layers.splice(i, 1)[0]
      bot = @layers[i]
      bot.crop(x = min(top.x, bot.x), y = min(top.y, bot.y),
          max(top.w + top.x, bot.w + bot.x) - x,
          max(top.h + top.y, bot.h + bot.y) - y)
      ctx = bot.img().getContext('2d')
      ctx.translate -bot.x, -bot.y
      top.drawOnto ctx
      top.clear()
      @trigger 'layer:del', i
      @changeLayer min(@layer, @layers.length - 1)

  # Save a snapshot of a single layer in the undo stack.
  #
  # snap :: int (Optional Object) -> a
  #
  snap: (i, options = {}) ->
    if 0 <= i < @layers.length
      @redos = []
      @undos.splice 0, 0, jQuery.extend({
          index:  i
          state:  @layers[i].state(true)
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
        when @REDO_MERGE_DOWN then @mergeDown   data.index
        when @UNDO_MERGE_DOWN
          @createLayer data.index, data.state
          @layers[data.index + 1].set(data.below)
          @undos[0].action = @REDO_MERGE_DOWN

    # The above operations all call `@snap`, which resets the redo stack and adds something
    # to `@undos`. We don't want the former, and possibly the latter, too.
    @redos = redos
    @redos.splice(0, 0, @undos.splice(0, 1)[0]) if @undos.length and not reverse

  # Cancel an `undo`.
  #
  # redo :: -> a
  #
  redo: -> @undo true

  # Serialize contents of the area. Supported methods:
  #
  #   png -- returns an image/png data URL; loses metadata, such as layers.
  #   svg -- returns an image/svg+xml data URL where all metadata is preserved.
  #   flatten -- returns a canvas onto which all layers have been drawn in order.
  #
  # export :: str -> object
  #
  export: (type) ->
    switch type
      when "flatten"
        element = new Canvas(@w, @h)[0]
        context = element.getContext('2d')
        layer.drawOnto context for layer in @layers by -1
        return element
      when "png"
        return @export("flatten").toDataURL("image/png")
      when "svg"
        xml = new XMLSerializer()
        element = $("<svg:svg xmlns:svg='http://www.w3.org/2000/svg' width='#{@w}'
                          xmlns:xlink='http://www.w3.org/1999/xlink' height='#{@h}'>")
        element.css 'isolation', 'isolate'
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

  # Load the contents of every file in a drag-and-drop operation or the clipboard.
  #
  # paste :: DataTransfer -> a
  #
  paste: (data) ->
    for type in data.types
      if type.match(/image\/.*/)
        @import(data.getData(type))
    for item in data.files
      if item.type.match(/image\/.*/)
        file = new FileReader
        file.onload = (r) => @import(r.target.result)
        file.readAsDataURL item

  # Copy some options from an object over to the currently selected tool.
  # Emits various events that begin with `tool:` and end with the name of the option
  # that was changed.
  #
  # setToolOptions :: Object -> a
  #
  setToolOptions: (options) ->
    k = options.kind
    @tool = new k(@, if @tool then @tool.options else {}) if k
    @tool.setOptions options
    @trigger('tool:' + k, v, @tool.options) for k, v of if k then @tool.options else options
    @trigger('tool:options', @tool.options)

    sz = @tool.options.size * @scale
    cr = $ @crosshair
      .attr {'width': sz, 'height': sz}
      .css  {'margin-left': -sz / 2, 'margin-top': -sz / 2}
    if @tool.options.size > 5 then cr.removeClass 'hidden' else cr.addClass 'hidden'
    ctx = @crosshair.getContext('2d')
    ctx.translate sz / 2, sz / 2
    ctx.scale @scale, @scale
    @tool.crosshair ctx  # FIXME this goes out of bounds sometimes

  _getContext: ->
    context = @layers[@layer].img().getContext '2d'
    context.save()
    context.translate 0.5 - @layers[@layer].x, 0.5 - @layers[@layer].y
    context.clip path for path in @selection
    return context

  onMouseDown: (ev) ->
    if ev.which is 1 and (ev.buttons is undefined or ev.buttons is 1)
      if 0 <= @layer < @layers.length and @tool and not @context and evdev.reset ev
        # FIXME this next line prevents unwanted selection, but breaks focusing.
        ev.preventDefault()
        x = ev.offsetX or ev.layerX
        y = ev.offsetY or ev.layerY
        @context = @_getContext()
        # TODO pressure & rotation
        if @tool.start(@context, x / @scale, y / @scale, 0, 0)
          @snap @layer
          @trigger 'stroke:begin', @layers[@layer], @layer
          @element.addEventListener 'mouseenter', @onMouseDown if ev.type isnt "mouseenter"
          @element.addEventListener 'mousemove',  @onMouseMove
          @element.addEventListener 'mouseleave', @onMouseUp
          @element.addEventListener 'mouseup',    @onMouseUp

  onMouseMove: (ev) ->
    if evdev.ok ev
      x = ev.offsetX or ev.layerX
      y = ev.offsetY or ev.layerY
      # TODO pressure & rotation
      @tool.move(@context, x / @scale, y / @scale, 0, 0)

  onMouseUp: (ev) ->
    if ev.type is "mouseup" or evdev.ok(ev)
      @tool.stop @context
      @element.removeEventListener 'mouseenter', @onMouseDown if ev.type isnt "mouseleave"
      @element.removeEventListener 'mousemove',  @onMouseMove
      @element.removeEventListener 'mouseleave', @onMouseUp
      @element.removeEventListener 'mouseup',    @onMouseUp
      @trigger 'stroke:end', @layers[@layer], @layer
      @context.restore()
      @context = null

  onTouchDown: (ev) ->
    if ev.touches.length == 1 and 0 <= @layer < @layers.length and @tool and not @context and ev.which == 0
      # FIXME this one is even worse depending on the device.
      #   On Chromium OS, this will prevent "back/forward" gestures from
      #   interfering with drawing, but will not focus the broswer window
      #   if the user taps the canvas.
      ev.preventDefault()
      @context = @_getContext()
      r = @element.getBoundingClientRect()
      t = ev.touches[0]
      x = t.clientX - r.left
      y = t.clientY - r.top
      if @tool.start @context, x / @scale, y / @scale, t.force, t.rotationAngle * PI / 180
        @snap @layer
        @trigger 'stroke:begin', @layers[@layer], @layer
        @element.addEventListener 'touchmove', @onTouchMove
        @element.addEventListener 'touchend',  @onTouchUp

  onTouchMove: (ev) ->
    r = @element.getBoundingClientRect()
    t = ev.touches[0]
    x = t.clientX - r.left
    y = t.clientY - r.top
    @tool.move @context, x / @scale, y / @scale, t.force, t.rotationAngle * PI / 180

  onTouchUp: (ev) ->
    if ev.touches.length == 0
      @tool.stop @context
      @element.removeEventListener 'touchmove', @onTouchMove
      @element.removeEventListener 'touchend',  @onTouchUp
      @trigger 'stroke:end', @layers[@layer], @layer
      @context.restore()
      @context = null
