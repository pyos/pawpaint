---
---

$ ->
  area = window.area = new Canvas.Area '.main-area'
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
