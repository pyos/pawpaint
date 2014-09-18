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
  a = sqrt(3) / 2 * (r - d)  # half the side of a equilateral triangle
  h = sqrt(3) / 2 * a        # half its height

  CanvasSelector r * 2, r * 2, {H: area.tool.options.H, S: area.tool.options.S, L: area.tool.options.L},
    (x, y) ->
      if pow(r - d + inner, 2) <= pow(x - r, 2) + pow(y - r, 2)
        H: floor(atan2(y - r, x - r) * 180 / PI), S: @value.S, L: @value.L
      else
        m = -@value.H * PI / 180
        # Coordinates relative to the black corner of a triangle:
        p = (x - r) * cos(m) - (y - r) * sin(m) + h * 2 / 3
        q = (x - r) * sin(m) + (y - r) * cos(m) + a
        s = p / 2 / h / (1 - abs(q - a) / a)
        H: @value.H, S: floor(min(1, max(0, s)) * 100), L: floor(min(1, max(0, q / 2 / a)) * 100)

    (ctx) ->
      if @_hue is undefined
        for i in [0...10]
          s_a = i * PI / 5
          e_a = 1 * PI / 5 + s_a + 0.01  # some overlap to avoid gaps
          grad = ctx.fillStyle = ctx.createLinearGradient(r + r * cos(s_a), r + r * sin(s_a), r + r * cos(e_a), r + r * sin(e_a))
          grad.addColorStop 0, "hsl(#{i * 36},      100%, 50%)"
          grad.addColorStop 1, "hsl(#{i * 36 + 36}, 100%, 50%)"
          ctx.beginPath()
          ctx.arc(r, r, r - outer,     s_a, e_a, false)
          ctx.arc(r, r, r + inner - d, e_a, s_a, true)
          ctx.fill()

      if @_hue != @value.H
        ctx.beginPath()
        ctx.arc(r, r, r - d, 0, PI * 2, false)
        ctx.clip()
        ctx.clearRect(0, 0, r * 2, r * 2)

        ctx.save()
        ctx.translate(r, r)
        ctx.rotate(@value.H * PI / 180)
        ctx.translate(-h * 2 / 3, 0)
        ctx.beginPath()
        ctx.moveTo(0, -a)
        ctx.lineTo(0, +a)
        ctx.lineTo(h * 2, 0)

        grad = ctx.fillStyle = ctx.createLinearGradient(0, -a / 2, h * 2, 0)
        grad.addColorStop 0, "#000"
        grad.addColorStop 1, "hsl(#{@value.H}, 100%, 50%)"
        ctx.fill()

        grad = ctx.fillStyle = ctx.createLinearGradient(0, +a, h * 0.8, -a / 2 * 0.8)
        grad.addColorStop 0, "rgba(255, 255, 255, 1)"
        grad.addColorStop 1, "rgba(255, 255, 255, 0)"
        ctx.fill()
        ctx.restore()
        @_hue = @value.H


SizeSlider = (area, height, width, low, high, overshoot = 0) ->
  CanvasSelector width, height, area.tool.options.size,
    (x, y) -> min(high, max(low, floor(((overshoot - y) / (height - 2 * overshoot) + 1) * high + low)))
    (ctx) ->
      ctx.clearRect(0, 0, width, height)

      ctx.fillStyle = "rgba(127, 127, 127, 0.4)"
      ctx.beginPath()
      ctx.arc(width / 2, height / 2, @value / 2, 0, PI * 2, true)
      ctx.fill()

      y = (high - @value - low) / high * (height - 2 * overshoot) + overshoot
      ctx.lineWidth = 2
      ctx.strokeStyle = "rgba(127, 127, 127, 0.7)"
      ctx.beginPath()
      ctx.moveTo 0, y
      ctx.lineTo width, y
      ctx.stroke()


window.Canvas or= {}
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

    width.on 'change', (_, value) -> area.setToolOptions(size: value)
    color.on 'change', (_, value) -> area.setToolOptions(value)
    cover