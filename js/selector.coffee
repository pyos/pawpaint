---
---

@Canvas.palettes = (data) ->
  i = 0
  r = {}
  t = new TextDecoder('utf-8')

  while i < data.length
    # struct Palette:
    #     uint16_t sz_name;
    #     uint16_t sz_swatches;
    return null if data.length < i + 4
    n = data[i++] << 8 | data[i++]
    k = data[i++] << 8 | data[i++]
    #     char name[sz_name];
    #     struct { unsigned H: 10, S: 7, L: 7; } swatches[sz_swatches];
    return null if data.length < i + n + k * 3
    c = r[t.decode(new DataView(data.buffer, i, n))] = []
    i += n
    for _ in [0...k]
      c.push
        H: (data[i++] << 2 | data[i] >> 6) & 0x3FF,
        S: (data[i++] << 1 | data[i] >> 7) & 0x7F,
        L: (data[i++]) & 0x7F
  return r


$.fn.selector_canvas = (area, value, update, redraw, nodrag) ->
  ontmove = (ev) -> ev.preventDefault(); on_move @, ev.originalEvent.touches[0]
  onmmove = (ev) -> ev.preventDefault(); on_move @, ev
  on_move = (e, ev) ->
    r = e.getBoundingClientRect()
    update.call(e, value, ev.clientX - r.left, ev.clientY - r.top)
    $(e).trigger('change', [value])
        .trigger('redraw')

  @on 'redraw', (_, init) -> redraw.call(@, value, @getContext('2d'), init)
  @on 'mousedown',  onmmove
  @on 'touchstart', ontmove
  unless nodrag
    @on 'mousedown',  (ev) -> $(@).on  'mousemove', onmmove
    @on 'touchstart', (ev) -> $(@).on  'touchmove', ontmove
    @on 'touchend',   (ev) -> $(@).off 'touchmove'
    @on 'mouseup',    (ev) -> $(@).off 'mousemove'
  return @trigger('redraw', [true])


$.fn.selector_color = (area) ->
  @each ->
    @outerR = min(@width, @height) / 2
    @innerR = 30 / 40 * @outerR
    @triagR = 25 / 40 * @outerR
    @triagA = sqrt(3) * @triagR
    @triagH = sqrt(3) * @triagA / 2

  @selector_canvas area, {H: area.tool.options.H, S: area.tool.options.S, L: area.tool.options.L},
    (value, x, y) ->
      x -= @outerR
      y -= @outerR

      if @innerR * @innerR <= x * x + y * y
        value.H = floor(atan2(y, x) * 180 / PI)
      else
        a = -value.H * PI / 180
        dx = x * cos(a) - y * sin(a) + @triagH / 3
        dy = x * sin(a) + y * cos(a) + @triagA / 2
        value.S = floor 100 * min 1, max 0, dx / @triagH / abs(1 - abs(dy * 2 / @triagA - 1))
        value.L = floor 100 * min 1, max 0, dy / @triagA

    (value, ctx, init) ->
      ctx.save()
      ctx.translate(@outerR, @outerR)

      if init
        value.H = area.tool.options.H
        value.S = area.tool.options.S
        value.L = area.tool.options.L

        ctx.clearRect(-@outerR, -@outerR, @width, @height)
        ctx.save()
        steps = 8
        delta = 2 * PI / steps
        dgrad = 360 / steps

        for i in [0...steps]
          grad = ctx.fillStyle = ctx.createLinearGradient(@outerR, 0, @outerR * cos(delta), @outerR * sin(delta))
          grad.addColorStop 0, "hsl(#{i * dgrad},         100%, 50%)"
          grad.addColorStop 1, "hsl(#{i * dgrad + dgrad}, 100%, 50%)"
          ctx.beginPath()
          ctx.arc(0, 0, @outerR, 0, delta, false)
          ctx.arc(0, 0, @innerR, delta, 0, true)
          ctx.fill()
          ctx.rotate(delta)
        ctx.restore()

      ctx.beginPath()
      ctx.arc(0, 0, @triagR, 0, PI * 2, false)
      ctx.clip()
      ctx.clearRect(-@triagR, -@triagR, @triagR * 2, @triagR * 2)

      ctx.rotate(value.H * PI / 180)
      ctx.translate(-@triagH / 3, 0)
      ctx.beginPath()
      ctx.moveTo(0, -@triagA / 2)
      ctx.lineTo(0, +@triagA / 2)
      ctx.lineTo(@triagH, 0)
      ctx.closePath()

      grad = ctx.fillStyle = ctx.createLinearGradient(0, -@triagA / 4, @triagH, 0)
      grad.addColorStop 0, "#000"
      grad.addColorStop 1, "hsl(#{value.H}, 100%, 50%)"
      ctx.fill()

      grad = ctx.fillStyle = ctx.createLinearGradient(0, +@triagA / 2, @triagH / 2, -@triagA / 4)
      grad.addColorStop 0, "rgba(255, 255, 255, 1)"
      grad.addColorStop 1, "rgba(255, 255, 255, 0)"
      ctx.fill()

      y = value.L / 100 * @triagA
      x = value.S / 100 * @triagH * abs(1 - abs(y * 2 / @triagA - 1))
      y -= @triagA / 2
      grad = ctx.fillStyle = ctx.createRadialGradient(x, y, 0, x, y, 3)
      grad.addColorStop 0, "rgba(0, 0, 0, 1)"
      grad.addColorStop 1, "rgba(255, 255, 255, 1)"
      ctx.beginPath()
      ctx.arc(x, y, 3, 0, 2 * PI)
      ctx.fill()
      ctx.restore()


$.fn.selector_vertical = (area, options) ->
  opt    = options.what
  ondraw = options.ondraw

  @each ->
    @low    = if options.min then options.min.call(this) else 1
    @high   = if options.max then options.max.call(this) else @low + @height
    @margin = @height / 20

  value = {}
  value[opt] = area.tool.options[opt]

  @selector_canvas area, value,
    (value, x, y) ->
      v = max(0, min(1, (@height - y - @margin) / (@height - 2 * @margin))) * (@high - @low) + @low
      value[opt] = options.fn v

    (value, ctx, init) ->
      ctx.save()
      ctx.clearRect(0, 0, @width, @height)
      ctx.translate(@width / 2, @height / 2)
      tool = new area.tool.constructor(area, area.tool.options)
      tool.setOptions dynamic: [], opacity: 0.5, H: 0, S: 0, L: 50, size: @width * 0.75
      tool.setOptions value
      ondraw?.call this, value, ctx, init, tool
      ctx.restore()

      y = (@high - options.inv(value[opt])) * (@height - 2 * @margin) / (@high - @low) + @margin
      ctx.lineWidth = 2
      ctx.strokeStyle = "rgba(127, 127, 127, 0.7)"
      ctx.beginPath()
      ctx.moveTo(0, floor y)
      ctx.lineTo(@width, floor y)
      ctx.stroke()


$.fn.selector_width = (area) -> @selector_vertical area,
  fn:  (x) -> floor(x ** 2 / 100)
  inv: (x) -> sqrt(x * 100)
  what: 'size'
  ondraw: (value, ctx, init, tool) ->
    tool.crosshair ctx


$.fn.selector_spacing = (area) -> @selector_vertical area,
  fn:  (x) -> floor x
  inv: (x) -> x
  min:     -> 1
  max:     -> @low + @height / 2
  what: 'spacing'
  ondraw: (value, ctx, init, tool) ->
    tool.start ctx, 0, -@height * 0.4, 1, 0
    tool.move  ctx, 0,  @height * 0.4, 1, 0
    tool.stop  ctx, 0,  @height * 0.4


$.fn.selector_opacity = (area) -> @selector_vertical area,
  fn:  (x) -> x
  inv: (x) -> x
  min: -> 0
  max: -> 1
  what: 'opacity'
  ondraw: (value, ctx, init, tool) ->
    tool.start ctx, 0, 0, 1, 0
    tool.move  ctx, 0, 1, 1, 0
    tool.stop  ctx, 0, 1


$.fn.selector_discrete = (area, options) ->
  cells = options.colsize or 4
  allow = options.choices or []
  value = {}; options.change(value, options.initial)

  @selector_canvas area, value,
    (value, x, y) ->
      result = allow[floor(x * cells / @height) * cells + floor(y * cells / @height)]
      options.change value, result if result

    (value, ctx, init) ->
      size = @height / cells
      ctx.clearRect(0, 0, @width, @height)
      ctx.strokeStyle = "#444"
      ctx.fillStyle   = "rgba(127, 127, 127, 0.3)"

      for i, v of allow
        x = floor(i / cells) * size
        y = floor(i % cells) * size

        ctx.beginPath()
        ctx.rect(x, y, size, size)
        ctx.stroke() if options.stroke
        ctx.fill()   if options.current(value, v)
        options.ondraw(value, ctx, init, v, x, y, size)
    true


$.fn.selector_palette = (area) ->
  choices = []
  choices.push(n) for n of area.palettes
  return @hide() if not choices.length

  colsize = floor(@[0].height / @[0].width)
  colsize = max(colsize, v.length + 2) for n, v of area.palettes
  current = max(0, choices.indexOf area.palette)
  palette = []

  setPalette = (p) =>
    palette.splice 0, palette.length
    palette.push(-1)
    palette.push(cx) for cx in  area.palettes[p]
    palette.push(+0) for _  in [area.palettes[p].length...colsize - 2]
    palette.push(+1)
    @tooltip('destroy').tooltip(title: p, placement: 'bottom').tooltip('show')
  setPalette(choices[current])

  @selector_discrete area,
    colsize: colsize
    initial: {H: area.tool.options.H, S: area.tool.options.S, L: area.tool.options.L}
    choices: palette
    current: (value, color) -> false  # no point in highlighting a color
    change:  (value, color) -> switch color
      when -1 then setPalette(area.palette = choices[--current]) if current > 0
      when +1 then setPalette(area.palette = choices[++current]) if current < choices.length - 1
      when +0 then null
      else jQuery.extend value, color

    ondraw: (value, ctx, init, color, x, y, size) -> switch color
      when -1, 0, +1
        ctx.lineWidth = 3
        ctx.beginPath()
        ctx.moveTo(x + size * 0.3, y + size * (0.5 - 0.1 * color))
        ctx.lineTo(x + size * 0.5, y + size * (0.5 + 0.1 * color))
        ctx.lineTo(x + size * 0.7, y + size * (0.5 - 0.1 * color))
        ctx.stroke()
      else
        ctx.fillStyle = "hsl(#{color.H},#{color.S}%,#{color.L}%)"
        ctx.fill()


$.fn.selector_tools = (area) -> @each ->
  reduced = [
    Canvas.Tool.Selection.Rect,
    area.tool.options.last,
    Canvas.Tool.Eraser,
    Canvas.Tool.Colorpicker
  ]

  $(@).selector_discrete area,
    stroke:  true
    initial: area.tool.constructor
    choices: if $(@).hasClass('small') then reduced else area.tools
    current: (value, tool) -> value.kind is tool
    ondraw:  (value, ctx, init, tool, x, y, size) ->
      t = new tool(area, {size: size * 9 / 20, H: 0, S: 0, L: 80, opacity: 0.75})
      t.symbol ctx, x + size / 2, y + size / 2

    change: (value, tool) ->
      value.kind = tool
      value.last = tool if tool isnt area.tool.constructor and reduced.indexOf(tool) == -1
      reduced[1] = value.last if value.last


$.fn.selector_modal = (x, y, fixed) ->
  @css 'left', x
  @css 'top',  y
  @addClass 'fixed' if fixed
  $('<div class="cover selector">').append(@).hide().fadeIn(100)


$.fn.selector_main = (area, x, y, fixed) ->
  t = @clone()
  color = t.find('.selector-color').selector_color(area)
  width = t.find('.selector-width').selector_width(area)
  tools = t.find('.selector-tools').selector_tools(area)
  space = t.find('.selector-spacing').selector_spacing(area)
  trans = t.find('.selector-opacity').selector_opacity(area)
  clset = t.find('.selector-palette').selector_palette(area)

  t.find('.either').each ->
    self = $(@)
    self.find('.selector:not(:eq(0))').hide()

    link = self.find('.selector-switch')
    link.find('.selector-switch').each -> $(@).css('font-size', $(@).innerHeight() * 0.75)

    link.append($('<option>').attr('value', $(el).attr('class')).text($(el).attr('data-name'))) \
      for el in self.find('.selector')

    link.on 'change', ->
      x = self.find(".selector[class='#{@value}']")
      y = self.find('.selector')
      if x.length
        y.hide()
        x.show()
      @value = $(@).children().eq(0).val() or $(@).children().eq(0).text()

  width.on 'change', (_, value) -> area.setToolOptions(value)
  space.on 'change', (_, value) -> area.setToolOptions(value)
  trans.on 'change', (_, value) -> area.setToolOptions(value)
  color.on 'change', (_, value) -> area.setToolOptions(value)
  clset.on 'change', (_, value) -> area.setToolOptions(value)
  tools.on 'change', (_, value) -> area.setToolOptions(value)
  tools.on 'change', -> width.trigger('redraw'); space.trigger('redraw'); trans.trigger('redraw')
  clset.on 'change', -> color.trigger('redraw', [true])
  t.selector_modal(x, y, fixed)


$.fn.selector_export = (area, x, y, fixed) ->
  t = @clone()
  t.on 'click', 'a[data-type]', (ev) ->
    type = $(@).attr 'data-type'
    link = document.createElement 'a'
    link.download = 'image.' + type
    link.href     = area.export(type)
    link.click()
  t.selector_modal(x, y, fixed)


$.fn.selector_dynamics = (area, x, y, fixed) ->
  t = @clone()
    .on 'change', '[data-option="type"]', ->
      self = $(@).parents('[data-kind]')
      data = self.data('dynamic')

      if data and not @value
        i = area.tool.options.dynamic.indexOf(data)
        _ = area.tool.options.dynamic.splice(i, 1)
        return self.data('dynamic', null)
      if not data and @value
        data = new OptionDynamic kind: self.attr('data-kind')
        self.data('dynamic', data)
        self.find('[data-option]').trigger('change')
        area.tool.options.dynamic.push(data)

    .on 'change', '[data-option]', ->
      value = if @getAttribute('data-raw') is null then parseFloat @value else @value
      data = $(@).parents('[data-kind]').data('dynamic')
      data[@getAttribute 'data-option'] = value if data

  for dyn in area.tool.options.dynamic
    elem = t.find("[data-kind='#{dyn.kind}']")
    elem.data('dynamic', dyn)
    elem.find('[data-option]').each -> @value = dyn[@getAttribute 'data-option']

  t.selector_modal(x, y, fixed)


$.fn.selector_layers = (area, template) ->
  @append '<li class="hidden">'

  @on 'click', 'li', (ev) ->
    ev.preventDefault()
    if area.layer == $(@).index() then $(@).trigger 'contextmenu' else area.setLayer $(@).index()

  @on 'contextmenu', 'li', (ev) ->
    ev.preventDefault()
    if not $(@).data('no-layer-menu')
      index  = $(@).index()
      offset = $(@).offset()
      $(template).selector_layer_config(area, index, offset.left, offset.top, true).appendTo('body')
    $(@).removeData('no-layer-menu')

  @on 'mousedown touchstart', 'li', (ev) ->
    # This will make stuff work with both touchscreens and mice.
    _getY = (ev) -> (ev.originalEvent.touches?[0] or ev).pageY
    _getC = (ev) -> ev.originalEvent.touches?.length or ev.which
    return if _getC(ev) != 1

    body = $('body')
    elem = $(@).removeData('no-layer-menu')

    deltaC = 15
    startC = _getY(ev)
    startP = elem.position().top
    offset = null

    h1 = (ev) ->
      # Another touch/click detected, abort. (If `_getC` returns the same value,
      # though, that's the initial event. We need to ignore it.)
      h3(ev) if _getC(ev) > 1

    h2 = (ev) ->
      if offset is null and abs(_getY(ev) - startC) > deltaC
        offset = 0
        elem.addClass 'dragging'
      if offset isnt null
        offset = _getY(ev) - startC
        elem.css 'top', offset + startP

    h3 = (ev) ->
      body.off 'mousedown touchstart', h1
      body.off 'mousemove touchmove',  h2
      body.off 'mouseup   touchend',   h3

      if offset isnt null and _getC(ev) <= 1
        elem.data('no-layer-menu', true)
        elem.parent().children().each (i) ->
          if i != elem.index() and $(@).hasClass('hidden') or offset + startP < $(@).position().top
            area.moveLayer(elem.index(), i - elem.index() - (i >= elem.index()))
            # Stop iterating.
            return false
          return true

      elem.css('top', '')
      elem.removeClass('dragging')

    body.on 'mousedown touchstart', h1
    body.on 'mousemove touchmove',  h2
    body.on 'mouseup   touchend',   h3

  area.on 'layer:add', (layer, index) =>
    entry = $ '<li><canvas></canvas></li>'
    entry.insertBefore @children().eq(index)

  area.on 'layer:resize', (layer, index) =>
    sz = 150 / max(layer.w, layer.h)
    canvas = @children().eq(index).find('canvas')
    canvas.attr(width: layer.w * sz, height: layer.h * sz)

  area.on 'layer:redraw', (layer, index) =>
    cnv = @children().eq(index).find('canvas')
    cnv.each ->
      ctx = @getContext('2d')
      ctx.globalCompositeOperation = "copy"
      ctx.drawImage layer.img(), 0, 0, @width, @height

  area.on 'layer:set',    (index)    => @children().removeClass('active').eq(index).addClass('active')
  area.on 'layer:del',    (index)    => @children().eq(index).remove()
  area.on 'layer:move',   (index, d) => @children().eq(index).detach().insertBefore @children().eq(index + d)


$.fn.selector_layer_config = (area, index, x, y, fixed) ->
  t = @clone()
  t.on 'change', '[data-prop]', ->
    area.snap index: index
    area.layers[index][@getAttribute 'data-prop'] =
      if @type == "checkbox" then @checked else @value
  t.find('[data-prop]').each ->
    @checked = @value = area.layers[index][@getAttribute 'data-prop']
    return true
  t.selector_modal(x, y, fixed)
