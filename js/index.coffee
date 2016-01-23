---
---

$ ->
  area = window.area = new Area $('.main-area .layers')[0], [
    Canvas.Tool.Selection.Rect
    Canvas.Tool.Move
    Canvas.Tool.Colorpicker
    Canvas.Tool.Eraser
    Canvas.Tool.Pen
    class _ extends Canvas.Tool.FromImage then img: $id 'r-round-16'
    class _ extends Canvas.Tool.FromImage then img: $id 'r-round-32'
    class _ extends Canvas.Tool.FromImage then img: $id 'r-round-64'
    class _ extends Canvas.Tool.FromImage then img: $id 'r-line'; spacingAdjust: 0
  ]

  xhr = new XMLHttpRequest
  xhr.open 'GET', 'img/palettes.dat', true
  xhr.responseType = 'arraybuffer'
  xhr.onload = -> area.palettes = Canvas.palettes(new Uint8Array @response)
  xhr.send()

  $(window).on 'unload', ->
    if area
      @localStorage?.image   = area.export("svg")
      @localStorage?.palette = area.palette

  $('body').keymappable()
    .on 'key:ctrl+90',       (_, e) -> e.preventDefault(); area.undo()  # Ctrl+Z
    .on 'key:ctrl+shift+90', (_, e) -> e.preventDefault(); area.redo()  # Ctrl+Shift+Z
    .on 'key:ctrl+89',       (_, e) -> e.preventDefault(); area.redo()  # Ctrl+Y
    .on 'key:ctrl+48',       (_, e) -> e.preventDefault(); area.setScale(1)  # Ctrl+0
    .on 'key:ctrl+189',      (_, e) -> e.preventDefault(); area.setScale(area.scale * 0.8)   # Ctrl+-
    .on 'key:ctrl+187',      (_, e) -> e.preventDefault(); area.setScale(area.scale * 1.25)  # Ctrl+=
    .on 'key:27',            (_, e) -> e.preventDefault(); $('.cover').click()  # Esc
    .on 'key:ctrl+83',       (_, e) ->  # Ctrl+S
      e.preventDefault()
      link = document.createElement 'a'
      link.download = 'image.png'
      link.href     = area.export('png')
      link.click()

    .on 'key:81', -> area.createLayer(0)  # Q
    .on 'key:78', -> area.createLayer(0)  # N
    .on 'key:88', -> area.deleteLayer(area.layer)  # X
    .on 'key:87', -> area.setToolOptions(kind: area.tool.options.last)  # W
    .on 'key:69', -> area.setToolOptions(kind: Canvas.Tool.Eraser)      # E
    .on 'key:65', -> area.mergeDown(area.layer)  # A
    .on 'key:77', -> area.mergeDown(area.layer)  # M

    .on 'click', '.action-add-layer', -> area.createLayer(0)
    .on 'click', '.action-del-layer', -> area.deleteLayer(area.layer)
    .on 'click', '.action-undo',      -> area.undo()
    .on 'click', '.action-redo',      -> area.redo()
    .on 'click', '.cover', (e) -> $(@).fadeOut(100, $(@).remove.bind $(@)) if e.target is e.currentTarget
    .on 'click', '.tabbar li', ->
      attr = @getAttribute 'data-target'
      self = $ @
      self.siblings().removeClass('active').end().addClass('active')
      self.parent().parent().find('.tab').removeClass('active').filter(attr).addClass('active')
    .on 'click contextmenu', '[data-selector], [data-selector-menu]', (ev) ->
      if ev.which > 1
        s = $(@).attr 'data-selector-menu'
        o = left: ev.clientX, top: ev.clientY
      else
        s = $(@).attr 'data-selector'
        o = left: @offsetLeft, top: @offsetTop, fix: true
      if s
        ev.preventDefault()
        $(".templates .selector-#{s}")["selector_" + s](area, o.left, o.top, o.fix).appendTo('body')

   #.on 'copy',     (e) -> e.preventDefault(); area.copy(e.originalEvent.clipboardData)
   #.on 'cut',      (e) -> e.preventDefault(); area.copy(e.originalEvent.clipboardData); area.clear()
    .on 'paste',    (e) -> e.preventDefault(); area.paste(e.originalEvent.clipboardData)
    .on 'drop',     (e) -> e.preventDefault(); area.paste(e.originalEvent.dataTransfer)
    .on 'dragover', (e) -> e.preventDefault()

  main = $ '.main-area'
  tool = $ '.action-tool'
  menu = $ '.layer-menu'
  menu.selector_layers area, '.templates .selector-layer-config'

  area.on 'tool:options', (v) ->
    tool.css 'background', "hsl(#{v.H},#{v.S}%,#{v.L}%)"
    tool.find('canvas').each ->
      ctx = @getContext('2d')
      ctx.clearRect 0, 0, @width, @height
      t = new v.kind(null, size: min(@width, @height) * 0.75, L: if v.L > 50 then 0 else 100)
      t.symbol(ctx, @width / 2, @height / 2)

  area.setToolOptions(kind: Canvas.Tool.Pen, last: Canvas.Tool.Pen)
  area.import(window.localStorage.image, true) if window.localStorage?.image

  if not area.layers.length
      area.setSize main.innerWidth(), main.innerHeight()
      area.createLayer(0).fill = 'white'
  else
      area.palette = window.localStorage.palette
