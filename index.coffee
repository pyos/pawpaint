pow = Math.pow

evdev =
  # When using tablets, evdev may bug and send the cursor jumping when doing
  # fine movements. To prevent this, we're going to ignore extremely fast
  # mouse movement events.
  #
  # Usage:
  #
  #   smth.on 'mousedown', (ev) ->
  #     if evdev.ok ev, true # !!! new code !!!
  #       ...
  #
  #   smth.on 'mousemove', (ev) ->
  #     if evdev.ok ev # !!! new code !!!
  #       ...
  #
  lastX: 0
  lastY: 0
  ok: (ev, reset) ->
    ok = Math.abs(ev.pageX - @lastX) + Math.abs(ev.pageY - @lastY) < 150
    if reset or ok
      @lastX = ev.pageX
      @lastY = ev.pageY
    reset or ok


class Tool
  defaults:
    dynamic: null
    opacity: 1
    size:    1
    color:   "#000000"

  constructor: (options) ->
    @options = jQuery.extend {}, @defaults
    @lastX = 0
    @lastY = 0
    @setOptions options

  crosshair: (ctx, options) ->
    ctx.lineWidth   = 1
    ctx.strokeStyle = "#777"
    ctx.stroke()

  setOptions: (options) ->
    @options = jQuery.extend @options, options

  start: (ctx, x, y) ->
  move:  (ctx, x, y) ->
  stop:  (ctx, x, y) ->


class Pen extends Tool
  crosshair: (ctx, options) ->
    size = options.size || @defaults.size
    ctx.beginPath()
    ctx.arc(size / 2, size / 2, size / 2, 0, 2 * Math.PI, false)
    super

  dynamize: (ctx, x, y) ->
    velocity = pow(pow(x - @lastX, 2) + pow(y - @lastY, 2), 0.333) || 0.1

    data =
      lx: @lastX
      ly: @lastY
      la: ctx.globalAlpha
      lw: ctx.lineWidth
      x:  x
      y:  y
      a:  ctx.globalAlpha
      w:  ctx.lineWidth

    switch @options.dynamic
      when "size"    then data.w = pow(0.01, 1 / velocity) * @options.size
      when "opacity" then data.a = (1 - pow(0.01, 1 / velocity)) * @options.opacity

    @lastX = x
    @lastY = y
    data

  draw: (ctx, data) ->
    steps  = 5
    x_step = (data.x - data.lx) / steps
    y_step = (data.y - data.ly) / steps
    a_step = (data.a - data.la) / steps
    w_step = (data.w - data.lw) / steps
    x = data.lx
    y = data.ly

    for i in [0...steps]
      ctx.lineWidth   += w_step
      ctx.globalAlpha += a_step
      ctx.beginPath()
      ctx.moveTo(x, y)
      ctx.lineTo((x += x_step), (y += y_step))
      ctx.stroke()

    ctx.lineWidth   = data.w
    ctx.globalAlpha = data.a
    data

  start: (ctx, x, y) ->
    ctx.lineCap     = "round"
    ctx.lineJoin    = "round"
    ctx.lineWidth   = @options.size
    ctx.strokeStyle = @options.color
    ctx.globalAlpha = @options.opacity
    @lastX = x
    @lastY = y
    data = @dynamize ctx, x, y
    ctx.lineWidth   = data.w
    ctx.globalAlpha = data.a
    data

  move: (ctx, x, y) -> @draw ctx, @dynamize(ctx, x, y)
  stop: (ctx, x, y) -> @draw ctx, @dynamize(ctx, x, y)


class Eraser extends Pen
  start: (ctx, x, y) ->
    @_old_mode = ctx.globalCompositeOperation
    ctx.globalCompositeOperation = "destination-out"
    super

  stop: (ctx, x, y) ->
    super
    ctx.globalCompositeOperation = @_old_mode


class Layer
  defaults:
    name: "Layer"

  constructor: (area, name) ->
    @canvas = $ '<canvas class="layer">'
    @canvasE = @canvas[0]
    @context = @canvasE.getContext "2d"
    @name    = name || @defaults.name
    @drawing = false


class Area
  constructor: (selector, tools) ->
    @element = $ selector
    @element.css 'overflow', 'hidden'

    @size      = @element[0].getBoundingClientRect()
    @tools     = tools
    @crosshair = $ '<span>'
    @layer     = 0
    @layers    = []

  event: (name, layer) ->
    size    = @size
    tool    = @tool
    context = layer.context

    switch name
      when "touchstart" then (ev) =>
        touch = ev.originalEvent.targetTouches[0]
        ev.preventDefault()

        if ev.originalEvent.targetTouches.length == 1
          layer.drawing = true
          tool.start(context, touch.pageX - size.left, touch.pageY - size.top)
          # Strictly speaking, this hack is unnecessary on touchpads.
          # However, it's way easier to use it than to special-case touch events.
          evdev.ok touch, true
        else if layer.drawing
          layer.drawing = false
          tool.stop(context, touch.pageX - size.left, touch.pageY - size.top)

      when "mousedown" then (ev) =>
        ev.preventDefault()
        if ev.button == 0 and evdev.ok ev, true
          layer.drawing = true
          tool.start(context, ev.pageX - size.left, ev.pageY - size.top)

      when "mousemove", "touchmove" then (ev) =>
        ev = ev.originalEvent?.targetTouches?[0] || ev
        @crosshair
          .css 'left', ev.pageX - @crosshair_left
          .css 'top',  ev.pageY - @crosshair_top

        if layer.drawing and evdev.ok ev
          tool.move(context, ev.pageX - size.left, ev.pageY - size.top)

      when "mouseup", "touchend" then (ev) =>
        ev = ev.originalEvent?.targetTouches?[0] || ev
        if layer.drawing and evdev.ok ev
          layer.drawing = false
          tool.stop(context, ev.pageX - size.left, ev.pageY - size.top)

  addLayer: (name) ->
    layer = new Layer(@element, name)
    layer.canvas.css 'z-index', @layers.length
    layer.canvas.appendTo @element
    layer.canvasE.setAttribute 'width',  @element[0].offsetWidth
    layer.canvasE.setAttribute 'height', @element[0].offsetHeight
    @layers.push(layer)
    @element.trigger 'layer:add', [layer]
    @setLayer(@layers.length - 1)
    @redoLayout()

  setLayer: (i) ->
    if 0 <= i < @layers.length
      layer  = @layers[i]
      events = ['mousedown', 'mouseup', 'mouseleave', 'mousemove',
                'touchstart', 'touchmove', 'touchend']

      @layer = i
      for ev in events
        @element.off ev
        @element.on  ev, @event(ev, layer)
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
      @layers[i].canvas.css 'z-index', i

  redoCrosshair: ->
    @crosshair.remove()
    @crosshair = $ '<canvas>'
    @crosshair.appendTo @element
    @crosshair.css 'z-index', '65536'
    @crosshair.css 'position', 'absolute'
    @crosshair.attr 'width',  @tool.size
    @crosshair.attr 'height', @tool.size
    @crosshair_left = @element[0].offsetLeft + @tool.size / 2
    @crosshair_top  = @element[0].offsetTop  + @tool.size / 2
    @tool.options.kind.prototype.crosshair(
      @crosshair[0].getContext('2d'), @tool.options)

  setTool: (kind, size, color, options) ->
    @tool = new kind(size, color, options)
    @tool.options.kind = kind

    for k of @tool.options
      @element.trigger('tool:' + k, [@tool.options[k]])

    @redoCrosshair()
    @setLayer(@layer)

  setToolOptions: (options) ->
    @tool.setOptions options
    for k of options
      @element.trigger('tool:' + k, [options[k]])
    @redoCrosshair()


$ ->
  area = window.area = new Area '.main-area', [Pen, Eraser]

  tools = $ '.tool-menu'
  tools.on 'click', '[data-tool]', ->
    tool = area.tools[parseInt $(this).attr('data-tool')]
    area.setTool tool, area.tool.options

  for t of area.tools
    item = $ "<a data-tool='#{t}'>"
    item.text area.tools[t].name
    $("<li>").append(item).appendTo(tools)

  colors = $ '.color-picker'
  colors.on 'click', -> colors.input.click()
  colors.input = $ '<input type="color">'
  colors.input.css 'position', 'absolute'
  colors.input.css 'visibility', 'hidden'
  colors.input.appendTo area.element
  colors.input.on 'change', -> area.setToolOptions color: @value

  width = $ '.width-picker'
  width.input = $ '<input type="range" min="1" max="61" step="1">'
  width.input.appendTo width.html('')
  width.input.on 'change',     -> area.setToolOptions size: parseInt(@value)
  width.input.on 'click', (ev) -> ev.stopPropagation()

  layers = $ '.layer-menu'
  layers
    .on 'click', '.toggle', (ev) ->
      ev.stopPropagation()
      area.toggleLayer $(this).parents('li').index()

    .on 'click', '.remove', (ev) ->
      ev.stopPropagation()
      area.delLayer $(this).parents('li').index()

    .on 'click', 'li', (ev) ->
      area.setLayer $(this).index()

  area.element
    .on 'tool:size',  (_, v) -> width.input.val v
    .on 'tool:color', (_, v) -> colors.css 'background-color', v
    .on 'tool:color', (_, v) -> colors.input.val v
    .on 'tool:kind',  (_, v) ->
      index = area.tools.indexOf v
      eitem = tools.find "[data-tool='#{index}']"
      entry = eitem.parent()

      entry.addClass "active" unless entry.hasClass "active"
      entry.siblings().removeClass "active"
      $('.tool-display').html(v.name)

    .on 'layer:add', (_, layer) ->
      entry = $ '<li><a><i class="fa toggle fa-eye"></i> <i class="fa fa-times remove"></i> <span class="name"></span></a></li>'
      entry.find('.name').text layer.name
      entry.appendTo layers

    .on 'layer:set', (_, index) ->
      $('.layer-display').text area.layers[index].name
      layers.children().removeClass 'active'
      layers.children().eq(index).addClass 'active'

    .on 'layer:del',    (_, i)    -> layers.children().eq(i).remove()
    .on 'layer:move',   (_, i, d) -> layers.children().eq(i).insertAfter(layers.children().eq(i + d))
    .on 'layer:toggle', (_, i)    -> layers.children().eq(i).find('.toggle').toggleClass('fa-eye').toggleClass('fa-eye-slash')

  area.addLayer null
  area.setTool  area.tools[0], {}
