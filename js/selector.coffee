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
    @update ev.offsetX, ev.offsetY
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


class ColorSelector extends Selector
  constructor: (area, radius, thickness, margin) ->
    @value = H: area.tool.options.H, S: area.tool.options.S, L: area.tool.options.L
    #  1. outer radius of the hue selector
    #  2. inner radius of the hue selector
    #  3. radius of the saturation/lightness selector
    #  4. length of the selector's side
    #  5. and its height
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


class ToolSelector
  constructor: (area) ->
    @value = area.tools.indexOf area.tool.__proto__.constructor

    @element = el = $ '<ul class="canvas-selector-tool">'
    @element.on 'click', 'li', (ev) ->
      if ev.button == 0
        ev.stopPropagation()
        el.trigger 'change', [area.tools[@value = $(this).index()]]
        el.children().removeClass('active').eq(@value).addClass('active')

    @element.append("<li><a>#{t.name}</a></li>") for t in area.tools
    @element.children().eq(@value).addClass('active')


@Canvas.Selector = (area, x, y, size = 100, fixed = false) ->
  color = new ColorSelector(area, size, size / 4, size / 10)
  width = new WidthSelector(area, size / 2.5, size * 2, 1, size, size / 10)
  tools = new ToolSelector(area)

  cover = $ '<div class="canvas-selector-container">'
    .on 'click', -> cover.fadeOut(100, cover.remove.bind cover)
    .appendTo 'body'
    .append(
      $ "<div class='canvas-selector'>"
        .css 'left', x - (if fixed then 0 else size)
        .css 'top',  y - (if fixed then 0 else size)
        .append color.element.addClass 'canvas-selector-color'
        .append width.element.addClass 'canvas-selector-size'
        .append tools.element.addClass 'canvas-selector-tools')
    .hide().fadeIn(100)
  cover.addClass 'canvas-selector-fixed' if fixed

  tools.element.on 'change', (_, value) -> area.setTool(value, area.tool.options)
  width.element.on 'change', (_, value) -> area.setToolOptions(size: value)
  color.element.on 'change', (_, value) -> area.setToolOptions(value)
  cover
