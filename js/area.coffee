evdev =
  # When using tablets, evdev may bug and send the cursor jumping when doing
  # fine movements. To prevent this, we're going to ignore extremely fast
  # mouse movement events.
  #
  # Usage:
  #
  #   smth.on 'mousedown', (ev) ->
  #     if evdev.reset ev # !!! new code !!!
  #       ...
  #
  #   smth.on 'mousemove', (ev) ->
  #     if evdev.ok ev # !!! new code !!!
  #       ...
  #
  lastX: 0
  lastY: 0
  reset: (ev) ->
    @lastX = ev.pageX
    @lastY = ev.pageY
    true

  ok: (ev, reset) ->
    ok = Math.abs(ev.pageX - @lastX) + Math.abs(ev.pageY - @lastY) < 200
    @lastX = ev.pageX
    @lastY = ev.pageY
    ok


class Layer
  defaults:
    name: "Layer"

  constructor: (area, name, w, h) ->
    @canvas  = $ "<canvas class='layer' width='#{w}' height='#{h}'>"
    @context = @canvas[0].getContext "2d"
    @name    = name || @defaults.name
    @drawing = false


class Area
  constructor: (selector, tools) ->
    @element   = $ selector
    @tools     = tools
    @layer     = 0
    @layers    = []
    @crosshair = $ '<canvas>'
      .css 'position', 'absolute'
      .css 'pointer-events', 'none'
      .appendTo @element

  event: (name, layer) ->
    tool    = @tool
    context = layer.context

    switch name
      when "mousedown" then (ev) =>
        ev.preventDefault()

        if ev.button == 0 and evdev.reset ev
          layer.drawing = true
          tool.start context, ev.offsetX, ev.offsetY
        else if layer.drawing
          layer.drawing = false
          tool.stop context, ev.offsetX, ev.offsetY

        if ev.button == 1 then @element.trigger 'button:1', [ev]
        if ev.button == 2 then @element.trigger 'button:2', [ev]

      when "mousemove" then (ev) =>
        @crosshair
          .css 'left', ev.offsetX - @crosshair.sz
          .css 'top',  ev.offsetY - @crosshair.sz

        if layer.drawing and evdev.ok ev
          tool.move context, ev.offsetX, ev.offsetY

      when "mouseup", "mouseleave" then (ev) =>
        if layer.drawing and evdev.ok ev
          layer.drawing = false
          tool.stop(context, ev.offsetX, ev.offsetY)

  addLayer: (name) ->
    layer = new Layer(@element, name, @element.innerWidth(), @element.innerHeight())
    layer.canvas.appendTo @element
    @layers.push(layer)
    @element.trigger 'layer:add', [layer]
    @setLayer(@layers.length - 1)
    @redoLayout()

  setLayer: (i) ->
    if 0 <= i < @layers.length
      @layer = i
      for ev in ['mousedown', 'mouseup', 'mouseleave', 'mousemove']
        @element.off ev
        @element.on  ev, @event(ev, @layers[i])
      @element.trigger 'layer:set', [i]

  delLayer: (i) ->
    if 0 <= i < @layers.length
      layer = @layers.splice(i, 1)[0]
      layer.canvas.remove()
      @element.trigger 'layer:del', [i]
      @addLayer null if not @layers.length
      @setLayer @layer
      @redoLayout()

  moveLayer: (i, delta) ->
    if 0 <= i < @layers.length and 0 <= i + delta < @layers.length
      @layers.splice(i + delta, 0, @layers.splice(i, 1)[0])
      @element.trigger 'layer:move', [i, delta]
      @setLayer(i + delta)
      @redoLayout()

  toggleLayer: (i) ->
    @layers[i].canvas.toggle()
    @element.trigger 'layer:toggle', [i]

  redoLayout: ->
    for i of @layers
      @layers[i].canvas.css 'z-index', i - @layers.length

  setTool: (kind, size, color, options) ->
    @tool = new kind(size, color, options)
    @tool.kind = kind
    @element.trigger 'tool:kind', [kind]
    @setToolOptions @tool.options
    @setLayer(@layer)

  setToolOptions: (options) ->
    @tool.setOptions options
    for k of options
      @element.trigger('tool:' + k, [options[k]])
    @crosshair.attr 'width',  @tool.options.size
    @crosshair.attr 'height', @tool.options.size
    @crosshair.sz = @tool.options.size / 2
    @tool.crosshair @crosshair[0].getContext('2d')


window.Canvas or= {}
window.Canvas.Area = Area
