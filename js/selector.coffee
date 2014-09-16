max = Math.max
min = Math.min
abs = Math.abs
cos = Math.cos
sin = Math.sin
pi  = Math.PI


window.Canvas or= {}
window.Canvas.HSLtoRGB = HSLtoRGB = (h, s, l) ->
  H = (h + 360) % 360 / 60
  C = (1 - Math.abs(l * 2 - 1)) * s
  X = (1 - Math.abs(H % 2 - 1)) * C
  R = [C, X, 0, 0, X, C][Math.floor(H)]
  G = [X, C, C, X, 0, 0][Math.floor(H)]
  B = [0, 0, X, C, C, X][Math.floor(H)]
  m = l - C / 2
  r = Math.round((R + m) * 255 + 256).toString(16).substr(-2)
  g = Math.round((G + m) * 255 + 256).toString(16).substr(-2)
  b = Math.round((B + m) * 255 + 256).toString(16).substr(-2)
  "##{r}#{g}#{b}"


window.Canvas.RGBtoHSL = RGBtoHSL = (hex) ->
  r = parseInt(hex.substr(1, 2), 16) / 255
  g = parseInt(hex.substr(3, 2), 16) / 255
  b = parseInt(hex.substr(5, 2), 16) / 255

  M = max(r, g, b)
  m = min(r, g, b)
  l = (M + m) / 2
  d = (M - m)

  return [0, 0, l] if d == 0
  s = if l > 0.5 then d / (2 - M - m) else d / (M + m)
  h = switch M
    when r then (g - b) / d + (if g < b then 6 else 0)
    when g then (b - r) / d + 2
    when b then (r - g) / d + 4
  return [h * 60, s, l]


CanvasSelector = (w, h, init, valueAt, redraw) ->
  canvas = $ "<canvas width='#{w}' height='#{h}'>"
  canvas.tracking = false
  canvas.context = canvas[0].getContext '2d'

  canvas.on 'mousedown', (ev) ->
    if ev.button == 0
      canvas.tracking = true
      canvas.emit ev.offsetX, ev.offsetY

  canvas.on 'mousemove', (ev) ->
    if canvas.tracking
      canvas.emit ev.offsetX, ev.offsetY

  canvas.on 'mouseup', (ev) ->
    if canvas.tracking
      canvas.emit ev.offsetX, ev.offsetY
      canvas.tracking = false

  canvas.on 'mouseleave', (ev) ->
    if canvas.tracking
      canvas.emit ev.offsetX, ev.offsetY
      canvas.tracking = false

  canvas.on 'click', (ev) ->
    ev.stopPropagation()

  canvas.emit = (x, y) ->
    canvas.value = valueAt.apply canvas, [x, y]
    canvas.trigger 'change', [canvas.value]
    redraw.apply canvas, [canvas.context]

  canvas.update = (value) ->
    canvas.value = value
    redraw.apply canvas, [canvas.context]
    canvas

  canvas.update init


HueRing = (area, r, d, inner, outer) ->
  a = (r - d) * Math.sqrt(3) / 2
  h = a * Math.sqrt(3) / 2

  getHSL = (H, x, y) ->
    m = -H * Math.PI / 180
    p = (x - r) * Math.cos(m) - (y - r) * Math.sin(m) + h * 2 / 3
    q = (x - r) * Math.sin(m) + (y - r) * Math.cos(m) + a
    s = p / 2 / h / (1 - Math.abs(q - a) / a)
    [H, Math.min(1, Math.max(0, s)), Math.min(1, Math.max(0, q / 2 / a))]

  CanvasSelector r * 2, r * 2, RGBtoHSL(area.tool.options.color),
    (x, y) ->
      if Math.pow(r - d + inner, 2) <= Math.pow(x - r, 2) + Math.pow(y - r, 2)
        [Math.floor(Math.atan2(y - r, x - r) * 180 / Math.PI), @value[1], @value[2]]
      else
        getHSL @value[0], x, y

    (ctx) ->
      if @_hue is undefined
        for i in [0...10]
          s_a = i * pi / 5
          e_a = 1 * pi / 5 + s_a + 0.01  # some overlap to avoid gaps
          grad = ctx.fillStyle = ctx.createLinearGradient(r + r * cos(s_a), r + r * sin(s_a), r + r * cos(e_a), r + r * sin(e_a))
          grad.addColorStop 0, "hsl(#{i * 36},      100%, 50%)"
          grad.addColorStop 1, "hsl(#{i * 36 + 36}, 100%, 50%)"
          ctx.beginPath()
          ctx.arc(r, r, r - outer,     s_a, e_a, false)
          ctx.arc(r, r, r + inner - d, e_a, s_a, true)
          ctx.fill()

      if @_hue != @value[0]
        ctx.beginPath()
        ctx.arc(r, r, r - d, 0, pi * 2, false)
        ctx.clip()
        ctx.clearRect(0, 0, r * 2, r * 2)

        ctx.save()
        ctx.translate(r, r)
        ctx.rotate(@value[0] * Math.PI / 180)
        ctx.translate(-h * 2 / 3, 0)
        ctx.beginPath()
        ctx.moveTo(0, -a)
        ctx.lineTo(0, +a)
        ctx.lineTo(h * 2, 0)

        grad = ctx.fillStyle = ctx.createLinearGradient(0, -a / 2, h * 2, 0)
        grad.addColorStop 0, "#000"
        grad.addColorStop 1, "hsl(#{@value[0]}, 100%, 50%)"
        ctx.fill()

        grad = ctx.fillStyle = ctx.createLinearGradient(0, +a, h * 0.8, -a / 2 * 0.8)
        grad.addColorStop 0, "rgba(255, 255, 255, 1)"
        grad.addColorStop 1, "rgba(255, 255, 255, 0)"
        ctx.fill()
        ctx.restore()
        @_hue = @value[0]


SizeSlider = (area, height, width, min, max, overshoot = 0) ->
  CanvasSelector width, height, area.tool.options.size,
    (x, y) -> Math.min(max, Math.max(min, Math.round(((overshoot - y) / (height - 2 * overshoot) + 1) * max + min)))
    (ctx) ->
      ctx.clearRect(0, 0, width, height)

      ctx.fillStyle = "rgba(127, 127, 127, 0.4)"
      ctx.beginPath()
      ctx.arc(width / 2, height / 2, @value / 2, 0, Math.PI * 2, true)
      ctx.fill()

      y = ((max - @value) - min) / max * (height - 2 * overshoot) + overshoot
      ctx.lineWidth = 2
      ctx.strokeStyle = "rgba(127, 127, 127, 0.7)"
      ctx.beginPath()
      ctx.moveTo 0, y
      ctx.lineTo width, y
      ctx.stroke()


window.Canvas.Selector =
  show: (area, x, y, fixed = false) ->
    color = HueRing(area, 100, 30, 10, 1).addClass('canvas-selector-color')
    width = SizeSlider(area, 200, 40, 1, 100, 10).addClass('canvas-selector-size')

    tools = $ '<ul class="canvas-selector-tool">'
    tools.on 'click', 'a', ->
      tool = area.tools[$(this).parents('li').index()]
      area.setTool tool, area.tool.options

    for t in area.tools
      $("<li>").append($("<a>").text(t.name)).appendTo(tools)

    tools.children().eq(area.tools.indexOf area.tool.__proto__.constructor).addClass('active')

    cover = $ '<div class="canvas-selector-container">'
      .on 'click', -> $(this).fadeOut(100, $(this).remove.bind($(this)))
      .appendTo 'body'
      .append(
        $ '<div class="canvas-selector">'
          .css 'left', x - 100
          .css 'top',  y - 100
          .append color
          .append width
          .append tools)
      .hide().fadeIn(100)

    if fixed
      cover.addClass 'canvas-selector-fixed'

    width.on 'change', (_, value) -> area.setToolOptions(size:  value)
    color.on 'change', (_, value) -> area.setToolOptions(color: HSLtoRGB.apply(null, value))
    cover