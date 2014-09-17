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


class Area
  constructor: (selector, tools) ->
    @element   = $(selector).eq(0)
    @tools     = tools
    @layer     = 0
    @layers    = []
    @crosshair = crosshair = $('<canvas class="crosshair">').appendTo(@element)[0]

    @onMouseMove  = @onMouseMove  .bind @
    @onMouseDown  = @onMouseDown  .bind @
    @onMouseUp    = @onMouseUp    .bind @
    @onTouchStart = @onTouchStart .bind @
    @onTouchMove  = @onTouchMove  .bind @
    @onTouchEnd   = @onTouchEnd   .bind @

    @offsetX = @element.offset().left
    @offsetY = @element.offset().top

    @element[0].addEventListener 'touchstart', @onTouchStart
    @element[0].addEventListener 'touchstart', (ev) ->
      crosshair.style.left = '-100%'
      crosshair.style.top  = '-100%'

    @element[0].addEventListener 'mousedown',  @onMouseDown
    @element[0].addEventListener 'mousemove', (ev) ->
      crosshair.style.left = ev.offsetX + 'px'
      crosshair.style.top  = ev.offsetY + 'px'

  onMouseDown: (ev) ->
    if ev.button == 0 and evdev.reset ev
      ev.preventDefault()
      @element.trigger 'stroke:begin', [@layers[@layer][0], @layer]
      @element[0].addEventListener 'mousemove',  @onMouseMove
      @element[0].addEventListener 'mouseleave', @onMouseUp
      @element[0].addEventListener 'mouseup',    @onMouseUp
      @tool.start @context, ev.offsetX, ev.offsetY
    else if ev.button == 1 then @element.trigger 'button:1', [ev]
    else if ev.button == 2 then @element.trigger 'button:2', [ev]

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
      ev.preventDefault()
      @element.trigger 'stroke:begin', [@layers[@layer][0], @layer]
      @element[0].addEventListener 'touchmove', @onTouchMove
      @element[0].addEventListener 'touchend',  @onTouchEnd
      @tool.start @context, ev.touches[0].pageX - @offsetX, ev.touches[0].pageY - @offsetY

  onTouchMove: (ev) ->
    if ev.which == 0
      @tool.move @context, ev.touches[0].pageX - @offsetX, ev.touches[0].pageY - @offsetY

  onTouchEnd:  (ev) ->
    if ev.touches.length == 0
      @tool.stop @context, @tool.lastX, @tool.lastY
      @element[0].removeEventListener 'touchmove', @onTouchMove
      @element[0].removeEventListener 'touchend',  @onTouchEnd
      @element.trigger 'stroke:end', [@layers[@layer][0], @layer]

  addLayer: (name) ->
    layer = $ "<canvas class='layer' width='#{@element.innerWidth()}' height='#{ @element.innerHeight()}'>"
    layer.name = name || "Layer"
    @layers.push(layer)
    @element.append(layer).trigger('layer:add', [layer])
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
      @setLayer Math.min(@layer, @layers.length - 1)
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
    x.css 'z-index', i - @layers.length for i, x of @layers

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
