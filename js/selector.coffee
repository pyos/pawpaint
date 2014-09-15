window.Canvas or= {}
window.Canvas.Selector =
  show: (area, x, y) ->
    cover = $ '<div class="canvas-selector-container">'
      .css 'position', 'absolute'
      .css 'left',   0
      .css 'top',    0
      .css 'right',  0
      .css 'bottom', 0
      .on 'click', -> $(this).remove()
      .appendTo 'body'
      .append(
        $ '<div class="canvas-selector">'
          .css 'position', 'absolute'
          .css 'left', x
          .css 'top',  y
          .on 'click', (ev) -> ev.stopPropagation()
      )
