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

  setHidden:    (v) -> @element.css('display', if v then 'none' else ''); @trigger('reprop', [@])
  getHidden:    ( ) -> @element.css('display') == 'none'
  setBlendMode: (v) -> @element.css('mix-blend-mode', v); @trigger('reprop', [@])
  getBlendMode: ( ) -> @element.css('mix-blend-mode')
  setOpacity:   (v) -> @element.css('opacity', v); @trigger('reprop', [@])
  getOpacity:   ( ) -> @element.css('opacity')

  # Remove the contents of this layer. (And the element that represents it.)
  #
  # clear :: -> a
  #
  clear: ->
    @element.remove()
    @element = $ []
    @trigger('redraw', [this])

  # Change the position of this layer.
  #
  # move :: int int -> a
  #
  move: (@x, @y) -> @trigger('resize', [this])

  # Change the size of this layer.
  #
  # resize :: int int int int -> a
  #
  resize: (@x, @y, @w, @h) -> @trigger('resize', [this])

  # Recreate the element that represents this layer.
  # Optionally, draw something on it.
  #
  # replace :: (Optional Image) -> a
  #
  replace: (img) ->
    element = new Canvas(@w, @h).addClass('layer')
    context = element[0].getContext('2d')
    context.drawImage cnv, 0, 0 for cnv in @element
    context.drawImage img, 0, 0 if img
    @element.remove()
    @element = element.appendTo(@area.element)
    @trigger('redraw', [this])

  # Update the style of the element that represents this layer.
  #
  # restyle :: int float -> a
  #
  restyle: (index, scale) ->
    @element.css {
      'z-index': -index,
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
    img = new Image
    img.src = state.i
    if img.width and img.height
      @clear()
      @resize(state.x, state.y, state.w or img.width, state.h or img.height)
      @replace(img)
      @setBlendMode state.blendMode
      @setOpacity   state.opacity
      @setHidden    state.hidden
      return true
    @resize(state.x, state.y, 1, 1)
    return false

  # Get the image that represents the contents of this layer.
  #
  # img :: bool -> Image
  #
  img: (force) ->
    if @element.length and (force or not @getHidden())
      @element[0]
    else
      document.createElement 'canvas'

  # Encode the contents of this layer as a data: URL.
  #
  # url :: -> str
  #
  url: -> @img(true).toDataURL('image/png')

  # Encode the contents of this layer as an SVG shape.
  #
  # svg :: -> jQuery
  #
  svg: ->
    $('<image>').attr('xmlns', 'http://www.w3.org/2000/svg')
      .attr {'xlink:href': @url(), 'x': "#{@x}px", 'y': "#{@y}px", 'width': "#{@w}px", 'height': "#{@h}px"}
      .attr {'data-opacity': @getOpacity(), 'data-blend-mode': @getBlendMode(), 'data-hidden': @getHidden()}

  # Return the immutable state of this layer.
  #
  # state :: -> State
  #
  state: -> {
    x: @x, y: @y, w: @w, h: @h, i: @url(),
    blendMode: @getBlendMode(), opacity: @getOpacity(), hidden: @getHidden()
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
    blendMode: elem.attr('data-blend-mode')
    opacity:   elem.attr('data-opacity')
    hidden:    elem.attr('data-hidden') == 'true'
  }
