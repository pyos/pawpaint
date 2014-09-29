---
---

$.fn.selector_canvas = (area, value, update, redraw) ->
  _updateT = (ev) -> ev.preventDefault(); _update.call @, ev.originalEvent.touches[0]
  _updateM = (ev) -> ev.preventDefault(); _update.call @, ev
  _update  = (t) ->
    update.call(@, value, t.clientX - $(@).offset().left, t.clientY - $(@).offset().top)
    $(@).trigger('change', [value])
        .trigger('redraw')

  @on 'redraw', -> redraw.call(@, value, @getContext('2d'))
  @on 'mousedown',  (ev) -> $(@).on  'mousemove', _updateM; _updateM.call @, ev
  @on 'touchstart', (ev) -> $(@).on  'touchmove', _updateT; _updateT.call @, ev
  @on 'touchend',   (ev) -> $(@).off 'touchmove'
  @on 'mouseup',    (ev) -> $(@).off 'mousemove'
  @on 'click', (ev) ->
    # Prevent these clicks from going through and dismissing
    # dialogs and stuff.
    ev.stopPropagation()
  return @each -> redraw.call(@, value, @getContext('2d'), true)


$.fn.selector_color = (area) ->
  @each ->
    @outerR = min(@width, @height) / 2
    @innerR = 30 / 40 * @outerR
    @triagR = 26 / 40 * @outerR
    @triagA = sqrt(3) * @triagR
    @triagH = sqrt(3) * @triagA / 2

  @selector_canvas area, {H: area.tool.options.H, S: area.tool.options.S, L: area.tool.options.L},
    (value, x, y) ->
      x -= @outerR
      y -= @outerR

      if pow(@innerR, 2) <= pow(x, 2) + pow(y, 2)
        # Got a click inside the ring.
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
        ctx.save()
        steps = 10
        delta = 2 * PI / steps

        for i in [0...steps]
          grad = ctx.fillStyle = ctx.createLinearGradient(@outerR, 0, @outerR * cos(delta), @outerR * sin(delta))
          grad.addColorStop 0, "hsl(#{i * 36},      100%, 50%)"
          grad.addColorStop 1, "hsl(#{i * 36 + 36}, 100%, 50%)"
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
      value[opt] = v = max(0, min(1, (@height - y - @margin) / (@height - 2 * @margin))) * (@high - @low) + @low
      value[opt] = floor v unless options.float

    (value, ctx, init) ->
      ctx.save()
      ctx.clearRect(0, 0, @width, @height)
      ctx.translate(@width / 2, @height / 2)
      tool = new area.tool.constructor(area.tool.options)
      tool.setOptions dynamic: [], opacity: 0.5, H: 0, S: 0, L: 50, size: @width * 0.75
      tool.setOptions value
      ondraw?.call this, value, ctx, init, tool
      ctx.restore()

      y = (@high - value[opt]) * (@height - 2 * @margin) / (@high - @low) + @margin
      ctx.lineWidth = 2
      ctx.strokeStyle = "rgba(127, 127, 127, 0.7)"
      ctx.beginPath()
      ctx.moveTo(0, floor y)
      ctx.lineTo(@width, floor y)
      ctx.stroke()


$.fn.selector_width = (area) -> @selector_vertical area,
  what:   'size'
  ondraw: (value, ctx, init, tool) ->
    tool.crosshair ctx


$.fn.selector_spacing = (area) -> @selector_vertical area,
  min: -> 1
  max: -> @low + @height / 2
  what:   'spacing'
  ondraw: (value, ctx, init, tool) ->
    tool.start ctx, 0, -@height * 0.4, 1, 0
    tool.move  ctx, 0,  @height * 0.4, 1, 0
    tool.stop  ctx, 0,  @height * 0.4


$.fn.selector_opacity = (area) -> @selector_vertical area,
  float: true
  min: -> 0
  max: -> 1
  what: 'opacity'
  ondraw: (value, ctx, init, tool) ->
    tool.start ctx, 0, 0, 1, 0
    tool.move  ctx, 0, 1, 1, 0
    tool.stop  ctx, 0, 1


$.fn.selector_tools = (area) ->
  @each ->
    @cellS = @height / 4
    @cellY = floor @height / @cellS

  @selector_canvas area, {kind: area.tool.constructor},
    (value, x, y) ->
      kind = area.tools[floor(x / @cellS) * @cellY + floor(y / @cellS)]
      value.kind = kind if kind

    (value, ctx, init) ->
      ctx.clearRect(0, 0, @width, @height)
      ctx.strokeStyle = "#444"
      ctx.fillStyle   = "rgba(127, 127, 127, 0.3)"

      for i, tool of area.tools
        x = (floor(i / @cellY) + 0.5) * @cellS
        y = (floor(i % @cellY) + 0.5) * @cellS

        ctx.beginPath()
        ctx.rect(x - @cellS / 2, y - @cellS / 2, @cellS, @cellS)
        ctx.stroke()
        ctx.fill() if tool is value.kind

        t = new tool({size: @cellS * 9 / 20, H: 0, S: 0, L: 80, opacity: 0.75})
        t.symbol ctx, x, y


$.fn.selector_button = (area, ctor, template) ->
  @on 'click', (ev) ->
    if ev.which == 1
      ctor.call($(template), area, $(@).offset().left, $(@).offset().top, true).appendTo('body')


$.fn.selector_modal = (x, y, fixed) ->
  @css 'left', x
  @css 'top',  y
  @addClass 'fixed' if fixed
  cover = $('<div class="cover selector">').append(@).hide().fadeIn(100)
  cover.on 'click', -> cover.fadeOut(100, cover.remove.bind cover)


$.fn.selector_main = (area, x, y, fixed) ->
  t = @clone().on 'click', (ev) -> ev.stopPropagation()
  color = t.find('.selector-color').selector_color(area)
  width = t.find('.selector-width').selector_width(area)
  tools = t.find('.selector-tools').selector_tools(area)
  space = t.find('.selector-spacing').selector_spacing(area)
  trans = t.find('.selector-opacity').selector_opacity(area)

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
  tools.on 'change', (_, value) -> area.setTool(value.kind, area.tool.options)
  tools.on 'change', -> width.trigger('redraw'); space.trigger('redraw'); trans.trigger('redraw')
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
  funcs = Canvas.Dynamic
  types = Canvas.Dynamic.prototype

  t = @clone()
    .on 'click', (ev) -> ev.stopPropagation()
    .on 'change', '.comp', ->
      self = $(@).parents('.item')
      data = self.data('dynamic')
      data.options.fn = funcs[@value] if data and @value

      if data and not @value
        i = area.tool.options.dynamic.indexOf(data)
        _ = area.tool.options.dynamic.splice(i, 1)
        return self.data('dynamic', null)
      else if not data
        data = new Canvas.Dynamic.Option
          source: self.attr('data-source')
          target: self.attr('data-target')
          tgcopy: self.attr('data-tgcopy')
          kind  : self.attr('data-kind')
        self.data('dynamic', data)
        self.find('.comp, .type, .min, .max').trigger('change')
        area.tool.options.dynamic.push(data)

    .on 'change', '.type', ->
      data = $(@).parents('.item').data('dynamic')
      data.options.type = types[@value] if data

    .on 'change', '.min', ->
      data = $(@).parents('.item').data('dynamic')
      if data
        data.options.k += data.options.a
        data.options.a  = parseFloat @value
        data.options.k -= data.options.a

    .on 'change', '.max', ->
      data = $(@).parents('.item').data('dynamic')
      data.options.k = parseFloat @value - data.options.a if data

  for dyn in area.tool.options.dynamic
    elem = t.find "[data-kind='#{dyn.options.kind}']"
    for x, f of funcs then elem.find('.comp').val x if f is dyn.options.fn
    for x, f of types then elem.find('.type').val x if f is dyn.options.type
    elem.find('.min').val(dyn.options.a)
    elem.find('.max').val(dyn.options.k + dyn.options.a)
    elem.data('dynamic', dyn)

  t.selector_modal(x, y, fixed)


$.fn.selector_layers = (area, template) ->
  @append '<li class="hidden">'

  @on 'click', 'li', (ev) ->
    ev.preventDefault()
    if area.layer == $(@).index() then $(@).trigger 'contextmenu' else area.changeLayer $(@).index()

  @on 'contextmenu', 'li', (ev) ->
    ev.preventDefault()
    if not $(@).data('no-layer-menu')
      index  = $(@).index()
      offset = $(@).offset()
      $(template).selector_layer_config(area, index, offset.left, offset.top, true).appendTo('body')
    $(@).removeData('no-layer-menu')

  area.element
    .on 'layer:add', (_, canvas, index) =>
      sz = 150 / max(canvas.width, canvas.height)
      entry = $ '<li class="background">'
      entry.addClass 'disabled' if canvas.style.display == 'none'
      entry.append new Canvas floor(canvas.width * sz), floor(canvas.height * sz)
      entry.insertBefore @children().eq(index)

    .on 'layer:resize', (_, canvas, index) =>
      sz = 150 / max(canvas.width, canvas.height)
      entry = @children().eq(index).find('canvas')
      entry.replaceWith new Canvas canvas.width * sz, canvas.height * sz

    .on 'layer:redraw', (_, canvas, index) =>
      cnv = @children().eq(index).find('canvas')
      cnv.each ->
        ctx = @getContext('2d')
        ctx.clearRect         0, 0, @width, @height
        ctx.drawImage canvas, 0, 0, @width, @height

    .on 'layer:set',    (_, index)    => @children().removeClass('active').eq(index).addClass('active')
    .on 'layer:del',    (_, index)    => @children().eq(index).remove()
    .on 'layer:move',   (_, index, d) => @children().eq(index).detach().insertBefore @children().eq(index + d)
    .on 'layer:toggle', (_, index)    => @children().eq(index).toggleClass('disabled')


$.fn.selector_layer_config = (area, index, x, y, fixed) ->
  layer = area.layers[index]

  t = @clone()
  t.on 'click', (ev) -> ev.stopPropagation()
   .on 'change', '[data-css]', ->
    expect = @value

    if @getAttribute('type') == 'checkbox'
      invert = !!@getAttribute('data-invert')
      func   =   @getAttribute('data-func')
      expect = if @checked == invert then @getAttribute('data-null') or '' else @value
      return area[func](index) if expect != layer.css @getAttribute('data-css') if func

    layer.css @getAttribute('data-css'), @value

  t.find('[data-css]').each ->
    if @getAttribute('type') == 'checkbox'
      @checked = (layer.css(@getAttribute('data-css')) == @value) == !@getAttribute('data-invert')
    else
      @value = layer.css(@getAttribute('data-css')) or @value
    # `false` breaks iteration. `@checked` may be `false`. You get the idea.
    return true
  t.selector_modal(x, y, fixed)
