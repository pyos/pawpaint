"use strict";


class CanvasSelector
{
    // select(x, y)
    // redraw()

    constructor(e, area, linked, draggable)
    {
        this.element = e;
        this.area    = area;

        const click = (ev) =>
        {
            const r = e.getBoundingClientRect();
            this.select(ev.clientX - r.left, ev.clientY - r.top);
            this.redraw();
            for (const selector of linked) selector.redraw();
        };

        const touch = (ev) => { if (ev.touches.length === 1) { ev.preventDefault(); click(ev.touches[0]); } };
        const mouse = (ev) => { if (ev.which === 1) { ev.preventDefault(); click(ev); } };

        e.addEventListener('mousedown',  mouse);
        e.addEventListener('touchstart', touch);

        if (draggable) {
            e.addEventListener('mousedown',  () => e.addEventListener('mousemove', mouse));
            e.addEventListener('touchstart', () => e.addEventListener('touchmove', touch));
            e.addEventListener('mouseup', () => e.removeEventListener('mousemove', mouse));
            e.addEventListener('touchend',() => e.removeEventListener('touchmove', mouse));
        }
    }
}


class ColorSelector extends CanvasSelector
{
    constructor(e, area, linked)
    {
        super(e, area, linked, true);
        this.hueOuterR = Math.min(e.width, e.height) / 2;
        this.hueInnerR = 3 / 4 * this.hueOuterR;
        this.satRadius = 5 / 6 * this.hueInnerR;

        const ctx = this.element.getContext('2d');
        ctx.save();
        ctx.scale(this.hueOuterR, this.hueOuterR);
        ctx.translate(1, 1);

        const dr = Math.PI / 4;
        const di = 45;  // rad_to_deg(dr)

        for (let i = 0, r = 0; i < 360; i += di) {
            var grad = ctx.createLinearGradient(Math.cos(r), Math.sin(r), Math.cos(r + dr), Math.sin(r + dr));
            grad.addColorStop(0, `hsl(${i},      100%, 50%)`);
            grad.addColorStop(1, `hsl(${i + di}, 100%, 50%)`);
            ctx.beginPath();
            ctx.arc(0, 0, 1, r, r += dr);
            ctx.lineTo(0, 0);
            ctx.fillStyle = grad;
            ctx.fill();
        }

        ctx.restore();
        this.redraw();
    }

    select(x, y)
    {
        const satHeight = this.satRadius * 1.5;
        const satSide   = this.satRadius * Math.sqrt(3);

        x -= this.hueOuterR;
        y -= this.hueOuterR;

        if (this.hueInnerR * this.hueInnerR > x * x + y * y) {
            const a = -this.area.tool.options.H * Math.PI / 180;
            const St = (x * Math.cos(a) - y * Math.sin(a)) / satHeight + 1/3;
            const Lt = (x * Math.sin(a) + y * Math.cos(a)) / satSide   + 1/2;
            const S = 100 * Math.min(1, Math.max(0, St / Math.abs(1 - Math.abs(Lt * 2 - 1))));
            const L = 100 * Math.min(1, Math.max(0, Lt));
            this.area.setToolOptions({ S, L });
        } else
            this.area.setToolOptions({ H: Math.atan2(y, x) * 180 / Math.PI });
    }

    redraw()
    {
        const satHeight = this.satRadius * 1.5;
        const satSide   = this.satRadius * Math.sqrt(3);
        const ctx       = this.element.getContext('2d');

        ctx.save();
        ctx.translate(this.hueOuterR, this.hueOuterR);
        ctx.beginPath();
        ctx.arc(0, 0, this.hueInnerR, 0, Math.PI * 2, false);
        ctx.clip();
        ctx.clearRect(-this.hueInnerR, -this.hueInnerR, this.hueInnerR * 2, this.hueInnerR * 2);

        ctx.rotate(this.area.tool.options.H * Math.PI / 180);
        ctx.translate(-this.satRadius / 2, 0);
        ctx.beginPath();
        ctx.moveTo(0, -satSide / 2);
        ctx.lineTo(0, +satSide / 2);
        ctx.lineTo(satHeight, 0);
        ctx.closePath();

        {
            const grad = ctx.createLinearGradient(0, -satSide / 4, satHeight, 0);
            grad.addColorStop(0, "#000");
            grad.addColorStop(1, `hsl(${this.area.tool.options.H}, 100%, 50%)`);
            ctx.fillStyle = grad;
            ctx.fill();
        }

        {
            const grad = ctx.createLinearGradient(0, +satSide / 2, satHeight / 2, -satSide / 4);
            grad.addColorStop(0, "rgba(255, 255, 255, 1)");
            grad.addColorStop(1, "rgba(255, 255, 255, 0)");
            ctx.fillStyle = grad;
            ctx.fill();
        }

        const y = this.area.tool.options.L / 100 - 1/2;
        const x = this.area.tool.options.S / 100 * Math.abs(1 - Math.abs(y * 2));

        ctx.lineWidth   = 1.5;
        ctx.fillStyle   = "#000";
        ctx.strokeStyle = "#fff";
        ctx.beginPath();
        ctx.arc(x * satHeight, y * satSide, 3, 0, 2 * Math.PI);
        ctx.fill();
        ctx.stroke();
        ctx.restore();
    }
}


class BarSelector extends CanvasSelector
{
    // get value -> [0..1]
    // set value <- [0..1]

    constructor(e, area, linked)
    {
        super(e, area, linked, true);
        this.redraw();
    }

    select(x, y)
    {
        this.value = 1 - Math.max(0, Math.min(1, y / this.element.height * 10 / 9 - 1 / 18));
    }

    redraw()
    {
        const ctx = this.element.getContext('2d');
        const y   = (1 - this.value + 1 / 18) * this.element.height * 9 / 10;
        ctx.clearRect(0, 0, this.element.width, this.element.height);
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(this.element.width, y);
        ctx.lineWidth = 2;
        ctx.strokeStyle = '#7f7f7f';
        ctx.stroke();
    }
}


class SizeSelector extends BarSelector
{
    get value( ) { return Math.sqrt((this.area.tool.options.size - 1) / this.element.height); }
    set value(v) { this.area.setToolOptions({ size: v * v * this.element.height + 1 }); }

    redraw()
    {
        super.redraw();
        const ctx = this.element.getContext('2d');
        ctx.save();
        ctx.translate(this.element.width / 2, this.element.height / 2);
        this.area.tool.crosshair(ctx);
        ctx.restore();
    }
}


class ItemSelector extends CanvasSelector
{
    // selectItem(i)
    // redrawItem(i, context2d, x, y)

    constructor(e, area, linked)
    {
        super(e, area, linked);
        this.number = 0;
        this.height = Math.min(e.height / 4, e.width);
    }

    select(x, y)
    {
        const i = Math.floor(x / this.height) * Math.floor(this.element.height / this.height)
                + Math.floor(y / this.height);
        this.selectItem(i);
    }

    redraw()
    {
        const ctx = this.element.getContext('2d');
        const qty = Math.floor(this.element.height / this.height);
        ctx.clearRect(0, 0, this.element.width, this.element.height);

        for (let i = 0; i < this.number; i++) {
            const x = Math.floor(i / qty) * this.height;
            const y = Math.floor(i % qty) * this.height;
            ctx.beginPath();
            ctx.rect(x, y, this.height, this.height);
            ctx.strokeStyle = "#444";
            ctx.fillStyle   = "rgba(127,127,127,0.3)";
            this.redrawItem(i, ctx, x, y);
        }
    }
}


class PaletteSelector extends ItemSelector
{
    constructor(e, area, linked)
    {
        super(e, area, linked);

        for (const p of area.palettes)
            this.height = Math.min(this.height, e.height / (p.colors.length + 2));

        this.number = Math.floor(e.height / this.height);

        if (area.palettes.length === 0)
            e.style.display = 'none';
        else
            this.redraw();
    }

    selectItem(i)
    {
        if (i === 0) {
            if (this.area.palette !== 0)
                this.area.palette--;
        } else if (i === this.number - 1) {
            if (this.area.palette !== this.area.palettes.length - 1)
                this.area.palette++;
        } else  {
            const p = this.area.palettes[this.area.palette];

            if (i <= p.colors.length)
                this.area.setToolOptions(p.colors[i - 1]);

            return;
        }

        $(this.element).tooltip('destroy')
                       .tooltip({ title: this.area.palettes[this.area.palette].name, placement: 'bottom' })
                       .tooltip('show');
    }

    redrawItem(i, ctx, x, y)
    {
        const p = this.area.palettes[this.area.palette];

        if (i === 0 || i > p.colors.length) {
            const q = i === 0 ? -1 : i === this.number - 1 ? +1 : 0;
            ctx.beginPath();
            ctx.moveTo(x + this.height * 0.3, y + this.height * (0.5 - 0.1 * q));
            ctx.lineTo(x + this.height * 0.5, y + this.height * (0.5 + 0.1 * q));
            ctx.lineTo(x + this.height * 0.7, y + this.height * (0.5 - 0.1 * q));
            ctx.lineWidth = 3;
            ctx.stroke();
        } else {
            ctx.fillStyle = `hsl(${p.colors[i - 1].H},${p.colors[i - 1].S}%,${p.colors[i - 1].L}%)`;
            ctx.fill();
        }
    }
}


class ToolSelector extends ItemSelector
{
    constructor(e, area, linked)
    {
        super(e, area, linked);
        this.tools  = e.classList.contains('small') ? this.smallSubset : this.area.tools;
        this.number = this.tools.length;
        this.redraw();
    }

    get smallSubset()
    {
        return [RectSelectionTool, this.area.tool.options.last, EraserTool, ColorpickerTool];
    }

    selectItem(i)
    {
        const tool = this.tools[i];

        if (tool === undefined || tool === this.area.tool.options.kind)
            return;

        if (this.smallSubset.indexOf(tool) === -1)
            this.area.setToolOptions({ kind: tool, last: tool });
        else
            this.area.setToolOptions({ kind: tool });
    }

    redrawItem(i, ctx, x, y)
    {
        ctx.stroke();

        if (this.tools[i] === this.area.tool.options.kind)
            ctx.fill();

        const size = this.height;
        const tool = new this.tools[i](null, { size: size * 9 / 20, L: 80, opacity: 0.75 });
        tool.symbol(ctx, x + size / 2, y + size / 2);
    }
}


$.fn.selector_modal = function (x, y, fixed)
{
    return this.css('left', x).appendTo('<div class="cover selector">')
               .css('top',  y).addClass(fixed ? 'fixed' : 'floating').parent();
};


$.fn.selector_main = function (area, x, y, fixed)
{
    const t = this.clone();
    const color   = t.find('.selector-color')   .toArray().map((v) => new ColorSelector   (v, area, []));
    const palette = t.find('.selector-palette') .toArray().map((v) => new PaletteSelector (v, area, color));
    const size    = t.find('.selector-size')    .toArray().map((v) => new SizeSelector    (v, area, []));
    const tool    = t.find('.selector-tool')    .toArray().map((v) => new ToolSelector    (v, area, size));
    return t.selector_modal(x, y, fixed);
};


$.fn.selector_save = function (area, x, y, fixed)
{
    return this.clone().on('click', 'a[data-type]', function (ev) {
        const type = this.getAttribute('data-type');
        const link = document.createElement('a');
        link.download = 'image.' + type;
        link.href     = area.export(type);
        link.click();
    }).selector_modal(x, y, fixed);
};


$.fn.selector_layers = function (area, template)
{
    const button = (ev) =>
        ev.originalEvent.touches ? ev.originalEvent.touches.length : ev.button;

    const position = (ev) =>
        ev.originalEvent.touches ? ev.originalEvent.touches[0].pageY : ev.pageY;

    this.append("<li>");

    this.on('contextmenu', 'li', function (ev) {
        const index  = $(this).index();
        const offset = $(this).offset();
        $(template).selector_layer_config(area, index, offset.left, offset.top, true).appendTo('body');
        return false;
    });

    this.on('mousedown touchstart', 'li', function (ev) {
        const elem  = $(this);
        const index = elem.index();
        const pageY = elem.position().top;
        const body  = $(document.body);

        let offset = 0;
        let start  = position(ev);

        const drag = (ev) => {
            offset = position(ev) - start;
            elem.css('position', 'relative').css('top', offset);
        };

        const abort = (ev) => {
            if (button(ev) > 1) {
                body.off('mousedown touchstart', abort);
                body.off('mousemove touchmove',  drag);
                body.off('mouseup   touchend',   drop);
                elem.css('position', 'static').css('top', '');
                return false;
            }
        };

        const drop = (ev) => {
            body.off('mousedown touchstart', abort);
            body.off('mousemove touchmove',  drag);
            body.off('mouseup   touchend',   drop);

            let shift = 0;

            elem.parent().children().each((i, it) => {
                if (i != index && $(it).position().top > pageY + offset) {
                    shift = i - index - (i >= index);
                    return false;
                }

                return true;
            });

            elem.css('position', 'static').css('top', '');

            if (shift !== 0)
                area.moveLayer(index, shift);
            else if (index !== area.layer)
                area.setLayer(index);
            else
                elem.trigger('contextmenu');

            return false;
        };

        body.on('mousedown touchstart', abort);
        body.on('mousemove touchmove',  drag);
        body.on('mouseup   touchend',   drop);
    });

    area.on('layer:add', (layer, index) => {
            const entry = $('<li><canvas></canvas></li>');
            entry.insertBefore(this.children().eq(index));
        })
        .on('layer:resize', (layer, index) => {
            const scale = 150 / Math.max(layer.w, layer.h);
            const canvas = this.children().eq(index).find('canvas')[0];
            canvas.width  = layer.w * scale;
            canvas.height = layer.h * scale;
        })
        .on('layer:redraw', (layer, index) => {
            const canvas = this.children().eq(index).find('canvas')[0];
            const ctx    = canvas.getContext('2d');
            ctx.globalCompositeOperation = 'copy';
            ctx.drawImage(layer.img(), 0, 0, canvas.width, canvas.height);
        })

        .on('layer:set',  (index) => this.children().removeClass('active').eq(index).addClass('active'))
        .on('layer:del',  (index) => this.children().eq(index).remove())
        .on('layer:move', (i, di) => this.children().eq(i).detach().insertBefore(this.children().eq(i + di)));

    return this;
};


$.fn.selector_layer_config = function (area, index, x, y, fixed)
{
    const tmpl = this.clone();

    tmpl.find('[data-prop]')
        .each(function () { this.checked = this.value = area.layers[index][this.getAttribute('data-prop')]; })
        .on('change', function () {
            area.snap({ index });
            area.layers[index][this.getAttribute('data-prop')] =
                this.type == 'checkbox' ? this.checked : this.value;
        });

    return tmpl.selector_modal(x, y, fixed);
};
