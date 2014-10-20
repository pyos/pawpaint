---
---

$ ->
  area = window.area = new Canvas.Area '.main-area .layers',
    Canvas.Tool.Selection.Rect
    Canvas.Tool.Move
    Canvas.Tool.Colorpicker
    Canvas.Tool.Eraser
    Canvas.Tool.Pen
    class _ extends Canvas.Tool.Resource then rsrc: 'brush-soft-16'
    class _ extends Canvas.Tool.Resource then rsrc: 'brush-soft-32'
    class _ extends Canvas.Tool.Resource then rsrc: 'brush-soft-64'
    class _ extends Canvas.Tool.Resource then rsrc: 'brush-watercolor'
    class _ extends Canvas.Tool.Resource then rsrc: 'brush-pencil'
    class _ extends Canvas.Tool.Resource then rsrc: 'brush-skewed-ellipse'; spacingAdjust: 0

  xhr = new XMLHttpRequest
  xhr.open 'GET', 'img/palettes.dat', true
  xhr.responseType = 'arraybuffer'
  xhr.onload = -> area.palettes = Canvas.palettes(new Uint8Array @response)
  xhr.send()

  $(window).on 'unload', -> if area
    @localStorage?.image   = area.export("svg")
    @localStorage?.palette = area.palette

  $(window).on 'resize', ->
    if window.outerWidth == screen.width and window.outerHeight == screen.height
      $('body').addClass('slim')
    else
      $('body').removeClass('slim')

  $('body').keymappable()
    .on 'key:ctrl+90',       (_, e) -> e.preventDefault(); area.undo()
    .on 'key:ctrl+shift+90', (_, e) -> e.preventDefault(); area.redo()
    .on 'key:ctrl+48',       (_, e) -> e.preventDefault(); area.setScale(1)
    .on 'key:ctrl+189',      (_, e) -> e.preventDefault(); area.setScale(area.scale * 0.8)
    .on 'key:ctrl+187',      (_, e) -> e.preventDefault(); area.setScale(area.scale * 1.25)
    .on 'key:ctrl+83',       (_, e) -> e.preventDefault(); $('.action-export').click()
    .on 'key:ctrl+shift+70', (_, e) -> e.preventDefault(); $('body').toggleClass('slim')
    .on 'key:27',            (_, e) -> $('.cover').click()
    .on 'click', '.action-add-layer', -> area.createLayer()
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

  area.on 'layer:add', ->
    area.resize main.innerWidth(), main.innerHeight() if area.w == 0 or area.h == 0

  area.on 'tool:options', (v) ->
    tool.css 'background', "hsl(#{v.H},#{v.S}%,#{v.L}%)"
    tool.find('canvas').each ->
      ctx = @getContext('2d')
      ctx.clearRect 0, 0, @width, @height
      t = new v.kind(null, size: min(@width, @height) * 0.75, L: if v.L > 50 then 0 else 100)
      t.symbol(ctx, @width / 2, @height / 2)

  area.setToolOptions(kind: Canvas.Tool.Pen, last: Canvas.Tool.Pen)
  area.import    window.localStorage.image   if window.localStorage?.image
  area.palette = window.localStorage.palette if window.localStorage?.palette
  area.layers[0].fill('white') if not area.layers.length and area.createLayer()
