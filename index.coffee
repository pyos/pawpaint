$ ->
  window._focused = true
  $(window).on 'focus', -> this._focused = true
  $(window).on 'blur',  -> this._focused = false

  _evdev =
    lastX: 0
    lastY: 0
    hack: (ev, reset) ->
      # evdev sometimes bugs out when using tablets.
      # To prevent the line from jumping, we'll ignore fast movements.
      ok = Math.abs(ev.pageX - this.lastX) + Math.abs(ev.pageY - this.lastY) < 150
      if reset or ok
        this.lastX = ev.pageX
        this.lastY = ev.pageY
      reset or ok

  tools =
    pen:    (ctx, path) -> ctx.stroke path
    eraser: (ctx, path) ->
      _composite = ctx.globalCompositeOperation
      ctx.globalCompositeOperation = "destination-out"
      ctx.stroke path
      ctx.globalCompositeOperation = _composite

  icons =
    pen:    "fa fa-paint-brush"
    eraser: "fa fa-eraser"

  defaults =
    layer: "background"
    style: "#000000"
    width: 1
    tool:  tools.pen

  state  = jQuery.extend {}, defaults
  canvas = $ '<canvas>'
  canvas.appendTo ".main-area"
  canvas = canvas[0]

  canvas._ctx   = canvas.getContext "2d"
  canvas._paths = { }
  canvas._paths[state.layer] = { paths: [], hidden: false }

  canvas.start = (ev) ->
    if window._focused and ev.button == 0
      this.drawing = true
      this._path = tool: state.tool, width: state.width, style: state.style, x: new Path2D()
      this._path.x.moveTo(ev.pageX - this.rect.left - 1, ev.pageY - this.rect.top)
      this._paths[state.layer].paths.push this._path
      this.draw(ev)

  canvas.finish = (ev) ->
    this.draw(ev)
    this.drawing = false
    # TODO optimize `this._path` to minimize drawing
    this.redraw()

  canvas.draw = (ev) ->
    x = ev.pageX - this.rect.left
    y = ev.pageY - this.rect.top
    this._path.x.lineTo(x, y)
    this.redraw (ctx) ->
      ctx.beginPath()
      ctx.rect(x - state.width, y - state.width, state.width * 2, state.width * 2)
      ctx.clip()

  canvas.draw_tool_circle = (ev) ->
    if this._crosshair
      lastX = this._crosshair.x
      lastY = this._crosshair.y
    if ev is null
      this._crosshair = undefined
    else
      x = ev.pageX - this.rect.left
      y = ev.pageY - this.rect.top
      this._crosshair = x: x, y: y

    this.redraw (ctx) =>
      ctx.beginPath()
      ctx.rect(lastX - state.width, lastY - state.width, state.width * 2, state.width * 2)
      if this._crosshair
        ctx.rect(x - state.width, y - state.width, state.width * 2, state.width * 2)
      ctx.clip()

  canvas.redraw = (clipf) ->
    ctx = this._ctx
    ctx.save()
    clipf ctx if clipf isnt undefined
    ctx.clearRect 0, 0, this.width, this.height

    for layer of this._paths
      if not this._paths[layer].hidden
        for path in this._paths[layer].paths
          ctx.lineCap     = "round"
          ctx.lineJoin    = "round"
          ctx.lineWidth   = path.width
          ctx.strokeStyle = path.style
          path.tool(ctx, path.x)

    if this._crosshair
      ctx.beginPath()
      ctx.arc this._crosshair.x, this._crosshair.y, state.width / 2, 0, 2 * Math.PI, false
      ctx.lineWidth   = 1
      ctx.strokeStyle = "#777"
      ctx.stroke()

    ctx.restore()

  body = $ "body"
  body.on 'resize', ->
    canvas.setAttribute 'width',  canvas.offsetWidth
    canvas.setAttribute 'height', canvas.offsetHeight
    canvas.rect = canvas.getBoundingClientRect()
    canvas.redraw()
  body.resize()

  body.on 'mousedown', "canvas", (ev) ->
    ev.preventDefault()
    _evdev.hack ev, true
    canvas.start(ev)

  body.on 'mousemove', (ev) ->
    canvas.draw(ev) if canvas.drawing and _evdev.hack ev

  body.on 'mouseup', (ev) ->
    canvas.finish(ev) if canvas.drawing

  body.on 'mouseleave', (ev) ->
    canvas.finish(ev) if self.drawing and _evdev.hack ev

  body.on 'mousemove', 'canvas', (ev) ->
    if state.width > 5
      canvas.draw_tool_circle(ev)

  body.on 'mouseleave', 'canvas', (ev) ->
    canvas.draw_tool_circle(null)

  $(".tool-menu").each ->
    for t of tools
      item = $ "<a data-tool='#{t}'>"
      item.append "<i class='#{icons[t]}'>"
      item.on 'click', ->
        state.tool = tools[$(this).attr("data-tool")]
        entry = $(this).parent()
        entry.addClass "active" unless entry.hasClass "active"
        entry.siblings().removeClass "active"
        $(".tool-display").html $(this).html()

      entry = $ "<li>"
      entry.append item
      entry.appendTo this
      item.click() if tools[t] == state.tool

  $(".color-picker").each ->
    self = $ this
    self.on 'click', -> inpf.click()

    inpf = $ "<input type='color'>"
    inpf.on 'change', ->
      state.style = inpf.val()
      self.css 'background-color', inpf.val()
      self.css 'color', 'white'

    inpf.css 'visibility', 'hidden'
    inpf.val(state.style).change().appendTo body

  $(".width-picker").each ->
    self = $ this
    self.html('')

    inpf = $ "<input type='range' min='1' max='60' step='1'>"
    inpf.on 'change', -> state.width = parseInt inpf.val()
    inpf.on 'click',  -> false
    inpf.val(state.width).change().appendTo self

  $(".layer-menu").each ->
    self = $ this

    self.on 'click', '.create-layer', ->
      name = prompt 'new layer name:'
      if name and canvas._paths[name] is undefined
        canvas._paths[name] = { paths: [], hidden: false }
        state.layer = name
        update()

    self.on 'click', '.toggle-layer-visibility', (ev) ->
      ev.stopPropagation()
      value = $(this).parent().attr('data-layer')
      canvas._paths[value].hidden = not canvas._paths[value].hidden
      canvas.redraw()
      $(this).toggleClass('fa-eye').toggleClass('fa-eye-slash')

    self.on 'click', '.remove-layer', (ev) ->
      ev.stopPropagation()
      value = $(this).parent().attr('data-layer')
      delete canvas._paths[value]
      canvas.redraw()
      if value == state.layer
        for k of canvas._paths
          0  # noop
        if k is undefined
          # k will be undefined if `canvas._paths` is empty,
          state.layer = defaults.layer
          canvas._paths[state.layer] = { paths: [], hidden: false }
        else
          # otherwise it will point to one of the layers.
          state.layer = k
      update()

    self.on 'click', '[data-layer]', ->
      state.layer = $(this).attr('data-layer')
      entry = $(this).parent()
      entry.addClass "active" unless entry.hasClass "active"
      entry.siblings().removeClass "active"
      $(".layer-display").text $(this).text()

    update = ->
      self.html ''
      self.append $ '<li><a class="create-layer">create</a></li>'
      self.append $ '<li class="divider">'

      for i of canvas._paths
        check = $ "<i class='fa toggle-layer-visibility'></i>"
        check.addClass if canvas._paths.hidden then 'fa-eye-slash' else 'fa-eye'

        item = $ "<a data-layer='#{i}'>"
        item.text i
        item.prepend ' <i class="fa fa-times remove-layer"></i> '
        item.prepend check

        entry = $ "<li>"
        entry.append item
        entry.appendTo self
        item.click() if i == state.layer

    update()