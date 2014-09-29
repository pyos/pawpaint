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

  constructor: (selector, tools...) ->
    # The main canvas container. Also fires some events; use `.element.on` to react.
    #
    # Drawing-related:
    #   stroke:begin (ev: Event, layer: Canvas, index: int) - before drawing
    #   stroke:end   (ev: Event, layer: Canvas, index: int) - after drawing
    #
    # Configuration:
    #   tool:kind    (ev: Event, kind: Class, opts: Object) - when a new tool is assigned
    #   tool:<name>  (ev: Event, value: any, opts: Object) - when a setting is modified
    #
    # Layers:
    #   layer:add    (ev: Event, layer: Canvas, index: int)
    #   layer:redraw (ev: Event, layer: Canvas, index: int)
    #   layer:del    (ev: Event, index: int)
    #   layer:set    (ev: Event, index: int)
    #   layer:toggle (ev: Event, index: int)
    #   layer:move   (ev: Event, old: int, delta: int)
    #
    @element = $('<div class="area background">').appendTo $(selector).eq(0)
    @element.on 'stroke:end', (_, c, i) -> $(@).trigger 'layer:redraw', [c, i]
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

    # CoffeeScript's `=>` results in an ugly `__bind` wrapper.
    @onMouseMove  = @onMouseMove  .bind @
    @onMouseDown  = @onMouseDown  .bind @
    @onMouseUp    = @onMouseUp    .bind @
    @onTouchStart = @onTouchStart .bind @
    @onTouchMove  = @onTouchMove  .bind @
    @onTouchEnd   = @onTouchEnd   .bind @

    @element.on 'layer:del layer:set', =>
      ep = @element.position()
      mw = 0
      mh = 0
      for layer in @layers
        lp = layer.position()
        mw = max(mw, layer.innerWidth()  + lp.left - ep.left)
        mh = max(mh, layer.innerHeight() + lp.top  - ep.top)
      @element.css('width', mw).css('height', mh)
      @setToolOptions {}  # rescale the crosshair

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
    if x > 0
      @scale = x
      @changeLayer(@layer)

  # Add an empty layer at the end of the stack. Emits `layer:add`.
  #
  # createLayer :: (Optional int) (Optional int) (Optional int) (Optional int) -> a
  #
  createLayer: (index = -1, w, h, x = 0, y = 0) ->
    w or= @element.parent().innerWidth()
    h or= @element.parent().innerHeight()
    index = @layers.length if index < 0
    layer = new Canvas(w, h).data('x', x).data('y', y).addClass('layer')
    @layers.splice(index, 0, layer)
    @element.append(layer).trigger('layer:add', [layer[0], index])
    @changeLayer(index)
    @snap index, action: @UNDO_ADD_LAYER

  # Switch to a different layer; all drawing events will go to it. Emits `layer:set`.
  #
  # changeLayer :: int -> a
  #
  changeLayer: (i) ->
    for n, x of @layers
      x.css('z-index', n - @layers.length)
       .css('left',   x.data('x') * @scale)
       .css('top',    x.data('y') * @scale)
       .css('width',  x[0].width  * @scale)
       .css('height', x[0].height * @scale)

    if 0 <= i < @layers.length
      @layer = i
      @element.children('.layer').removeClass('active').eq(i).addClass('active')
      @element.trigger 'layer:set', [i]

  # Remove a layer. Emits `layer:del`.
  #
  # deleteLayer :: int -> a
  #
  deleteLayer: (i) ->
    if 0 <= i < @layers.length
      @snap i, action: @UNDO_DEL_LAYER
      @layers.splice(i, 1)[0].remove()
      @element.trigger 'layer:del', [i]
      @changeLayer min(@layer, @layers.length - 1)

  # Move a layer `delta` items closer to the top of the stack. Emits `layer:move`.
  #
  # moveLayer :: int int -> a
  #
  moveLayer: (i, delta) ->
    if 0 <= i < @layers.length and 0 <= i + delta < @layers.length
      @snap i, action: @UNDO_MOVE_LAYER, delta: delta
      @layers.splice(i + delta, 0, @layers.splice(i, 1)[0])
      @element.trigger 'layer:move', [i, delta]
      @changeLayer(i + delta)

  # Toggle the visibility of a single layer. Does not actually affect its contents.
  # Emits `layer:toggle`.
  #
  # toggleLayer :: int -> a
  #
  toggleLayer: (i) ->
    if 0 <= i < @layers.length
      @layers[i].toggle()
      @element.trigger 'layer:toggle', [i]

  # Change the dimensions of a layer.
  #
  # resizeLayer :: int int int -> a
  #
  resizeLayer: (layer, w, h, x = 0, y = 0, im = @layers[layer][0], noSnapshot) ->
    if 0 <= layer < @layers.length
      @snap layer, action: @UNDO_DRAW unless noSnapshot
      @layers[layer].replaceWith(@layers[layer] = cnv = @fromImage im, w, h, x, y).remove()
      @element.trigger 'layer:resize', [cnv[0], layer]
      @element.trigger 'layer:redraw', [cnv[0], layer]
      @changeLayer(@layer)

  # Load a layer from a data URL.
  #
  # load :: int str -> a
  #
  reloadLayer: (layer, data, x = 0, y = 0, noSnapshot) ->
    img = new Image
    img.src = data
    @resizeLayer layer, img.width, img.height, x, y, img, noSnapshot

  # Create a layer from an image.
  #
  # fromImage :: Image -> Canvas
  #
  fromImage: (img, w = img.width, h = img.height, x = 0, y = 0) ->
    cnv = new Canvas(w, h).data('x', x).data('y', y).addClass('layer')
    ctx = cnv[0].getContext('2d')
    ctx.drawImage img, 0, 0
    return cnv

  # Save a snapshot of a single layer in the undo stack.
  #
  # snap :: int (Optional Object) -> a
  #
  snap: (layer, options = {}) ->
    if 0 <= layer < @layers.length
      @redos = []
      @undos.splice 0, 0, jQuery.extend({
          action: @UNDO_DRAW
          canvas: @layers[layer][0].toDataURL()
          x: @layers[layer].position().x
          y: @layers[layer].position().y
          layer:  layer
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
        when @UNDO_DRAW       then @reloadLayer data.layer, data.canvas
        when @UNDO_DEL_LAYER  then @createLayer data.layer; @reloadLayer data.layer, data.canvas, data.x, data.y, true
        when @UNDO_ADD_LAYER  then @deleteLayer data.layer
        when @UNDO_MOVE_LAYER then @moveLayer   data.layer + data.delta, -data.delta

    # The above operations all call `@snap`, which resets the redo stack and adds something
    # to `@undos`. We don't want the former, and possibly the latter, too.
    @redos = redos
    @redos.splice(0, 0, @undos.splice(0, 1)[0]) if @undos.length and not reverse

  # Cancel an `undo`.
  #
  # redo :: -> a
  #
  redo: -> @undo true

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

    sp = @tool.options.size
    sz = @tool.options.size * @scale
    $(@crosshair).attr 'width',  sz + 1
                 .attr 'height', sz + 1
                 .css 'margin-left', -sz / 2
                 .css 'margin-top',  -sz / 2
                 .css 'display', if @tool.options.size > 5 then '' else 'none'
    ctx = @crosshair.getContext('2d')
    ctx.translate sz / 2, sz / 2
    @tool.options.size = sz
    @tool.crosshair ctx
    @tool.options.size = sp

  onMouseDown: (ev) ->
    # FIXME this next line prevents unwanted selection, but breaks focusing.
    ev.preventDefault()
    if 0 <= @layer < @layers.length and @tool and ev.button == 0 and evdev.reset ev
      @context = @layers[@layer][0].getContext '2d'
      # TODO pressure & rotation
      if @tool.start(@context, (ev.offsetX or ev.layerX) / @scale, (ev.offsetY or ev.layerY) / @scale, 0, 0)
        @snap @layer
        @element.trigger 'stroke:begin', [@layers[@layer][0], @layer]
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
      @element.trigger 'stroke:end', [@layers[@layer][0], @layer]

  onTouchStart: (ev) ->
    # FIXME this one is even worse depending on the device.
    #   On Chromium OS, this will prevent "back/forward" gestures from
    #   interfering with drawing, but will not focus the broswer window
    #   if the user taps the canvas.
    ev.preventDefault()
    if ev.touches.length == 1 and 0 <= @layer < @layers.length and @tool and ev.which == 0
      @context = @layers[@layer][0].getContext '2d'
      @offsetX = @element.offset().left
      @offsetY = @element.offset().top
      t = ev.touches[0]
      x = t.clientX - @offsetX
      y = t.clientY - @offsetY
      if @tool.start @context, x / @scale, y / @scale, t.force, t.rotationAngle * PI / 180
        @snap @layer
        @element.trigger 'stroke:begin', [@layers[@layer][0], @layer]
        @element[0].addEventListener 'touchmove', @onTouchMove
        @element[0].addEventListener 'touchend',  @onTouchEnd

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
      @element.trigger 'stroke:end', [@layers[@layer][0], @layer]

  # Serialize contents of the area.
  #
  # export :: str -> str
  #
  export: (type) ->
    switch type
      when "png"
        target  = new Canvas(@element.innerWidth(), @element.innerHeight())[0]
        context = target.getContext('2d')
        context.drawImage layer[0], layer.position().left, layer.position().top for layer in @layers
        return target.toDataURL("image/png")
      when "svg"
        target = $("<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'>")
        for layer in @layers
          $('<image>').appendTo(target)
            .attr('xlink:href', layer[0].toDataURL("image/png"))
            .attr("x",      layer.position().left + "px")
            .attr("y",      layer.position().top  + "px")
            .attr("width",  layer.innerWidth()    + "px")
            .attr("height", layer.innerHeight()   + "px")
        xml = new XMLSerializer().serializeToString target[0]
        return "data:image/svg+xml;base64," + btoa(xml)
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
        @createLayer()
        @reloadLayer(@layer, data, true)
        return true
      when "image/svg+xml"
        doc = $ atob(data.slice(comma + 1))
        doc.children('image').each (_, x) =>
          @createLayer()
          @reloadLayer(@layer, $(x).attr("xlink:href"), $(x).attr("x"), $(x).attr("y"), true)
        return true
    return false


@Canvas.Area = Area
