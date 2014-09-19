---
---

$ ->
  tools = [
    Canvas.Tool.Pen,
    Canvas.Tool.Eraser,
    Canvas.Tool.Resource.make('brush-circle-blur-16'),
    Canvas.Tool.Resource.make('brush-circle-blur-32'),
    Canvas.Tool.Resource.make('brush-circle-blur-64')]

  area = window.area = new Canvas.Area '.main-area', tools
  area.addLayer 0
  area.setTool  Canvas.Tool.Pen

  area.element
    .on 'contextmenu', (e) -> e.preventDefault(); new Canvas.Selector area, e.clientX, e.clientY

  button = new Canvas.Selector.Button area
  button.element.appendTo '.side-area'

  layers = new Canvas.Selector.Layers area
  layers.element.appendTo '.side-area'

  $(document).keymap {key: CTRL | 90,         f: area.undo.bind(area)},
                     {key: CTRL | SHIFT | 90, f: area.redo.bind(area)}
