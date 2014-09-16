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
    @element   = $(selector).eq(0)
    @tools     = tools
    @layer     = 0
    @layers    = []
    @crosshair = crosshair = $('<canvas class="crosshair">').appendTo(@element)[0]

    @onMouseMove = @onMouseMove.bind @
    @onMouseDown = @onMouseDown.bind @
    @onMouseUp   = @onMouseUp  .bind @

    @element[0].addEventListener 'mousedown', @onMouseDown
    @element[0].addEventListener 'mousemove', (ev) ->
      crosshair.style.left = ev.offsetX + 'px'
      crosshair.style.top  = ev.offsetY + 'px'

  onMouseMove: (ev) -> @tool.move @context, ev.offsetX, ev.offsetY if evdev.ok ev
  onMouseUp:   (ev) ->
    if evdev.ok ev
      @tool.stop @context, ev.offsetX, ev.offsetY
      @element[0].removeEventListener 'mousemove',  @onMouseMove
      @element[0].removeEventListener 'mouseleave', @onMouseUp
      @element[0].removeEventListener 'mouseup',    @onMouseUp
      @element.trigger 'stroke:end', [@layers[@layer].canvas[0], @layer]

  onMouseDown: (ev) ->
    if ev.button == 0 and evdev.reset ev
      ev.preventDefault()
      @element.trigger 'stroke:begin', [@layers[@layer].canvas[0], @layer]
      @element[0].addEventListener 'mousemove',  @onMouseMove
      @element[0].addEventListener 'mouseleave', @onMouseUp
      @element[0].addEventListener 'mouseup',    @onMouseUp
      @tool.start @context, ev.offsetX, ev.offsetY
    else if ev.button == 1 then @element.trigger 'button:1', [ev]
    else if ev.button == 2 then @element.trigger 'button:2', [ev]

  addLayer: (name) ->
    layer = new Layer(@element, name, @element.innerWidth(), @element.innerHeight())
    @layers.push(layer)
    @element.append(layer.canvas).trigger('layer:add', [layer])
    @setLayer(@layers.length - 1)
    @redoLayout()

  setLayer: (i) ->
    if 0 <= i < @layers.length
      @context = @layers[@layer = i].context
      @element.trigger 'layer:set', [i]

  delLayer: (i) ->
    if 0 <= i < @layers.length
      layer = @layers.splice(i, 1)[0]
      layer.canvas.remove()
      @element.trigger 'layer:del', [i]
      @addLayer null if not @layers.length
      @setLayer Math.min(@layer, @layers.length - 1)
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
    x.canvas.css 'z-index', i - @layers.length for i, x of @layers

  setTool: (kind, size, color, options) ->
    @tool = new kind(size, color, options)
    @setToolOptions @tool.options
    @element.trigger 'tool:kind', [kind]

  setToolOptions: (options) ->
    @tool.setOptions options
    @element.trigger('tool:' + k, [v]) for k, v of options
    @crosshair.setAttribute 'width',  @tool.options.size
    @crosshair.setAttribute 'height', @tool.options.size
    @crosshair.style.marginLeft = -@tool.options.size / 2 + 'px'
    @crosshair.style.marginTop  = -@tool.options.size / 2 + 'px'
    @crosshair.style.display = if @tool.options.size > 5 then '' else 'none'
    @tool.crosshair @crosshair.getContext('2d')


window.Canvas or= {}
window.Canvas.Area = Area
