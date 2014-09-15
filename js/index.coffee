$ ->
  area = window.area = new Canvas.Area '.main-area', [Canvas.Pen, Canvas.Eraser]

  tools = $ '.tool-menu'
  tools.on 'click', '[data-tool]', ->
    tool = area.tools[parseInt $(this).attr('data-tool')]
    area.setTool tool, area.tool.options

  for t of area.tools
    item = $ "<a data-tool='#{t}'>"
    item.text area.tools[t].name
    $("<li>").append(item).appendTo(tools)

  colors = $ '.color-picker'
  colors.on 'click', -> colors.input.click()
  colors.input = $ '<input type="color">'
  colors.input.css 'position', 'absolute'
  colors.input.css 'visibility', 'hidden'
  colors.input.appendTo area.element
  colors.input.on 'change', -> area.setToolOptions color: @value

  width = $ '.width-picker'
  width.input = $ '<input type="range" min="1" max="61" step="1">'
  width.input.appendTo width.html('')
  width.input.on 'change',     -> area.setToolOptions size: parseInt(@value)
  width.input.on 'click', (ev) -> ev.stopPropagation()

  layers = $ '.layer-menu'
  layers
    .on 'click', '.toggle', (ev) ->
      ev.stopPropagation()
      area.toggleLayer $(this).parents('li').index()

    .on 'click', '.remove', (ev) ->
      ev.stopPropagation()
      area.delLayer $(this).parents('li').index()

    .on 'click', 'li', (ev) ->
      area.setLayer $(this).index()

  area.element
    .on 'tool:size',  (_, v) -> width.input.val v
    .on 'tool:color', (_, v) -> colors.css 'background-color', v
    .on 'tool:color', (_, v) -> colors.input.val v
    .on 'tool:kind',  (_, v) ->
      index = area.tools.indexOf v
      eitem = tools.find "[data-tool='#{index}']"
      entry = eitem.parent()

      entry.addClass "active" unless entry.hasClass "active"
      entry.siblings().removeClass "active"
      $('.tool-display').html(v.name)

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
