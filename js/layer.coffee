---
---

@Canvas.Layer = class Layer extends EventSystem
  # A single raster layer. Emits the following events:
  #
  #   resize (layer: Layer)  -- when the dimensions change
  #   redraw (layer: Layer)  -- when the contents change
  #   reprop (layer: Layer)  -- when some other property (e.g. opacity) changes
  #
  constructor: (area) ->
    super
    @area    = area
    @element = $ []

  @property 'hidden',
    ( ) -> @element.css('display') == 'none'
    (v) -> @element.css('display', if v then 'none' else '')

  @property 'opacity',
    ( ) -> @element.css('opacity')
    (v) -> @element.css('opacity', v)

  # This requires experimental CSS support.
  # See the documentation on `mix-blend-mode` for details.
  @property 'blendMode',
    ( ) -> @element.css('mix-blend-mode')
    (v) -> @element.css('mix-blend-mode', v)

  @property 'fill',
    ( ) -> 'transparent'
    (v) ->
      opt = @area.tool.options
      ctx = @img().getContext('2d')
      ctx.fillStyle = switch v
        when "toolColor" then "hsl(#{opt.H},#{opt.S}%,#{opt.L}%)"
        else v
      ctx.fillRect 0, 0, @w, @h
      @trigger('redraw', [this])

  # Remove the contents of this layer. (And the element that represents it.)
  #
  # clear :: -> a
  #
  clear: ->
    @element.remove()
    @element = $ []
    @trigger('redraw', [this])

  # Change the position of this layer relative to the image.
  #
  # move :: int int -> a
  #
  move: (@x, @y) -> @trigger('resize', [this])

  # Change the size of this layer without modifying its contents.
  # The offset is relative to the image.
  #
  # crop :: int int int int -> a
  #
  crop: (x, y, @w, @h) ->
    dx = @x - x
    dy = @y - y
    @move(x, y)
    @replace(@element, dx, dy, false)

  # Change the size of this layer and scale the contents at the same time.
  #
  # resize :: int int -> a
  #
  resize: (@w, @h) ->
    @trigger('resize', [this])
    @replace(@element, 0, 0, true)

  # Recreate the element that represents this layer.
  #
  # replace :: [Either Canvas Image] int int bool -> a
  #
  replace: (imgs, x, y, scale) ->
    element = new Canvas(@w, @h).addClass('layer')
    context = element[0].getContext('2d')
    if scale
      context.drawImage img, x, y, @w, @h for img in imgs
    else
      context.drawImage img, x, y for img in imgs
    @element.remove()
    @element = element.appendTo(@area.element)
    @trigger('redraw', [this])

  # Update the style of the element that represents this layer.
  #
  # restyle :: int float -> a
  #
  restyle: (index, scale) ->
    @element.css {
      'z-index': index,
      'left':   @x * scale,
      'top':    @y * scale,
      'width':  @w * scale,
      'height': @h * scale,
    }

  # Load a layer from an old state.
  #
  # set :: State -> a
  #
  set: (state) ->
    return @setFromData(state, null) if state.data
    img = new Image
    img.onload = => @setFromData(state, img)
    img.src = state.i

  setFromData: (state, img) ->
    @clear()
    @crop(state.x, state.y, state.w or img.width, state.h or img.height)
    if img
      @replace([img], 0, 0, false)
    else
      @replace([], 0, 0, false)
      @img().getContext('2d').putImageData(state.data, 0, 0)
    @blendMode = state.blendMode
    @opacity   = state.opacity
    @hidden    = state.hidden

  # Get the image that represents the contents of this layer.
  #
  # img :: bool -> Image
  #
  img: (force) ->
    if @element.length then @element[0] else document.createElement 'canvas'

  # Draw the contents of this layer onto a 2D canvas context.
  #
  # drawOnto :: Context2D -> a
  #
  drawOnto: (ctx) ->
    if not @hidden
      ctx.globalAlpha = parseFloat @opacity
      ctx.globalCompositeOperation =
        if @blendMode is "normal" then "source-over" else @blendMode
      ctx.drawImage @img(), @x, @y

  # Encode the contents of this layer as a data: URL.
  #
  # url :: -> str
  #
  url: -> @img().toDataURL('image/png')

  # Encode the contents of this layer as an SVG shape.
  #
  # svg :: -> jQuery
  #
  svg: ->
    $ "<svg:image style='mix-blend-mode: #{@blendMode}'>"
      .attr 'xlink:href': @url(), 'x': @x, 'y': @y, 'width': @w, 'height': @h
      .attr 'opacity': @opacity, 'visibility': if @hidden then 'hidden' else @visibility

  # Return the immutable state of this layer.
  #
  # state :: -> State
  #
  state: (imdata) -> {
    x: @x, y: @y, w: @w, h: @h, i: if imdata then null else @url(),
    blendMode: @blendMode, opacity: @opacity, hidden: @hidden,
    data: if imdata then @img().getContext('2d').getImageData(0, 0, @w, @h) else null
  }

  # Create a new state given a data: URL.
  #
  # stateFromURL :: str -> State
  #
  stateFromURL: (data) -> {
    x: 0, y: 0, w: 0, h: 0, i: data, blendMode: 'normal', opacity: '1', hidden: false
  }

  # Create a new state given an SVG shape.
  #
  # stateFromSVG :: jQuery -> State
  #
  stateFromSVG: (elem) -> {
    x: parseInt elem.attr('x')
    y: parseInt elem.attr('y')
    w: parseInt elem.attr('width')
    h: parseInt elem.attr('height')
    i: elem.attr('xlink:href')
    opacity:   elem.attr('opacity')
    hidden:    elem.attr('visibility') == 'hidden'
    blendMode: elem.css('mix-blend-mode')
  }
