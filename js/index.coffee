$ ->
  tool = $ '.tool-name'
  tool.on 'click', (ev) ->
    if ev.which == 1
      Canvas.Selector(area, tool.offset().left, tool.offset().top + tool.outerHeight(), true)

  layers = $ '.layer-menu'
  layers.on 'click', 'li', (ev) ->
    if ev.which == 1
      area.setLayer $(this).index()

  layermenu = $ '.layer-global-cmds'
    .on 'click', '.layer-add',  (ev) -> ev.preventDefault(); area.addLayer(null)
    .on 'click', '.layer-del',  (ev) -> ev.preventDefault(); area.delLayer(area.layer)
    .on 'click', '.layer-hide', (ev) -> ev.preventDefault(); area.toggleLayer(area.layer)
    .on 'click', '.layer-show', (ev) -> ev.preventDefault(); area.toggleLayer(area.layer)

  area = window.area = new Canvas.Area '.main-area'
  area.element
    .on 'tool:kind',  (_, v) -> tool.text(v.name)
    .on 'tool:H',     (_, v, o) -> tool.css 'background', "hsl(#{o.H}, #{o.S}%, #{o.L}%)"
    .on 'tool:S',     (_, v, o) -> tool.css 'background', "hsl(#{o.H}, #{o.S}%, #{o.L}%)"
    .on 'tool:L',     (_, v, o) ->
      tool.css background: "hsl(#{o.H}, #{o.S}%, #{o.L}%)", color: if o.L > 50 then 'black' else 'white'

    .on 'layer:add', (_, layer) ->
      width  = area.element.innerWidth()
      height = area.element.innerHeight()
      msize  = max(width, height)
      canvas = new Canvas(width / msize * 50, height / msize * 50)

      entry = $ "<li><a><span class='name'></span></a></li>"
      entry.find('.name').before(canvas).text 'Layer'  # todo
      entry.appendTo layers

    .on 'layer:set', (_, index) ->
      layers.children().removeClass('active')
      layers.children().eq(index).addClass('active')
      hidden = area.layers[index].css('display') == 'none'
      layermenu.find('.layer-hide').toggle(not hidden)
      layermenu.find('.layer-show').toggle(    hidden)

    .on 'stroke:begin',       (_, layer, index) -> area.snap index
    .on 'stroke:end refresh', (_, layer, index) ->
      cnv = layers.children().eq(index).find('canvas')
      ctx = cnv[0].getContext('2d')
      ctx.clearRect(0, 0, cnv.innerWidth(), cnv.innerHeight())
      ctx.drawImage(layer, 0, 0, cnv.innerWidth(), cnv.innerHeight())

    .on 'layer:del',    (_, i)    -> layers.children().eq(i).remove()
    .on 'layer:move',   (_, i, d) -> layers.children().eq(i).insertAfter(layers.children().eq(i + d))
    .on 'layer:toggle', (_, i)    -> layers.children().eq(i).toggleClass('layer-hidden')
    .on 'layer:toggle', (_, i) ->
      if i == area.layer
        layermenu.find('.layer-hide').toggle()
        layermenu.find('.layer-show').toggle()

    .on 'mousedown', (e) ->
      if e.which == 2
        Canvas.Selector(area, e.pageX, e.pageY)

  area.addLayer null
  area.setTool  area.tools[0], {}

  $(document).keymap {key: CTRL | 90,         f: area.undo.bind(area)},
                     {key: CTRL | SHIFT | 90, f: area.redo.bind(area)}
