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
    ok = Math.abs(ev.pageX - this.lastX) + Math.abs(ev.pageY - this.lastY) < 150
    if reset or ok
      this.lastX = ev.pageX
      this.lastY = ev.pageY
    reset or ok


class Tool
  name: "noop"

  constructor: (size, color, options) ->
    this.size    = size
    this.color   = color
    this.options = options

  crosshair: (ctx) ->
    ctx.lineWidth   = 1
    ctx.strokeStyle = "#777"
    ctx.stroke()

  setColor:   (color)   -> this.color   = color
  setSize:    (size)    -> this.size    = size
  setOptions: (options) -> this.options = jQuery.extend this.options options

  start: (ctx, x, y) ->
  move:  (ctx, x, y) ->
  stop:  (ctx, x, y) ->


class Pen extends Tool
  name: "pen"

  crosshair: (ctx, size, color, options) ->
    ctx.beginPath()
    ctx.arc(size / 2, size / 2, size / 2, 0, 2 * Math.PI, false)
    super ctx, size, color, options

  start: (ctx, x, y) ->
    ctx.lineCap     = "round"
    ctx.lineJoin    = "round"
    ctx.lineWidth   = this.size
    ctx.strokeStyle = this.color
    ctx.beginPath()
    ctx.moveTo x, y

  move: (ctx, x, y) ->
    ctx.lineTo x, y
    ctx.stroke()
    ctx.beginPath()
    ctx.moveTo x, y

  stop: (ctx, x, y) ->
    ctx.lineTo x, y
    ctx.stroke()


class Eraser extends Pen
  name: "eraser"

  start: (ctx, x, y) ->
    this._old_mode = ctx.globalCompositeOperation
    ctx.globalCompositeOperation = "destination-out"
    super ctx, x, y

  stop: (ctx, x, y) ->
    super ctx, x, y
    ctx.globalCompositeOperation = this._old_mode


class Layer
  constructor: (area, name) ->
    this.canvas = $ '<canvas class="layer">'
    this.canvasE = this.canvas[0]
    this.context = this.canvasE.getContext "2d"
    this.name    = name
    this.drawing = false


class Area
  defaults:
    layerName: "layer"
    toolColor: "#000000"
    toolSize:  15

  constructor: (selector, tools) ->
    this.element = $ selector
    this.element.css 'overflow', 'hidden'

    this.size      = this.element[0].getBoundingClientRect()
    this.tools     = tools
    this.crosshair = $ '<span>'
    this.layer     = 0
    this.layers    = []

  event: (name, layer) ->
    size    = this.size
    tool    = this.tool
    context = layer.context

    if name == "mousedown"
      (ev) =>
        ev.preventDefault()
        if ev.button == 0 and evdev.ok ev, true
          layer.drawing = true
          tool.start(context, ev.pageX - size.left, ev.pageY - size.top)
    else if name == "mousemove"
      (ev) =>
        this.crosshair
          .css 'left', ev.pageX - this.crosshair_left
          .css 'top',  ev.pageY - this.crosshair_top
        if layer.drawing and evdev.ok ev
          tool.move(context, ev.pageX - size.left, ev.pageY - size.top)
    else if name == "mouseup"
      (ev) =>
        if layer.drawing and evdev.ok ev
          layer.drawing = false
          tool.stop(context, ev.pageX - size.left, ev.pageY - size.top)

  addLayer: (name) ->
    layer = new Layer(this.element, name)
    layer.canvas.css 'z-index', this.layers.length
    layer.canvas.appendTo this.element
    layer.canvasE.setAttribute 'width',  this.element[0].offsetWidth
    layer.canvasE.setAttribute 'height', this.element[0].offsetHeight
    this.layers.push(layer)
    this.element.trigger 'addLayer', [layer]
    this.setLayer(this.layers.length - 1)
    this.redoLayout()

  setLayer: (i) ->
    if 0 <= i < this.layers.length
      this.layer = i
      this.element
        .off 'mousedown'
        .off 'mouseup'
        .off 'mouseleave'
        .off 'mousemove'
        .on 'mousedown',  this.event("mousedown", this.layers[this.layer])
        .on 'mouseup',    this.event("mouseup",   this.layers[this.layer])
        .on 'mouseleave', this.event("mouseup",   this.layers[this.layer])
        .on 'mousemove',  this.event("mousemove", this.layers[this.layer])
        .trigger 'setLayer', [i]

  delLayer: (i) ->
    if 0 <= i < this.layers.length
      layer = this.layers.splice(i, 1)[0]
      layer.canvas.remove()
      this.element.trigger 'delLayer', [i]
      this.addLayer this.defaults.layerName if not this.layers.length
      this.setLayer this.layer
      this.redoLayout()

  moveLayer: (i, delta) ->
    if 0 <= i < this.layers.length and 0 <= i + delta < this.layers.length
      this.layers.splice(i + delta, 0, this.layers.splice(i, 1)[0])
      this.element.trigger 'moveLayer', [i, delta]
      this.setLayer(i + delta)
      this.redoLayout()

  toggleLayer: (i) ->
    this.layers[i].canvas.toggle()
    this.element.trigger 'toggleLayer', [i]

  redoLayout: ->
    for i of this.layers
      this.layers[i].canvas.css 'z-index', i

  redoCrosshair: ->
    this.crosshair.remove()
    this.crosshair = $ '<canvas>'
    this.crosshair.appendTo this.element
    this.crosshair.css 'z-index', '65536'
    this.crosshair.css 'position', 'absolute'
    this.crosshair.attr 'width',  this.tool.size
    this.crosshair.attr 'height', this.tool.size
    this.crosshair_left = this.element[0].offsetLeft + this.tool.size / 2
    this.crosshair_top  = this.element[0].offsetTop  + this.tool.size / 2
    this.tool.kind.prototype.crosshair(
      this.crosshair[0].getContext('2d'),
      this.tool.size, this.tool.color, this.tool.options)

  setTool: (kind, size, color, options) ->
    this.tool = new kind(size, color, options)
    this.tool.kind = kind

    this.element.trigger 'changeTool'
    this.element.trigger 'changeSize'
    this.element.trigger 'changeColor'
    this.element.trigger 'changeOptions'
    this.redoCrosshair()
    this.setLayer(this.layer)

  setToolColor: (color) ->
    this.tool.setColor color
    this.element.trigger 'changeColor'
    this.redoCrosshair()

  setToolSize: (size) ->
    this.tool.setSize size
    this.element.trigger 'changeSize'
    this.redoCrosshair()

  setToolOptions: (options) ->
    this.tool.setOptions options
    this.element.trigger 'changeOptions'
    this.redoCrosshair()


$ ->
  area = window.area = new Area '.main-area', [Pen, Eraser]

  tools = $ '.tool-menu'
  tools.on 'click', '[data-tool]', ->
    tool = area.tools[parseInt $(this).attr('data-tool')]
    area.setTool tool, area.tool.size, area.tool.color, area.tool.options

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
  colors.input.on 'change', -> area.setToolColor this.value

  width = $ '.width-picker'
  width.input = $ '<input type="range" min="1" max="61" step="1">'
  width.input.appendTo width.html('')
  width.input.on 'change',     -> area.setToolSize parseInt(this.value)
  width.input.on 'click', (ev) -> ev.stopPropagation()

  layers = $ '.layer-menu'
  layers
    .on 'click', '.toggle', (ev) ->
      ev.preventDefault()
      ev.stopPropagation()
      area.toggleLayer $(this).parents('li').index()

    .on 'click', '.remove', (ev) ->
      ev.preventDefault()
      ev.stopPropagation()
      area.delLayer $(this).parents('li').index()

    .on 'click', 'li', (ev) ->
      ev.preventDefault()
      ev.stopPropagation()
      area.setLayer $(this).index()

  area.element
    .on 'changeSize',  -> width.input.val area.tool.size
    .on 'changeColor', -> colors.css 'background-color', area.tool.color
    .on 'changeColor', -> colors.input.val area.tool.color
    .on 'changeTool',  ->
      index = area.tools.indexOf area.tool.kind
      eitem = tools.find "[data-tool='#{index}']"
      entry = eitem.parent()

      entry.addClass "active" unless entry.hasClass "active"
      entry.siblings().removeClass "active"
      $('.tool-display').html(area.tool.kind.name)

    .on 'addLayer', (ev, layer) ->
      entry = $ '<li><a><i class="fa toggle fa-eye"></i> <i class="fa fa-times remove"></i> <span class="name"></span></a></li>'
      entry.find('.name').text layer.name
      entry.appendTo layers

    .on 'setLayer', (ev, index) ->
      $('.layer-display').text area.layers[index].name
      layers.children().removeClass 'active'
      layers.children().eq(index).addClass 'active'

    .on 'delLayer',    (ev, i)    -> layers.children().eq(i).remove()
    .on 'moveLayer',   (ev, i, d) -> layers.children().eq(i).insertAfter(layers.children().eq(i + d))
    .on 'toggleLayer', (ev, i)    -> layers.children().eq(i).find('.toggle').toggleClass('fa-eye').toggleClass('fa-eye-slash')

  area.addLayer area.defaults.layerName
  area.setTool  area.tools[0], area.defaults.toolSize, area.defaults.toolColor, {}
