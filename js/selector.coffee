---
---

# A Canvas-based configuration widget.
#
# Selector :: Canvas.Area int int -> Canvas.Selector
#
class Selector
  constructor: (area, @width, @height) ->
    @area  = area
    @onMouseDown = @onMouseDown .bind @
    @onMouseMove = @onMouseMove .bind @
    @onMouseUp   = @onMouseUp   .bind @

    @element = new Canvas(@width, @height)
    @element.on 'click', (ev) -> ev.stopPropagation()
    @element.on 'mousedown', @onMouseDown
    @redraw true, @element[0].getContext '2d'

  onMouseMove: (ev) ->
    if @update(ev.offsetX || ev.layerX, ev.offsetY || ev.layerY)
      @redraw false, @element[0].getContext '2d'
      @element.trigger 'change', [@value]

  onMouseDown: (ev) ->
    if ev.button == 0
      ev.preventDefault()
      @element[0].addEventListener 'mousemove',  @onMouseMove
      @element[0].addEventListener 'mouseup',    @onMouseUp
      @element[0].addEventListener 'mouseleave', @onMouseUp
      @onMouseMove ev

  onMouseUp: (ev) ->
    @onMouseMove ev
    @element[0].removeEventListener 'mousemove',  @onMouseMove
    @element[0].removeEventListener 'mouseup',    @onMouseUp
    @element[0].removeEventListener 'mouseleave', @onMouseUp

  # Abstract methods:
  #   * `redraw` must paint with `context`. `initial` is true iff this is the first time.
  #   * `update` must set `@value` to a new value based on the click coordinates
  #     and return `true`, or do nothing and return `false`.
  redraw: (initial, context) ->
  update: (x, y) ->


# A HSL color wheel, i.e. a hue circle around a triangle in which one vertice is white,
# one is black, and one is colored.
#
#   radius    :: int -- outer radius of the hue circle (in px)
#   thickness :: int -- you-know-what of the hue circle
#   margin    :: int -- amount of pixels between the circle and the triangle
#
# ColorSelector :: Canvas.Area int int int -> Canvas.Selector
#
class ColorSelector extends Selector
  constructor: (area, radius, thickness, margin) ->
    @value = H: area.tool.options.H, S: area.tool.options.S, L: area.tool.options.L
    @outerR = radius
    @innerR = radius - thickness
    @triagR = radius - thickness - margin
    @triagA = sqrt(3) * @triagR
    @triagH = sqrt(3) * @triagA / 2
    super area, radius * 2, radius * 2

  update: (x, y) ->
    x -= @outerR
    y -= @outerR

    if pow(@innerR, 2) <= pow(x, 2) + pow(y, 2)
      # Got a click inside the ring.
      @value.H = floor(atan2(y, x) * 180 / PI)
    else
      a = -@value.H * PI / 180
      dx = x * cos(a) - y * sin(a) + @triagH / 3
      dy = x * sin(a) + y * cos(a) + @triagA / 2
      @value.S = floor 100 * min 1, max 0, dx / @triagH / (1 - abs(dy * 2 / @triagA - 1))
      @value.L = floor 100 * min 1, max 0, dy / @triagA
    return true

  redraw: (initial, ctx) ->
    ctx.save()
    ctx.translate(@outerR, @outerR)

    if initial
      ctx.save()
      steps = 10
      delta = 2 * PI / steps

      for i in [0...steps]
        grad = ctx.fillStyle = ctx.createLinearGradient(@outerR, 0, @outerR * cos(delta), @outerR * sin(delta))
        grad.addColorStop 0, "hsl(#{i * 36},      100%, 50%)"
        grad.addColorStop 1, "hsl(#{i * 36 + 36}, 100%, 50%)"
        ctx.beginPath()
        ctx.arc(0, 0, @outerR, 0, delta, false)
        ctx.arc(0, 0, @innerR, delta, 0, true)
        ctx.fill()
        ctx.rotate(delta)
      ctx.restore()

    ctx.beginPath()
    ctx.arc(0, 0, @triagR, 0, PI * 2, false)
    ctx.clip()
    ctx.clearRect(-@triagR, -@triagR, @triagR * 2, @triagR * 2)

    ctx.rotate(@value.H * PI / 180)
    ctx.translate(-@triagH / 3, 0)
    ctx.beginPath()
    ctx.moveTo(0, -@triagA / 2)
    ctx.lineTo(0, +@triagA / 2)
    ctx.lineTo(@triagH, 0)
    ctx.closePath()

    grad = ctx.fillStyle = ctx.createLinearGradient(0, -@triagA / 4, @triagH, 0)
    grad.addColorStop 0, "#000"
    grad.addColorStop 1, "hsl(#{@value.H}, 100%, 50%)"
    ctx.fill()

    grad = ctx.fillStyle = ctx.createLinearGradient(0, +@triagA / 2, @triagH / 2, -@triagA / 4)
    grad.addColorStop 0, "rgba(255, 255, 255, 1)"
    grad.addColorStop 1, "rgba(255, 255, 255, 0)"
    ctx.fill()
    ctx.restore()


# A vertical bar that changes the size of a pen or whatever.
# The approximate shape of the result is also displayed inside the bar.
#
#   width  :: int
#   height :: int
#   low    :: int -- (must not be 0)
#   high   :: int -- limits on the size of the tool
#   margin :: int -- distance between the end positions and the actual border of the element
#
# WidthSelector :: Canvas.Area int int int int int -> Canvas.Selector
#
class WidthSelector extends Selector
  constructor: (area, width, height, low, high, margin) ->
    @value = area.tool.options.size
    @low    = low     # min. value
    @high   = high    # max. value
    @margin = margin  # spacing between the element's edge and the limits
    super area, width, height

  update: (x, y) ->
    @value = floor max(0, min(1, (@height - y - @margin) / (@height - 2 * @margin))) * (@high - @low) + @low

  redraw: (i, c) ->
    c.lineWidth = 2
    c.fillStyle   = "rgba(127, 127, 127, 0.4)"
    c.strokeStyle = "rgba(127, 127, 127, 0.7)"
    c.clearRect 0, 0, @width, @height

    c.beginPath()
    c.arc @width / 2, @height / 2, @value / 2, 0, PI * 2, false
    c.fill()

    y = (@high - @value) * (@height - 2 * @margin) / (@high - @low) + @margin
    c.beginPath()
    c.moveTo 0, y
    c.lineTo @width, y
    c.stroke()


# A list of all available tools.
#
# ToolSelector :: Canvas.Area int int int -> Canvas.Selector
#
class ToolSelector extends Selector
  constructor: (area, height, cellSize) ->
    @value = area.tools.indexOf area.tool.constructor
    @cellS = cellSize
    @cellY = floor(height / cellSize)
    @cellX = ceil(area.tools.length / @cellY)
    super area, @cellX * cellSize, @cellY * cellSize

  update: (x, y) ->
    index = floor(x / @cellS) * @cellY + floor(y / @cellS)
    @value = @area.tools[index] if index < @area.tools.length

  redraw: (i, c) ->
    c.clearRect 0, 0, @width, @height

    for i, tool of @area.tools
      x = (floor(i / @cellY) + 0.5) * @cellS
      y = (floor(i % @cellY) + 0.5) * @cellS

      c.strokeStyle = c.fillStyle = "rgba(127, 127, 127, 0.3)"
      c.strokeRect x - @cellS / 2 - 1, y - @cellS / 2 - 1, @cellS + 1, @cellS + 1
      c.fillRect   x - @cellS / 2 - 1, y - @cellS / 2 - 1, @cellS + 1, @cellS + 1 \
        if tool is @area.tool.constructor

      t = new tool({size: @cellS * 9 / 20, H: 0, S: 0, L: 80, opacity: 0.75})
      t.symbol c, x, y


# Everything crammed together into a single element floating at a given position.
#
# For styling, use the following classes::
#   * `canvas-selector-container` is a big window covering elements that should be inaccessible.
#   * `canvas-selector` contains all the selectors.
#   * `canvas-selector-<x>` is an `<x>Selector` (lowercase).
#
# Selector :: Canvas.Area int int (Optional bool) (Optional int) -> jQuery
#
@Canvas.Selector = (area, x, y, fixed = false, size = 100) ->
  return $ [] unless area.tool
  color = new ColorSelector(area, size, size / 4, size / 10)
  width = new WidthSelector(area, size / 2.5, size * 2, 1, size, size / 10)
  tools = new ToolSelector(area, size * 2, size / 2)
  cover = Canvas.Selector.modal(fixed, x, y, size,
    $ "<div class='canvas-selector'>"
      .append color.element.addClass 'canvas-selector-color'
      .append width.element.addClass 'canvas-selector-width'
      .append tools.element.addClass 'canvas-selector-tool')

  tools.element.on 'change', (_, value) -> area.setTool(value, area.tool.options)
  width.element.on 'change', (_, value) -> area.setToolOptions(size: value)
  color.element.on 'change', (_, value) -> area.setToolOptions(value)
  cover


# Wrap a node in a transparent page cover that dismisses itself on click.
#
# Selector.modal :: bool jQuery -> jQuery
#
@Canvas.Selector.modal = (fixed, x, y, size, node) ->
  node
    .css 'left', x - (if fixed then 0 else size)
    .css 'top',  y - (if fixed then 0 else size)

  cover = $ '<div class="canvas-selector-container">'
    .on 'click', -> cover.fadeOut(100, cover.remove.bind cover)
    .append node
    .appendTo 'body'
    .hide().fadeIn(100)
  cover.addClass 'canvas-selector-fixed' if fixed


# A button that displays the name of the current tool and its
# color, and opens a complete selector on click.
#
# Selector.Button :: Canvas.Area -> Canvas.Selector
#
class SelectorButton
  constructor: (area, @width, @height, @target = null) ->
    @element = new Canvas(@width, @height)
    @element.addClass 'tool-name'
    @element.on 'click', (ev) =>
      if ev.which == 1
        Canvas.Selector @area, @element.offset().left, @element.offset().top, true

    @area = area
    @area.element.on 'tool:kind tool:H tool:S tool:L', @update
    @update() if @area.tool

  update: =>
    lv  = if @area.tool.options.L > 50 then 0 else 100
    w   = @element[0].width
    h   = @element[0].height
    ctx = @element[0].getContext('2d')
    ctx.clearRect 0, 0, w, h

    tool = new @area.tool.constructor({size: min(w, h) * 15 / 20, H: 0, S: 0, L: lv})
    tool.symbol ctx, @element[0].width / 2, @element[0].height / 2

    target = @target || @element
    target.css 'background', "hsl(#{@area.tool.options.H},#{@area.tool.options.S}%,#{@area.tool.options.L}%)"
          .css 'color', if lv == 100 then "white" else "black"


# ...
#
# Selector.ExportButton :: Canvas.Area -> Canvas.Selector
#
class ExportButton
  constructor: (area) ->
    @element = $ '<a class="export-button">'
    @element.on 'click', (e) =>
      if e.which == 1
        new Canvas.Selector.Export area, @element.offset().left, @element.offset().top, true


# ...
#
# Selector.DynamicsButton :: Canvas.Area -> Canvas.Selector
#
class DynamicsButton
  constructor: (area) ->
    @element = $ '<a class="dynamics-button">'
    @element.on 'click', (e) =>
      if e.which == 1
        new Canvas.Selector.Dynamics area, @element.offset().left, @element.offset().top, true


# ...
#
# Selector.Export :: Canvas.Area int int bool -> Canvas.Selector
#
@Canvas.Selector.Export = (area, x, y, fixed) ->
  node = $ "<ul>"
  node.append '<li class="export-selector-header"></li>'
  node.append '<li><a data-type="png">PNG</a> <span class="text-muted">(Flattened)</span></li>'
  node.append '<li><a data-type="svg">SVG+PNG</a> <span class="text-muted">(Layered)</span></li>'
  node.on 'click', 'a[data-type]', (ev) ->
    type = $(this).attr 'data-type'
    link = document.createElement 'a'
    link.download = 'image.' + type
    link.href     = area.saveAll(type)
    link.click()

  root = $ "<div class='export-selector'>"
  root.append node
  root.append $(Canvas.getResource('export-warning')).clone()
  Canvas.Selector.modal(fixed, x, y, 0, root)


# ...
#
# Selector.Dynamics :: Canvas.Area int int bool -> Canvas.Selector
#
@Canvas.Selector.Dynamics = (area, x, y, fixed) ->
  opts =
    size:
      source: 'size'
      target: 'lineWidth'
      name:   "Size"
      min: 0.01, max: 2.01, a: 0.01, k: 1

    opacity:
      source: 'opacity'
      target: 'globalAlpha'
      name:   "Opacity"
      min: 0, max: 2, a: 1, k: -1

    rotation:
      tgcopy: 'rotation'
      name:   "Rotation"
      min: 0, max: 2 * PI, a: 0, k: 2 * PI

  funcs =
    none:
      fn:   -> -> 1
      name: "Disabled"

    average:
      fn:   Canvas.Dynamic.movingAverage
      name: "Moving average"

    linear:
      fn:   Canvas.Dynamic.linear
      name: "Current value"

    random:
      fn:   Canvas.Dynamic.random
      name: "Random"

  types =
    velocity:
      value: Canvas.Dynamic.prototype.VELOCITY
      name:  "Velocity"

    pressure:
      value: Canvas.Dynamic.prototype.PRESSURE
      name:  "Pressure"

    rotation:
      value: Canvas.Dynamic.prototype.ROTATION
      name:  "Rotation"

  withItem = (elem, cb) ->
    val = $(elem).val()
    par = $(elem).parents('.dynamics-selector-item')
    dyn = par.data('dynamic')

    if not dyn and par.find('.dynamics-selector-comp').val() != 'none'
      dyn = new Canvas.Dynamic.Option(par.data 'options')
      dyn.options.kind = par.attr('data-option')
      dyn.options.type = types[par.find('.dynamics-selector-type').val()].value
      dyn.options.fn   = funcs[par.find('.dynamics-selector-comp').val()].fn
      dyn.options.a    = parseFloat(par.find('.dynamics-selector-a').val())
      dyn.options.k    = parseFloat(par.find('.dynamics-selector-k').val()) - dyn.options.a
      updateItem par, dyn
      area.tool.options.dynamic.push(dyn)

    cb val, par, dyn if dyn

  updateItem = (elem, dyn) ->
    comp = elem.find '.dynamics-selector-comp'
    type = elem.find '.dynamics-selector-type'

    for c, f of funcs then comp.val c if f.fn     is dyn.options.fn
    for t, f of types then type.val t if f.value  is dyn.options.type
    elem.find('.dynamics-selector-a').val(dyn.options.a)
    elem.find('.dynamics-selector-k').val(dyn.options.k + dyn.options.a)
    elem.data 'dynamic', dyn

  node = $ '<div class="dynamics-selector">'
  item = $ '<div class="dynamics-selector-item">'
    .append '<div class="dynamics-selector-name">&nbsp;</div>'
    .append '<div class="dynamics-selector-comp-label">'
    .append '<div class="dynamics-selector-type-label">'
    .append '<div class="dynamics-selector-a-label">'
    .append '<div class="dynamics-selector-k-label">'
    .append '<datalist id="dynamics-selector-range-list">'
    .appendTo node

  for o, x of opts
    comp = $ '<select class="dynamics-selector-comp">'
    comp.append "<option value='#{k}'>#{v.name}</option>" for k, v of funcs

    type = $ '<select class="dynamics-selector-type">'
    type.append "<option value='#{k}'>#{v.name}</option>" for k, v of types

    item = $ "<div class='dynamics-selector-item' data-option='#{o}'>"
      .data 'options', x
      .append "<div class='dynamics-selector-name'>#{x.name}</div>"
      .append comp
      .append type
      .append "<input class='dynamics-selector-a' type='range' step='0.05'>"
      .append "<input class='dynamics-selector-k' type='range' step='0.05'>"
      .append "<div class='dynamics-selector"
      .appendTo node

    item.find('.dynamics-selector-a').attr(min: x.min, max: x.max, value: x.a)
    item.find('.dynamics-selector-k').attr(min: x.min, max: x.max, value: x.k + x.a)

  node
    .on 'change', '.dynamics-selector-comp', ->
      withItem this, (val, par, dyn) ->
        if val is 'none'
          i = area.tool.options.dynamic.indexOf(dyn)
          _ = area.tool.options.dynamic.splice(i, 1)
          par.data 'dynamic', null
        else
          dyn.options.fn = funcs[val].fn

    .on 'change', '.dynamics-selector-type', ->
      withItem this, (val, par, dyn) ->
        dyn.options.type = types[val].value

    .on 'change', '.dynamics-selector-a', ->
      withItem this, (val, par, dyn) ->
        dyn.options.k += dyn.options.a
        dyn.options.a  = parseFloat val
        dyn.options.k -= dyn.options.a

    .on 'change', '.dynamics-selector-k', ->
      withItem this, (val, par, dyn) ->
        dyn.options.k = parseFloat val - dyn.options.a

    .on 'click', (ev) -> ev.stopPropagation()

  for dyn in area.tool.options.dynamic
    elem = node.find("[data-option='#{dyn.options.kind}']")
    elem.each -> updateItem $(this), dyn

  Canvas.Selector.modal(fixed, x, y, 0, node)

# ...
#
# Selector.Layers :: Canvas.Area -> Canvas.Selector
#
class LayerSelector
  constructor: (area) ->
    @element = $ '<ul class="layer-menu">'
    @element
      .on 'click', '.layer-add',        (ev) -> area.addLayer()
      .on 'click', '.layer-del',        (ev) -> area.delLayer    $(this).parents('.layer-menu-entry').index()
      .on 'click', '.layer-toggle',     (ev) -> area.toggleLayer $(this).parents('.layer-menu-entry').index()
      .on 'click', '.layer-menu-entry', (ev) -> area.setLayer $(this).index()

    @end = $ '<li class="layer-menu-control">'
      .append '<a class="layer-add fa fa-plus">'
      .appendTo @element

    @area = area
    @area.element
      .on 'layer:add',    @add
      .on 'layer:set',    @set
      .on 'layer:del',    @del
      .on 'layer:move',   @move
      .on 'layer:toggle', @toggle
      .on 'stroke:end refresh', @update

    @add null, layer for layer in area.layers
    @set null, area.layer

  add: (_, elem) =>
    sz = 150 / max(elem[0].width, elem[0].height)

    entry = $ '<li class="layer-menu-entry background">'
      .append new Canvas elem[0].width * sz, elem[0].height * sz
      .append '<a class="layer-del fa fa-trash">'
      .append '<a class="layer-toggle fa fa-toggle-on">'
      .append '<a class="layer-config fa fa-adjust">'
      .insertBefore @end
    entry.addClass 'layer-hidden' if elem.css('display') == 'none'

  update: (_, canvas, index) =>
    cnv = @element.children().eq(index).find('canvas')
    cnv.each ->
      ctx = @getContext('2d')
      ctx.clearRect         0, 0, @width, @height
      ctx.drawImage canvas, 0, 0, @width, @height

  set:    (_, index)    => @element.children().removeClass('active').eq(index).addClass('active')
  del:    (_, index)    => @element.children().eq(index).remove()
  move:   (_, index, d) => @element.children().eq(index).insertAfter @element.children().eq(index + d)
  toggle: (_, index)    => @element.children().eq(index).toggleClass('layer-hidden')


@Canvas.Selector.Tool   = ToolSelector
@Canvas.Selector.Color  = ColorSelector
@Canvas.Selector.Width  = WidthSelector
@Canvas.Selector.Button = SelectorButton
@Canvas.Selector.Layers = LayerSelector
@Canvas.Selector.ExportButton = ExportButton
@Canvas.Selector.DynamicsButton = DynamicsButton
