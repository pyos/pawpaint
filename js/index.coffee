---
---

$ ->
  area = window.area = new Canvas.Area '.main-area',
    Canvas.Tool.Selection.Rect
    Canvas.Tool.Selection.Ellipse
    Canvas.Tool.Move
    Canvas.Tool.Colorpicker
    Canvas.Tool.Pen
    class _ extends Canvas.Tool.Resource then rsrc: 'brush-circle-blur-16'
    class _ extends Canvas.Tool.Resource then rsrc: 'brush-circle-blur-32'
    class _ extends Canvas.Tool.Resource then rsrc: 'brush-circle-blur-64'
    Canvas.Tool.Eraser
    class _ extends Canvas.Tool.Resource then rsrc: 'brush-pencil'
    class _ extends Canvas.Tool.Resource then rsrc: 'brush-skewed-ellipse'; spacingAdjust: 0
    class _ extends Canvas.Tool.Resource then rsrc: 'brush-star'

  Canvas.palettesFromURL 'img/palettes.dat', (d) ->
    area.palettes = d

  $(window).on 'unload', -> if area
    @localStorage?.image   = if area.layers.length then area.export("svg") else ""
    @localStorage?.palette = area.palette

  $(document).keymappable()
    .on 'key:ctrl+90',       (_, e) -> e.preventDefault(); area.undo()
    .on 'key:ctrl+shift+90', (_, e) -> e.preventDefault(); area.redo()
    .on 'key:ctrl+48',       (_, e) -> e.preventDefault(); area.setScale(1)
    .on 'key:ctrl+189',      (_, e) -> e.preventDefault(); area.setScale(area.scale * 0.8)
    .on 'key:ctrl+187',      (_, e) -> e.preventDefault(); area.setScale(area.scale * 1.25)
    .on 'key:ctrl+83',       (_, e) -> e.preventDefault(); $('.action-export').click()
    .on 'key:27',            (_, e) -> $('.cover').click()
   #.on 'key:ctrl+67',       (_, e) -> e.preventDefault(); area.copy()
   #.on 'key:ctrl+shift+67'  (_, e) -> e.preventDefault(); area.copy(true)
   #.on 'key:ctrl+88',       (_, e) -> e.preventDefault(); area.copy(); area.clear()
   #.on 'key:ctrl+86',       (_, e) -> e.preventDefault(); area.paste()
   #.on 'key:ctrl+73',       (_, e) -> e.preventDefault(); area.invertSelection()
    .on 'click', '.action-add-layer', -> area.createLayer()
    .on 'click', '.action-del-layer', -> area.deleteLayer(area.layer)
    .on 'click', '.action-undo',      -> area.undo()
    .on 'click', '.action-redo',      -> area.redo()

  button = $ '.action-tool'
  $('body').addClass('no-canvas') if not Canvas.exists()
  $('.first-time').removeClass('hidden').on('click', -> $(@).remove()) if not window.localStorage?.image
  $('.action-tool')     .selector_button(area, $.fn.selector_main,     '.templates .selector-main')
  $('.action-export')   .selector_button(area, $.fn.selector_export,   '.templates .selector-export')
  $('.action-dynamics') .selector_button(area, $.fn.selector_dynamics, '.templates .selector-dynamics')
  $('.layer-menu')      .selector_layers(area, '.templates .selector-layer-config')
  $('.layer-menu').on 'mousedown touchstart', 'li', (ev) ->
    # This will make stuff work with both touchscreens and mice.
    _getY = (ev) -> (ev.originalEvent.touches?[0] or ev).pageY
    _getC = (ev) -> ev.originalEvent.touches?.length or ev.which
    return if _getC(ev) != 1

    body = $('body')
    elem = $(@).removeData('no-layer-menu')

    deltaC = 15
    startC = _getY(ev)
    startP = elem.position().top

    offset = null
    zindex = ''
    oldpos = ''
    oldtop = ''

    h1 = (ev) ->
      # Another touch/click detected, abort. (If `_getC` returns the same value,
      # though, that's the initial event. We need to ignore it.)
      h3(ev) if _getC(ev) > 1

    h2 = (ev) ->
      if offset is null and abs(_getY(ev) - startC) > deltaC
        zindex = elem.css('z-index')
        oldpos = elem.css('position')
        oldtop = elem.css('top')
        offset = 0
        elem.css 'z-index', '65539'
        elem.css 'position', 'absolute'
      if offset isnt null
        offset = _getY(ev) - startC
        elem.css 'top', offset + startP

    h3 = (ev) ->
      body.off 'mousedown touchstart', h1
      body.off 'mousemove touchmove',  h2
      body.off 'mouseup   touchend',   h3

      if offset isnt null and _getC(ev) <= 1
        elem.data('no-layer-menu', true)
        elem.parent().children().each (i) ->
          if i != elem.index() and $(@).hasClass('hidden') or offset + startP < $(@).position().top
            area.moveLayer(elem.index(), i - elem.index() - (i >= elem.index()))
            # Stop iterating.
            return false
          return true

      elem.css('position', oldpos or '')
      elem.css('z-index',  zindex or '')
      elem.css('top',      oldtop or '')

    body.on 'mousedown touchstart', h1
    body.on 'mousemove touchmove',  h2
    body.on 'mouseup   touchend',   h3

  area.element.on 'contextmenu click', (e) ->
    if e.which == 2 or e.which == 3
      e.preventDefault()
      $('.templates .selector-main').selector_main(area, e.clientX, e.clientY).appendTo('body')

  area.on 'tool:kind tool:L', ->
    button.each ->
      lvl = if area.tool.options.L > 50 then 0 else 100
      ctx = @getContext('2d')
      ctx.clearRect 0, 0, @width, @height

      tool = new area.tool.constructor(area, size: min(@width, @height) * 0.75, H: 0, S: 0, L: lvl)
      tool.symbol ctx, @width / 2, @height / 2

  area.on 'tool:H tool:S tool:L', ->
    button.css 'background', "hsl(#{area.tool.options.H},#{area.tool.options.S}%,#{area.tool.options.L}%)"

  area.setToolOptions(kind: Canvas.Tool.Pen, last: Canvas.Tool.Pen)
  area.import    window.localStorage.image   if window.localStorage?.image
  area.palette = window.localStorage.palette if window.localStorage?.palette
  area.createLayer() if not area.layers.length
