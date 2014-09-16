$ ->
  tool = $ '.tool-name'
    .on 'click', (ev) ->
      Canvas.Selector.show(area, tool.offset().left, tool.offset().top + tool.outerHeight(), true)

  layers = $ '.layer-menu'
    .on 'click', '.toggle', (ev) ->
      ev.stopPropagation()
      area.toggleLayer $(this).parents('li').index()

    .on 'click', '.remove', (ev) ->
      ev.stopPropagation()
      area.delLayer $(this).parents('li').index()

    .on 'click', 'li', (ev) ->
      area.setLayer $(this).index()

  area = window.area = new Canvas.Area '.main-area', [Canvas.Pen, Canvas.Eraser]
  area.element
    .on 'tool:size',  (_, v) -> area.element.toggleClass('no-cursor') if area.element.hasClass('no-cursor') != (v >= 15)
    .on 'tool:kind',  (_, v) -> tool.text(v.name)
    .on 'tool:color', (_, v) ->
      tool
        .css 'background', v
        .css 'color', if Canvas.RGBtoHSL(v)[2] > 0.5 then 'black' else 'white'

    .on 'layer:add', (_, layer) ->
      entry = $ '<li><a><i class="fa toggle fa-eye"></i> <i class="fa fa-times remove"></i> <span class="name"></span></a></li>'
      entry.find('.name').text layer.name
      entry.appendTo layers

    .on 'layer:set', (_, index) ->
      $('.layer-display').text area.layers[index].name
      layers.children().removeClass 'active'
      layers.children().eq(index).addClass 'active'

    .on 'layer:del',    (_, i)    -> layers.children().eq(i).remove()
    .on 'layer:move',   (_, i, d) -> layers.children().eq(i).insertAfter(layers.children().eq(i + d))
    .on 'layer:toggle', (_, i)    -> layers.children().eq(i).find('.toggle').toggleClass('fa-eye').toggleClass('fa-eye-slash')

    .on 'button:1', (_, e) -> Canvas.Selector.show(area, e.pageX, e.pageY)

  area.addLayer null
  area.setTool  area.tools[0], {}
