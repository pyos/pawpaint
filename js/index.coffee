---
---

$ ->
  area = window.area = new Canvas.Area '.main-area',
    Canvas.Tool.Pen
    Canvas.Tool.Resource.make('brush-circle-blur-16')
    Canvas.Tool.Resource.make('brush-circle-blur-32')
    Canvas.Tool.Resource.make('brush-circle-blur-64')
    Canvas.Tool.Eraser
    Canvas.Tool.Resource.make('brush-skewed-ellipse')
    Canvas.Tool.Resource.make('brush-star')

  $(window).on 'unload', -> @localStorage?.image = area.export("svg") if area
  $(document).keymappable()
    .on 'key:ctrl+90',       (_, e) -> e.preventDefault(); area.undo()
    .on 'key:ctrl+shift+90', (_, e) -> e.preventDefault(); area.redo()
    .on 'click', '.action-add-layer', -> area.createLayer()
    .on 'click', '.action-del-layer', -> area.deleteLayer(area.layer)
    .on 'click', '.action-undo',      -> area.undo()
    .on 'click', '.action-redo',      -> area.redo()

  button = $ '.action-tool'
  $('body').addClass('no-canvas')  if not Canvas.exists()
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

  area.element
    .on 'contextmenu', (e) ->
      e.preventDefault()
      $('.templates .selector-main').selector_main(area, e.clientX, e.clientY).appendTo('body')
    .on 'tool:kind tool:L', ->
      button.each ->
        lvl = if area.tool.options.L > 50 then 0 else 100
        ctx = @getContext('2d')
        ctx.clearRect 0, 0, @width, @height

        tool = new area.tool.constructor(size: min(@width, @height) * 0.75, H: 0, S: 0, L: lvl)
        tool.symbol ctx, @width / 2, @height / 2
    .on 'tool:H tool:S tool:L', ->
      button.css 'background', "hsl(#{area.tool.options.H},#{area.tool.options.S}%,#{area.tool.options.L}%)"

  area.setTool Canvas.Tool.Pen
  if window.localStorage?.image
    area.import window.localStorage.image
  else
    img = new Image
    img.onload = ->
      area.createLayer()
      area.resizeLayer(0, area.layers[0][0].width, area.layers[0][0].height, 0, 0, img, true)
    img.src = 'img/initial.png'
