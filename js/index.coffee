---
---

$ ->
  tools = [
    Canvas.Tool.Pen,
    Canvas.Tool.Resource.make('brush-circle-blur-16'),
    Canvas.Tool.Resource.make('brush-circle-blur-32'),
    Canvas.Tool.Resource.make('brush-circle-blur-64'),
    Canvas.Tool.Eraser,
    Canvas.Tool.Resource.make('brush-skewed-ellipse'),
    Canvas.Tool.Resource.make('brush-star'),
  ]

  area = window.area = new Canvas.Area '.main-area', tools
  area.addLayer 0
  area.setTool  Canvas.Tool.Pen

  area.element
    .on 'contextmenu', (e) -> e.preventDefault(); new Canvas.Selector area, e.clientX, e.clientY

  button = new Canvas.Selector.Button area, 45, 45
  button.element.appendTo '.side-area'

  dynamics = new Canvas.Selector.DynamicsButton area
  dynamics.element.appendTo '.side-area'

  undo = $ '<a class="undo-btn">'
    .appendTo '.side-area'
    .on 'click', -> area.undo()

  redo = $ '<a class="redo-btn">'
    .appendTo '.side-area'
    .on 'click', -> area.redo()

  exportb = new Canvas.Selector.ExportButton area
  exportb.element.appendTo '.side-area'

  layers = new Canvas.Selector.Layers area
  layers.element.appendTo '.side-area'

  $(document).keymap {key: CTRL | 90,         f: area.undo.bind(area)},
                     {key: CTRL | SHIFT | 90, f: area.redo.bind(area)}
