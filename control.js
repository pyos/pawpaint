"use strict";


class CanvasControl
{
    select(x, y) {}
    redraw() {}

    constructor(e, area, linked, draggable)
    {
        this.element = e;
        this.area    = area;

        const click = (ev) =>
        {
            const r = e.getBoundingClientRect();
            this.select(ev.clientX - r.left, ev.clientY - r.top);
            this.redraw();
            if (linked !== undefined) for (let control of linked) control.redraw();
        };

        const touch = (ev) => { if (ev.touches.length === 1) click(ev.touches[0]); };
        const mouse = (ev) => { if (ev.which === 1) click(ev); };

        if (draggable) {
            e.addEventListener('mousedown',  (ev) => { ev.preventDefault(); e.addEventListener('mousemove', mouse); mouse(ev); });
            e.addEventListener('touchstart', (ev) => { ev.preventDefault(); e.addEventListener('touchmove', touch); touch(ev); });
            e.addEventListener('mousemove',  (ev) =>   ev.preventDefault());
            e.addEventListener('touchmove',  (ev) =>   ev.preventDefault());
            e.addEventListener('mouseup',    (ev) => { ev.preventDefault(); e.removeEventListener('mousemove', mouse); });
            e.addEventListener('touchend',   (ev) => { ev.preventDefault(); e.removeEventListener('touchmove', mouse); });
        } else
            e.addEventListener('click', click);
    }
}


class ColorControl extends CanvasControl
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

        ctx.globalCompositeOperation = 'destination-out';
        ctx.beginPath();
        ctx.arc(0, 0, this.hueInnerR / this.hueOuterR, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
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
            const S = 100 * Math.min(1, Math.max(0, St / (1 - Math.abs(Lt * 2 - 1))));
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
        ctx.arc(0, 0, this.hueInnerR - 1, 0, Math.PI * 2, false);
        ctx.clip();
        ctx.clearRect(-this.hueInnerR, -this.hueInnerR, this.hueInnerR * 2, this.hueInnerR * 2);

        ctx.rotate(this.area.tool.options.H * Math.PI / 180);
        ctx.translate(-this.satRadius / 2, 0);

        ctx.beginPath();
        ctx.moveTo(0, -satSide / 2);
        ctx.lineTo(0, +satSide / 2);
        ctx.lineTo(satHeight, 0);
        ctx.fillStyle = `hsl(${this.area.tool.options.H}, 100%, 50%)`;
        ctx.fill();

        {
            const grad = ctx.createLinearGradient(0, -satSide / 2, satHeight, 0);
            grad.addColorStop(0, 'rgba(0, 0, 0, 1)');
            grad.addColorStop(1, 'rgba(0, 0, 0, 0)');
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


class BarControl extends CanvasControl
{
    // get title -> String
    // get value -> [0..1]
    // set value <- [0..1]

    constructor(e, area, linked)
    {
        super(e, area, linked, true);
    }

    get vertical () { return this.element.height >= this.element.width; }
    get length   () { return this.vertical ? this.element.height : this.element.width;  }

    select(x, y)
    {
        this.value = Math.max(0, Math.min(1, (this.vertical ? this.length - y : x) / this.length * 10 / 9 - 1 / 18));
    }

    redraw()
    {
        const ctx = this.element.getContext('2d');
        ctx.font        = '14px Helvetica';
        ctx.lineWidth   = 3;
        ctx.fillStyle   = '#aaa';
        ctx.strokeStyle = '#aaa';
        ctx.clearRect(0, 0, this.element.width, this.element.height);
        ctx.beginPath();
        if (this.vertical) {
            const y = 0.5 + (19 / 18 - this.value) * this.element.height * 9 / 10;
            ctx.fillText(this.title, 5.5, y - 5);
            ctx.moveTo(0.5, y);
            ctx.lineTo(0.5 + this.element.width, y);
        } else {
            const x = 0.5 + (1  / 18 + this.value) * this.element.width * 9 / 10;
            ctx.fillText(this.title, x + 5, this.element.height - 4.5);
            ctx.moveTo(x, 0.5);
            ctx.lineTo(x, 0.5 + this.element.height);
        }
        ctx.stroke();
    }
}


class SizeControl extends BarControl
{
    get title( ) { return Math.round(this.area.tool.options.size); }
    get value( ) { return Math.sqrt((this.area.tool.options.size - 1) / this.length); }
    set value(v) { this.area.setToolOptions({ size: v * v * this.length + 1 }); }

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


class ItemControl extends CanvasControl
{
    selectItem(i) {}
    redrawItem(i, context2d, x, y) {}

    constructor(e, area, linked)
    {
        super(e, area, linked);
        this.number = 0;
        this.height = Math.min(e.height, e.width);

        if (e.getAttribute('data-item-height'))
            this.height = parseInt(e.getAttribute('data-item-height'));
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
        ctx.save();
        ctx.clearRect(0, 0, this.element.width, this.element.height);
        ctx.translate(0.5, 0.5);

        for (let i = 0; i < this.number; i++) {
            const x = Math.floor(i / qty) * this.height;
            const y = Math.floor(i % qty) * this.height;
            ctx.beginPath();
            ctx.rect(x, y, this.height, this.height);
            this.redrawItem(i, ctx, x, y);
        }

        ctx.restore();
    }
}


class PaletteControl extends ItemControl
{
    constructor(e, area, linked)
    {
        super(e, area, linked);

        for (let p of area.palettes)
            this.height = Math.min(this.height, e.height / (p.colors.length + 2));

        this.number = Math.floor(e.height / this.height);
    }

    selectItem(i)
    {
        if (i === 0) {
            if (this.area.palette !== 0)
                this.area.palette--;
        } else if (i === this.number - 1) {
            if (this.area.palette !== this.area.palettes.length - 1)
                this.area.palette++;
        } else {
            const p = this.area.palettes[this.area.palette];

            if (i <= p.colors.length)
                this.area.setToolOptions(p.colors[i - 1]);
        }
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
            ctx.strokeStyle = "#888";
            ctx.stroke();
        } else {
            ctx.fillStyle = `hsl(${p.colors[i - 1].H},${p.colors[i - 1].S}%,${p.colors[i - 1].L}%)`;
            ctx.fill();
        }
    }
}


class ToolControl extends ItemControl
{
    constructor(e, area, linked)
    {
        super(e, area, linked);
        const n = Math.floor(e.height / this.height) * Math.floor(e.width / this.height);
        this.tools  = n < this.area.tools.length ? this.smallSubset : this.area.tools;
        this.number = this.tools.length;
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
        const selected = this.tools[i] === this.area.tool.options.kind;
        const size = this.height;
        const tool = new this.tools[i](null, { size: size * 9 / 20, L: 80, opacity: selected ? 1 : 0.5 });
        tool.symbol(ctx, x + size / 2, y + size / 2);
    }
}


class ModalControl
{
    constructor(e, x, y, parent)
    {
        if (parent) {
            const right = $(parent).parents('.side-area').hasClass('side-area-right');
            e.style.top = parent.offsetTop + 'px';
            e.classList.add('fixed');
            e.classList.add(right ? 'fixed-right' : 'fixed-left');
        } else {
            e.style.left = x + 'px';
            e.style.top  = y + 'px';
        }

        document.body.appendChild(this.cover = document.createElement('div'));
        this.cover.classList.add('cover');
        this.cover.appendChild(this.element = e);
    }

    redraw() {}
}


class SaveControl extends ModalControl
{
    constructor(e, area, x, y, parent)
    {
        super(e, x, y, parent);

        $(e).find('[data-type]').on('click', (ev) => {
            const link = document.createElement('a');
            link.download = ev.target.getAttribute('data-name');
            link.href     = area.export(ev.target.getAttribute('data-type'));
            link.click();
        });
    }
}


class JointControl extends ModalControl
{
    constructor(e, area, x, y, parent)
    {
        super(e, x, y, parent);
        const elem = $(e);
        const color   = elem.find('[data-control="ColorControl"]')   .control(area);
        const palette = elem.find('[data-control="PaletteControl"]') .control(area, color);
        const size    = elem.find('[data-control="SizeControl"]')    .control(area);
        const tool    = elem.find('[data-control="ToolControl"]')    .control(area, size);
    }
}


class ColorButtonControl extends CanvasControl
{
    constructor(e, area)
    {
        super(e, area);
        area.on('tool:H tool:S tool:L tool:kind', this.redraw.bind(this));
        this.tool = {};
    }

    redraw()
    {
        const opt = this.area.tool.options;

        if (this.tool.constructor !== opt.kind)
            this.tool = new opt.kind(null, { size: this.element.width / 1.5, L: 50 });

        if (Math.abs(this.tool.options.L - opt.L) <= 50) {
            const ctx = this.element.getContext('2d');
            ctx.clearRect(0, 0, this.element.width, this.element.height);
            this.tool.options.L = opt.L > 50 ? 0 : 100;
            this.tool.symbol(ctx, this.element.width / 2, this.element.height / 2);
        }

        this.element.style.background = `hsl(${opt.H}, ${opt.S}%, ${opt.L}%)`;
    }
}


class LayerControl
{
    constructor(e, area)
    {
        const template = $(e.getAttribute('data-control-layer-config'));
        const button   = (ev) => ev.originalEvent.touches ? ev.originalEvent.touches.length : ev.button;
        const position = (ev) => ev.originalEvent.touches ? ev.originalEvent.touches[0].pageY : ev.pageY;

        const elem = $(e);
        elem.append("<div>");

        elem.on('contextmenu', '.layer-menu-item', function (ev) {
            template.clone().control(area, $(this).index(), 0, 0, this);
            return false;
        });

        elem.on('mousedown touchstart', '.layer-menu-item', function (ev) {
            if (ev.which > 1)
                return true;

            const elem  = $(this);
            const index = elem.index();
            const pageY = elem.position().top;
            const body  = $(document.body);

            let offset = 0;
            let start  = position(ev);

            const drag = (ev) => {
                offset = position(ev) - start;
                elem.css('position', 'relative').css('top', offset).css('z-index', 1);
                return false;
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

                let shift = -index;

                elem.parent().children('.layer-menu-item').each((i, it) => {
                    if (i != index && $(it).position().top < pageY + offset)
                        shift = i - index + (i < index);
                });

                elem.css('position', 'static').css('z-index', '');

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
            return false;
        });

        area.on('layer:add', (layer, index) => {
                const entry = $('<div class="layer-menu-item"><canvas></canvas></div>');
                entry.insertBefore(elem.children().eq(index));
            })

            .on('layer:redraw', (layer, index) => {
                const scale  = 150 / Math.max(layer.w, layer.h);
                const canvas = elem.children().eq(index).find('canvas')[0];
                canvas.width  = layer.w * scale;
                canvas.height = layer.h * scale;
                const ctx    = canvas.getContext('2d');
                ctx.globalCompositeOperation = 'copy';
                ctx.drawImage(layer.img, 0, 0, canvas.width, canvas.height);
            })

            .on('layer:set',  (index) => elem.children().removeClass('active').eq(index).addClass('active'))
            .on('layer:del',  (index) => elem.children().eq(index).remove())
            .on('layer:move', (i, di) => elem.children().eq(i).detach().insertBefore(elem.children().eq(i + di)));
    }

    redraw() { /* add existing layers to the list? */ }
}


class ConfigControl extends ModalControl
{
    constructor(e, object, x, y, parent)
    {
        super(e, x, y, parent);
        this.object = object;
        this.props  = $(e).find('[data-prop]').on('change', (ev) => {
            let k = ev.target.getAttribute('data-prop');
            let t = ev.target.getAttribute('data-type');
            let v = ev.target.type == 'checkbox' ? ev.target.checked : ev.target.value;

            if      (t == 'int')   v = parseInt(v);
            else if (t == 'float') v = parseFloat(v);

            if (!(typeof v === 'number' && isNaN(v)) && this.select(k, v) !== false)
                this.object[k] = v;

            this.redraw();
        });
    }

    select(k, v) {}
    redraw()
    {
        this.props.each((_, p) => { p.checked = p.value = this.object[p.getAttribute('data-prop')] });
    }
}


class LayerConfigControl extends ConfigControl
{
    constructor(e, area, index, x, y, parent)
    {
        super(e, area.layers[index], x, y, parent);
        this.area = area;
    }

    select(k, v)
    {
        this.area.snap({ index: this.area.layers.indexOf(this.object) });
    }
}


const exports = { ColorControl, SizeControl, PaletteControl, ToolControl, SaveControl
                , JointControl, ColorButtonControl, LayerControl, LayerConfigControl
                , ImageConfigControl: ConfigControl };


$.fn.control = function (...args)
{
    return this.toArray().map((v) => {
        const it = new exports[v.getAttribute('data-control')](v, ...args);
        it.redraw();
        return it;
    });
};
