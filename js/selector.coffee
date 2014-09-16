window.Canvas or= {}
window.Canvas.HSLtoRGB = HSLtoRGB = (h, s, l) ->
  if s == 0
    r = g = b = l
  else
    h += 360 while h < 0
    H = h % 360 / 60
    C = (1 - Math.abs(l * 2 - 1)) * s
    X = (1 - Math.abs(H % 2 - 1)) * C

    R = [C, X, 0, 0, X, C][Math.floor(H)]
    G = [X, C, C, X, 0, 0][Math.floor(H)]
    B = [0, 0, X, C, C, X][Math.floor(H)]
    m = l - C / 2
    r = R + m
    g = G + m
    b = B + m
  r = Math.round(r * 255)
  g = Math.round(g * 255)
  b = Math.round(b * 255)
  "##{(r + 0x100).toString(16).substr(-2)}#{(g + 0x100).toString(16).substr(-2)}#{(b + 0x100).toString(16).substr(-2)}"


window.Canvas.RGBtoHSL = RGBtoHSL = (hex) ->
  r = parseInt(hex.substr(1, 2), 16) / 255
  g = parseInt(hex.substr(3, 2), 16) / 255
  b = parseInt(hex.substr(5, 2), 16) / 255

  M = Math.max(r, g, b)
  m = Math.min(r, g, b)
  l = (M + m) / 2

  if M == m
    h = s = 0
  else
    d = M - m
    s = if l > 0.5 then d / (2 - M - m) else d / (M + m)

    h = switch M
      when r then (g - b) / d + (if g < b then 6 else 0)
      when g then (b - r) / d + 2
      when b then (r - g) / d + 4
    h /= 6
  return [h * 360, s, l]


CanvasSelector = (w, h, init, valueAt, redraw) ->
  canvas = $ "<canvas width='#{w}' height='#{h}'>"
  canvas.tracking = false

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
    redraw.apply canvas, [canvas[0].getContext('2d')]

  canvas.update = (value) ->
    canvas.value = value
    redraw.apply canvas, [canvas[0].getContext('2d')]
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

  CanvasSelector(r * 2, r * 2, RGBtoHSL(area.tool.options.color),
    (x, y) ->
      if Math.pow(r - d + inner, 2) <= Math.pow(x - r, 2) + Math.pow(y - r, 2)
        [Math.floor(Math.atan2(y - r, x - r) * 180 / Math.PI), @value[1], @value[2]]
      else
        getHSL @value[0], x, y

    (ctx) ->
      ctx.clearRect 0, 0, r * 2, r * 2
      ctx.save()
      ctx.translate(r, r)
      ctx.rotate(@value[0] * Math.PI / 180)
      ctx.translate(-h * 2/3, 0)
      for y in [-a * 2..a * 2]
        x = 2 * h * (1 - Math.abs(y / 2) / a)
        p = Math.round(y * 25 / a + 50)

        grad = ctx.strokeStyle = ctx.createLinearGradient 0, 0, x, 0
        grad.addColorStop 0, "hsl(#{@value[0]},   0%, #{p}%)"
        grad.addColorStop 1, "hsl(#{@value[0]}, 100%, #{p}%)"
        ctx.beginPath()
        ctx.moveTo(0, y / 2)
        ctx.lineTo(x, y / 2)
        ctx.stroke()

      # Display the current color, too.
      y = @value[2] * a * 2 - a
      x = @value[1] * 2 * h * (1 - Math.abs(y) / a)
      ctx.lineWidth = 2
      ctx.fillStyle = "#444"
      ctx.strokeStyle = "#aaa"
      ctx.beginPath()
      ctx.arc(x, y, 5, 0, Math.PI * 2, false)
      ctx.stroke()
      ctx.fill()
      ctx.restore()

      for i in [0...1800]
        q = i * Math.PI / 900
        x = r + r * Math.cos(a)
        y = r + r * Math.sin(a)
        ctx.strokeStyle = "hsl(#{i / 5}, 100%, 50%)"
        ctx.beginPath()
        ctx.moveTo(r + (r + inner - d) * Math.cos(q), r + (r + inner - d) * Math.sin(q))
        ctx.lineTo(r + (r - outer)     * Math.cos(q), r + (r - outer)     * Math.sin(q))
        ctx.stroke()
  )


SizeSlider = (area, height, width, min, max, overshoot = 0) ->
  CanvasSelector(width, height, area.tool.options.size,
    (x, y) -> max - Math.round(Math.min(max, Math.max(min, ((y - overshoot) / (height - 2 * overshoot)) * max + min)))
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
  )


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

    tools.children().eq(area.tools.indexOf area.tool.kind).addClass('active')

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