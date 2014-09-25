---
---

$ ->
  area = window.area = new Canvas.Area '.main-area', [
    Canvas.Tool.Pen,
    Canvas.Tool.Resource.make('brush-circle-blur-16'),
    Canvas.Tool.Resource.make('brush-circle-blur-32'),
    Canvas.Tool.Resource.make('brush-circle-blur-64'),
    Canvas.Tool.Eraser,
    Canvas.Tool.Resource.make('brush-skewed-ellipse'),
    Canvas.Tool.Resource.make('brush-star'),
  ]

  $('.action-undo').on 'click', -> area.undo()
  $('.action-redo').on 'click', -> area.redo()
  $('.action-tool').selector_button(area, $.fn.selector_main, '.templates .selector-main')
  $('.action-export').selector_button(area, $.fn.selector_export, '.templates .selector-export')
  $('.action-dynamics').selector_button(area, $.fn.selector_dynamics, '.templates .selector-dynamics')
  $('.layer-menu').selector_layers(area)

  button = $ '.action-tool'
  layers = $ '.layer-menu'

  area.element
    .on 'contextmenu', (e) -> e.preventDefault(); $('body').selector_main(area, e.clientX, e.clientY)
    .on 'tool:kind tool:L', ->
      button.each ->
        lvl = if area.tool.options.L > 50 then 0 else 100
        ctx = @getContext('2d')
        ctx.clearRect 0, 0, @width, @height

        tool = new area.tool.constructor(size: min(@width, @height) * 0.75, H: 0, S: 0, L: lvl)
        tool.symbol ctx, @width / 2, @height / 2
    .on 'tool:H tool:S tool:L', ->
      button.css 'background', "hsl(#{area.tool.options.H},#{area.tool.options.S}%,#{area.tool.options.L}%)"

  area.addLayer 0
  area.setTool  Canvas.Tool.Pen

  $(window).on 'resize', -> area.resize()
  $(window).keymap {key: CTRL | 90,         f: area.undo.bind(area)},
                   {key: CTRL | SHIFT | 90, f: area.redo.bind(area)}
