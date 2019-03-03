"use strict";


class ControlBase {
    constructor(e, area, linked = []) {
        this.element = e;
        this.area    = area;
        this.linked  = linked;
    }

    redraw(all = false) {
        for (let c of this.linked)
            c.redraw();
    }
}


class CanvasControl extends ControlBase {
    constructor(e, area, linked = [], draggable = false) {
        super(e, area, linked);
        this.width   = +e.width;
        this.height  = +e.height;
        e.$forceNativeResolution();

        const click = ev => {
            const r = e.getBoundingClientRect();
            this.select(ev.clientX - r.left, ev.clientY - r.top);
            this.redraw();
        };

        if (draggable) {
            const touch = ev => {
                if (ev.touches.length === 1)
                    click(ev.touches[0]);
            };

            const mouse = ev => {
                if (ev.which === 1)
                    click(ev);
            };

            e.$defaultEventListener('mousedown',  ev => { e.addEventListener('mousemove', mouse); mouse(ev); });
            e.$defaultEventListener('touchstart', ev => { e.addEventListener('touchmove', touch); touch(ev); });
            e.$defaultEventListener('mousemove',  ev => {});
            e.$defaultEventListener('touchmove',  ev => {});
            e.$defaultEventListener('mouseup',    ev => { e.removeEventListener('mousemove', mouse); });
            e.$defaultEventListener('touchend',   ev => { e.removeEventListener('touchmove', touch); });
        } else {
            e.$defaultEventListener('click', click);
        }
    }

    select(x, y) {
    }

    redraw(all = false) {
        super.redraw(all);
        if (all) {
            this.element.getContext('2d').clearRect(0, 0, this.width, this.height);
        }
    }
}


class ColorControl extends CanvasControl {
    constructor(e, area, linked) {
        super(e, area, linked, true);
    }

    get hueOuterR() {
        return Math.min(this.width, this.height) / 2;
    }

    get hueInnerR() {
        return 0.78 * this.hueOuterR;
    }

    get satRadius() {
        return 0.87 * this.hueInnerR;
    }

    select(x, y) {
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

    redraw(all = false) {
        super.redraw(all);
        const satHeight = this.satRadius * 1.5;
        const satSide   = this.satRadius * Math.sqrt(3);
        const ctx       = this.element.getContext('2d');

        if (all) {
            ctx.save();
            ctx.scale(this.hueOuterR, this.hueOuterR);
            ctx.translate(1, 1);

            const steps = 8;
            const rad = 2 * Math.PI / steps;
            const deg = 360 / steps;
            for (let i = 0; i < steps; i++) {
                const grad = ctx.createLinearGradient(Math.cos(i*rad), Math.sin(i*rad), Math.cos((i+1)*rad), Math.sin((i+1)*rad));
                grad.addColorStop(0, `hsl(${i*deg},100%,50%)`);
                grad.addColorStop(1, `hsl(${(i+1)*deg},100%,50%)`);
                ctx.fillStyle = grad;
                ctx.beginPath();
                ctx.arc(0, 0, 1, i*rad, (i+1)*rad);
                ctx.lineTo(0, 0);
                ctx.fill();
            }

            ctx.globalCompositeOperation = 'destination-out';
            ctx.beginPath();
            ctx.arc(0, 0, this.hueInnerR / this.hueOuterR, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
        }

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


class BarControl extends CanvasControl {
    constructor(e, area, linked) {
        super(e, area, linked, true);
    }

    get isVertical() {
        return this.height >= this.width;
    }

    get length() {
        return Math.max(this.height, this.width);
    }

    select(x, y) {
        this.value = Math.max(0, Math.min(1, (this.isVertical ? this.length - y : x) / this.length * 10 / 9 - 1 / 18));
    }

    redraw(all = false) {
        super.redraw(true);
        const ctx = this.element.getContext('2d');
        ctx.font        = '14px Helvetica';
        ctx.lineWidth   = 3;
        ctx.fillStyle   = '#aaa';
        ctx.strokeStyle = '#aaa';
        ctx.beginPath();
        if (this.isVertical) {
            const y = 0.5 + (19 / 18 - this.value) * this.height * 9 / 10;
            ctx.fillText(this.text, 5.5, y - 5);
            ctx.moveTo(0.5, y);
            ctx.lineTo(0.5 + this.width, y);
        } else {
            const x = 0.5 + (1  / 18 + this.value) * this.width * 9 / 10;
            ctx.fillText(this.text, x + 5, this.height - 4.5);
            ctx.moveTo(x, 0.5);
            ctx.lineTo(x, 0.5 + this.height);
        }
        ctx.stroke();
    }

    get text() {
        return Math.round(this.value);
    }

    get value() {
        return 0;
    }

    set value(v) {
    }
}


class SizeControl extends BarControl {
    get text() {
        return Math.round(this.area.tool.options.size);
    }

    get value() {
        return Math.pow((this.area.tool.options.size - 1) / this.length / 2.5, 0.4);
    }

    set value(v) {
        this.area.setToolOptions({ size: Math.pow(v, 2.5) * this.length * 2.5 + 1 });
    }
}


class OpacityControl extends BarControl {
    get text() {
        return Math.round(this.area.tool.options.opacity * 100) / 100;
    }

    get value() {
        return this.area.tool.options.opacity;
    }

    set value(v) {
        this.area.setToolOptions({ opacity: v });
    }
}


class RotationControl extends BarControl {
    get text() {
        return Math.round(this.value * 360);
    }

    get value() {
        return this.area.tool.options.rotation / 2 / Math.PI;
    }

    set value(v) {
        this.area.setToolOptions({ rotation: v * 2 * Math.PI });
    }
}


class ItemControl extends CanvasControl {
    select(x, y) {
        let isz = this.itemSize;
        this.selectItem(Math.floor(x / isz) * Math.floor(this.height / isz) + Math.floor(y / isz));
    }

    redraw(all = false) {
        super.redraw(all);
        const ctx = this.element.getContext('2d');
        const qty = Math.floor(this.height / this.itemSize);
        ctx.save();
        ctx.clearRect(0, 0, this.width, this.height);
        ctx.translate(0.5, 0.5);

        let isz = this.itemSize;
        for (let i = 0; i < this.itemCount; i++) {
            const x = Math.floor(i / qty) * isz;
            const y = Math.floor(i % qty) * isz;
            ctx.beginPath();
            ctx.rect(x, y, isz, isz);
            this.redrawItem(i, ctx, x, y, isz);
        }

        ctx.restore();
    }

    get itemCount() {
        return 0;
    }

    get itemSize() {
        const ds = this.element.dataset.itemSize;
        return !isNaN(+ds) ? +ds : Math.min(this.width, this.height);
    }

    selectItem(i) {
    }

    redrawItem(i, context2d, x, y, size) {
    }
}


class PaletteControl extends ItemControl {
    get itemCount() {
        return Math.floor(this.height / this.itemSize);
    }

    get itemSize() {
        let r = Math.min(this.width, this.height);
        for (let p of this.area.palettes)
            r = Math.min(r, this.height / (p.colors.length + 2));
        return r;
    }

    selectItem(i) {
        if (i === 0)
            return this.area.palette = Math.max(this.area.palette - 1, 0);
        if (i === this.itemCount - 1)
            return this.area.palette = Math.min(this.area.palette + 1, this.area.palettes.length - 1);
        const p = this.area.palettes[this.area.palette];
        if (p && i <= p.colors.length)
            this.area.setToolOptions(p.colors[i - 1]);
    }

    redrawItem(i, ctx, x, y, size) {
        let p = this.area.palettes[this.area.palette];
        if (!p)
             p = {colors: []};

        if (i === 0 || i > p.colors.length) {
            const q = i === 0 ? -1 : i === this.itemCount - 1 ? +1 : 0;
            ctx.beginPath();
            ctx.moveTo(x + size * 0.3, y + size * (0.5 - 0.1 * q));
            ctx.lineTo(x + size * 0.5, y + size * (0.5 + 0.1 * q));
            ctx.lineTo(x + size * 0.7, y + size * (0.5 - 0.1 * q));
            ctx.lineWidth = 3;
            ctx.strokeStyle = "#888";
            ctx.stroke();
        } else {
            ctx.fillStyle = `hsl(${p.colors[i - 1].H},${p.colors[i - 1].S}%,${p.colors[i - 1].L}%)`;
            ctx.fill();
        }
    }
}


class ToolControl extends ItemControl {
    get itemCount() {
        return this.area.tools.length;
    }

    selectItem(i) {
        const tool = this.area.tools[i];
        if (tool === undefined || tool === this.area.tool.options.kind)
            return;
        this.area.setToolOptions({ kind: tool, last: tool });
    }

    redrawItem(i, ctx, x, y, size) {
        const ctor = this.area.tools[i];
        const tool = new ctor(null, { size: size * 9 / 20, L: 80, opacity: ctor === this.area.tool.options.kind ? 1 : 0.5 });
        tool.symbol(ctx, x + size / 2, y + size / 2);
    }
}


class ModalControl extends ControlBase {
    constructor(e, area, x, y, parent) {
        super(e, area, []);
        if (parent) {
            const area = parent.$nearestParent('.side-area');
            const right = area && area.classList.contains('side-area-right');
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

    redraw(all = false) {
    }
}


class SaveControl extends ModalControl {
    constructor(e, area, x, y, parent) {
        super(e, area, x, y, parent);
        let download = ev => {
            const link = document.createElement('a');
            link.download = ev.target.dataset.name;
            link.href     = area.save(ev.target.dataset.type);
            link.click();
        };
        for (let c of e.querySelectorAll('[data-type]'))
            c.addEventListener('click', download);
    }
}


class JointControl extends ModalControl {
    constructor(e, area, x, y, parent) {
        super(e, area, x, y, parent);
        let cs = Array.from(e.children).filter(c => c.dataset.control).map(c => new Control(c, area, [this]));
        let cc = cs.filter(c => c instanceof ColorControl);
        let pc = cs.filter(c => c instanceof PaletteControl);
        let bc = cs.filter(c => c instanceof BarControl);
        pc.forEach(c => c.linked = cc);
        this.bars = bc;
        this.tool = document.createElement('canvas');
        this.tool.style.top = '0';
        this.tool.style.zIndex = '0';
        this.tool.style.position = 'absolute';
        this.tool.style.pointerEvents = 'none';
        this.element.insertBefore(this.tool, this.element.children[0]);
    }

    redraw(all = true) {
        super.redraw(all);
        if (this.tool) {
            let a = Infinity, b = -Infinity;
            for (let c of this.bars)
                a = Math.min(a, c.element.offsetLeft), b = Math.max(b, c.element.offsetLeft + c.element.offsetWidth);

            this.tool.width = b - a;
            this.tool.height = this.element.offsetHeight;
            this.tool.style.left = `${a}px`;
            this.tool.$forceNativeResolution();
            const ctx = this.tool.getContext('2d');
            ctx.clearRect(0, 0, b - a, this.element.offsetHeight);
            ctx.translate((b - a) / 2, this.element.offsetHeight / 2);
            this.area.tool.crosshair(ctx);
        }
    }
}


class ColorButtonControl extends CanvasControl {
    constructor(e, area) {
        super(e, area);
        // FIXME event handler leak
        area.on('tool:options', _ => this.redraw());
    }

    redraw(all = false) {
        const opt = this.area.tool.options;
        if (all || this.tool.constructor !== opt.kind)
            this.tool = new opt.kind(null, { size: Math.min(this.width, this.height) / 1.5, L: 50 });
        if (all || Math.abs(this.tool.options.L - opt.L) <= 50) {
            super.redraw(true);
            this.tool.options.L = opt.L > 50 ? 0 : 100;
            this.tool.symbol(this.element.getContext('2d'), this.width / 2, this.height / 2);
        }
        this.element.style.background = `hsl(${opt.H}, ${opt.S}%, ${opt.L}%)`;
    }
}


class LayerControl extends ControlBase {
    constructor(e, area) {
        super(e, area);
        // FIXME event handler leak
        area.on('layer:add',    this.onLayerAdd.bind(this))
            .on('layer:redraw', this.onLayerDraw.bind(this))
            .on('layer:set',    this.onLayerSet.bind(this))
            .on('layer:del',    this.onLayerDel.bind(this))
            .on('layer:move',   this.onLayerMove.bind(this));
    }

    onLayerAdd(layer, index) {
        const cnv = document.createElement('canvas');
        const div = document.createElement('div');
        cnv.getContext('2d').globalCompositeOperation = 'copy';
        div.appendChild(cnv);
        div.addEventListener('contextmenu', this.onLayerMenu.bind(this));
        div.addEventListener('touchstart',  this.onLayerDrag.bind(this));
        div.addEventListener('mousedown',   this.onLayerDrag.bind(this));
        this.element.$insertAt(div, index);
    }

    onLayerDrag(ev) {
        const button   = ev => ev.touches ? ev.touches.length : ev.button;
        const position = ev => ev.touches ? ev.touches[0].pageY : ev.pageY;
        if (button(ev) > 1)
            return;

        ev.preventDefault();
        let target = ev.currentTarget;
        let origin = target.offsetTop;
        let start = position(ev), end = start, totalMoved = 0;
        target.style.position = 'relative';
        target.style.zIndex = 1;

        const drag = (ev) => {
            end = position(ev);
            totalMoved += Math.abs(end - start);
            target.style.top = `${end - start}px`;
        };

        const stop = (ev) => {
            ev.preventDefault();
            target.style.position = 'static';
            target.style.top = '';
            const body = document.body;
            body.removeEventListener('touchstart', abort);
            body.removeEventListener('mousedown',  abort);
            body.removeEventListener('mousemove',  drag);
            body.removeEventListener('touchmove',  drag);
            body.removeEventListener('mouseup',    drop);
            body.removeEventListener('touchend',   drop);
        };

        const abort = (ev) => {
            if (button(ev) > 1)
                stop(ev);
        };

        const drop = (ev) => {
            stop(ev);
            let index = 0, newIndex = 0;
            for (let c of target.parentElement.children) {
                if (c !== target && c.offsetTop < origin)
                    index++;
                if (c !== target && c.offsetTop < origin + (end - start))
                    newIndex++;
            }
            if (index !== newIndex)
                area.moveLayer(index, newIndex - index);
            if (area.layer === newIndex && totalMoved < 5)
                this.showLayerMenu(target);
            area.setLayer(newIndex);
        };

        const body = document.body;
        body.addEventListener('mousedown',  abort);
        body.addEventListener('touchstart', abort);
        body.addEventListener('mousemove',  drag);
        body.addEventListener('touchmove',  drag);
        body.addEventListener('mouseup',    drop);
        body.addEventListener('touchend',   drop);
    }

    showLayerMenu(target) {
        const c = document.querySelector(this.element.dataset.controlLayerConfig).cloneNode(true);
        new Control(c, this.area, 0, 0, target, this.area.layers[$(target).index()]);
    }

    onLayerMenu(ev) {
        ev.preventDefault();
        this.showLayerMenu(ev.currentTarget);
    }

    onLayerDraw(layer, index) {
        const scale = 150 / Math.max(layer.w, layer.h);
        const canvas = this.element.children[index].querySelector('canvas');
        canvas.width = layer.w * scale;
        canvas.height = layer.h * scale;
        canvas.getContext('2d').drawImage(layer.img, 0, 0, canvas.width, canvas.height);
    }

    onLayerSet(index) {
        for (let c of this.element.children)
            c.classList.remove('active');
        this.element.children[index].classList.add('active');
    }

    onLayerDel(index) {
        this.element.children[index].remove();
    }

    onLayerMove(index, delta) {
        this.element.$insertAt(this.element.children[index], index + delta + (delta >= 0));
    }
}


class ConfigControl extends ModalControl {
    constructor(e, area, x, y, parent, object) {
        super(e, area, x, y, parent);
        this.object = object;
        for (let c of e.querySelectorAll('[data-prop]'))
            c.addEventListener('change', this.onChange.bind(this));
    }

    onChange(ev) {
        let t = ev.target.dataset.type;
        let k = ev.target.dataset.prop;
        let v = ev.target.type == 'checkbox' ? ev.target.checked : ev.target.value;
        if (t === 'int')
            v = parseInt(v);
        if (t === 'float')
            v = parseFloat(v);
        if (!(typeof v === 'number' && isNaN(v)))
            this.select(k, v);
    }

    select(k, v) {
        this.object[k] = v;
        this.redraw();
    }

    redraw(all = false) {
        super.redraw(all);
        for (let p of this.element.querySelectorAll('[data-prop]'))
            p.checked = p.value = this.object[p.dataset.prop];
    }
}


class LayerConfigControl extends ConfigControl {
    select(k, v) {
        this.area.snap({ index: this.area.layers.indexOf(this.object) });
        super.select(k, v);
    }
}


class ImageConfigControl extends ConfigControl {
    constructor(e, area, x, y, parent) {
        super(e, area, x, y, parent, area);
    }
}


function Control(e, ...args) {
    let c = new Control.types[e.dataset.control](e, ...args);
    return c.redraw(true), c;
}

Control.types = { ColorControl, SizeControl, OpacityControl, RotationControl, PaletteControl, ToolControl
                , JointControl, ColorButtonControl, LayerControl, LayerConfigControl , ImageConfigControl
                , SaveControl };
