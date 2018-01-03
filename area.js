"use strict";

const UNDO_OPS_LIMIT = 50;

// enum UNDO_OPERATION_KIND
const UNDO_DRAW       = 0
    , UNDO_ADD_LAYER  = 1
    , UNDO_DEL_LAYER  = 2
    , UNDO_MOVE_LAYER = 3
    , UNDO_MERGE_DOWN = 4
    , UNDO_UNMERGE    = 5;


class Area {
    constructor(element) {
        element.appendChild(this.select_ui = document.createElement('canvas'));
        element.appendChild(this.crosshair = document.createElement('canvas'));
        this.select_ui.style.top = this.select_ui.style.left = "0";
        this.select_ui.style.width = "100%";
        this.select_ui.style.height = "100%";
        this.select_ui.classList.add('selection');
        this.crosshair.classList.add('crosshair');

        this.tool       = new Tool(this, {});
        this.element    = element;
        this.layer      = 0;
        this.drawing    = 0;   // number of active input devices
        this.layers     = [];  // :: [Layer]
        this.selection  = [];  // :: [Path2D]
        this.undos      = [];  // :: [{action, index, state, ...}]
        this.redos      = [];
        this.events     = {};
        this.scale      = this.defaultScale();
        this.w          = 0;
        this.h          = 0;

        let device = {
            active: {},
            context: null,

            position: (ev) => {
                const r = element.getBoundingClientRect();
                const x = (ev.clientX - r.left) / this.scale;
                const y = (ev.clientY - r.top)  / this.scale;
                const z = ev.pointerType === "pen" ? ev.pressure : 1;
                const w = (ev.rotationAngle || 0) / 360;
                return {x, y, z, w};
            },

            start: (dev, ev) => {
                if (!this.layers.length || !this.tool)
                    return false;
                if (this.drawing++ === 0) {
                    const layer = this.layers[this.layer];
                    const ctx = layer.img.getContext('2d');
                    ctx.save();
                    ctx.translate(0.5 - layer.x, 0.5 - layer.y);
                    for (let path of this.selection)
                        ctx.clip(path);
                    this.snap({index: this.layer, action: UNDO_DRAW});
                    device.context = ctx;
                }
                const p = device.position(ev);
                const t = device.active[dev] = new this.tool.options.kind(this, {});
                t.options = this.tool.options;  // FIXME should not share dynamics
                t.start(device.context, p.x, p.y, p.z, p.w);
                return true;
            },

            move: (dev, ev) => {
                if (device.active[dev]) {
                    const p = device.position(ev);
                    device.active[dev].move(device.context, p.x, p.y, p.z, p.w);
                }
            },

            end: (dev) => {
                if (device.active[dev]) {
                    device.active[dev].stop(device.context);
                    delete device.active[dev];
                    if (--this.drawing === 0) {
                        device.context.restore();
                        device.context = null;
                        if (this.layers.length)  // might have changed since `onDown`
                            this.trigger('layer:redraw', this.layers[this.layer], this.layer);
                        return true;
                    }
                }
                return false;
            },
        };

        const mouse = {
            start(ev) {
                element.removeEventListener('mouseenter', mouse.start);
                if (ev.which !== 1 || (ev.buttons !== undefined && ev.buttons !== 1))
                    return;
                ev.preventDefault();  // FIXME this prevents unwanted selection, but breaks focusing.
                if (device.start(-1, ev))
                    element.addEventListener('mousemove', mouse.move);
            },

            move(ev) {
                device.move(-1, ev);
            },

            end(ev) {
                device.end(-1);
                element.removeEventListener('mousemove', mouse.move);
                if (ev.type === 'mouseleave')
                    element.addEventListener('mouseenter', mouse.start);
            },
        };

        const touch = {
            start(ev) {
                // FIXME this one is even worse depending on the device.
                //   On Chromium OS, this will prevent "back/forward" gestures from
                //   interfering with drawing, but will not focus the broswer window
                //   if the user taps the canvas.
                ev.preventDefault();
                for (let t of ev.changedTouches)
                    if (device.start(t.identifier, t))
                        element.addEventListener('touchmove', touch.move);
            },

            move(ev) {
                for (let t of ev.changedTouches)
                    device.move(t.identifier, t);
            },

            end(ev) {
                for (let t of ev.changedTouches)
                    device.end(t.identifier);
                if (ev.touches.length === 0)
                    element.removeEventListener('touchmove', touch.move);
            },
        };

        const pointer = {
            start(ev) {
                element.removeEventListener('pointerenter', pointer.start);
                if (ev.which !== 0 /* no buttons, e.g. touch screen */ && ev.which !== 1)
                    return;
                ev.preventDefault();
                if (device.start(ev.pointerId, ev))
                    element.addEventListener('pointermove',  pointer.move);
            },

            move(ev) {
                device.move(ev.pointerId, ev);
            },

            end(ev) {
                if (device.end(ev.pointerId)) {
                    element.removeEventListener('pointermove',  pointer.move);
                    if (ev.type === 'pointerleave')
                        element.addEventListener('pointerenter', pointer.start);
                }
            },
        };

        if ('onpointerdown' in document.body) {
            element.addEventListener('pointerdown',  pointer.start);
            element.addEventListener('pointerleave', pointer.end);
            element.addEventListener('pointerup',    pointer.end);
            // Still have to ignore these separately.
            element.addEventListener('touchstart', ev => ev.preventDefault());
        } else {
            element.addEventListener('mousedown',  mouse.start);
            element.addEventListener('mouseleave', mouse.end);
            element.addEventListener('mouseup',    mouse.end);
            element.addEventListener('touchstart', touch.start);
            element.addEventListener('touchend',   touch.end);
        }

        const updateCrosshair = (ev) => {
            if (ev.pointerType && ev.pointerType !== "pen" && ev.pointerType !== "mouse")
                return;
            const r = element.getBoundingClientRect();
            this.crosshair.style.left = ev.clientX - r.left + 'px';
            this.crosshair.style.top  = ev.clientY - r.top  + 'px';
            this.crosshair.style.display = '';
        };

        element.addEventListener('mouseleave',  (ev) => this.crosshair.style.display = 'none');
        element.addEventListener('touchstart',  (ev) => this.crosshair.style.display = 'none');
        element.addEventListener('mousemove',   updateCrosshair);
        element.addEventListener('pointermove', updateCrosshair);
    }

    defaultScale() {
        return 1 / this.crosshair.$getResolution();
    }

    on(name, fn) {
        for (let n of name.split(' ')) {
            this.events[n] = this.events[n] || [];
            this.events[n].push(fn);
        }
        return this;
    }

    trigger(name, ...args) {
        if (!this.events[name])
            return false;
        for (let fn of this.events[name])
            fn.apply(this, args);
        return true;
    }

    onLayerRedraw(layer) {
        const index = this.layers.indexOf(layer);
        layer.restyle(index == this.layer, -1 - index);
        this.trigger('layer:redraw', layer, index);
    }

    restyleCrosshair() {
        const s = this.tool.options.size;
        this.crosshair.width = this.crosshair.height = s * this.scale;
        this.crosshair.$forceNativeResolution();
        this.crosshair.style.marginLeft = `${-s / 2 * this.scale}px`;
        this.crosshair.style.marginTop  = `${-s / 2 * this.scale}px`;
        const ctx = this.crosshair.getContext('2d');
        ctx.scale(this.scale, this.scale);
        ctx.translate(s / 2, s / 2);
        this.tool.crosshair(ctx);
    }

    get w() { return this._w; }
    get h() { return this._h; }
    get scale() { return this._scale; }

    set w(w) {
        this.element.style.width  = `${this._w = w}em`;
        this.selection = this.selection;
    }

    set h(h) {
        this.element.style.height = `${this._h = h}em`;
        this.selection = this.selection;
    }

    set scale(x) {
        this._scale = Math.max(0.05, Math.min(20, x));
        this.element.style.fontSize = `${this._scale}px`;
        this.restyleCrosshair();
        // TODO make the viewport centered at the same position as it was
    }

    get selection() {
        return this._selection;
    }

    set selection(paths) {
        this._selection = paths;  // TODO grayscale masks
        this.select_ui.width  = this.w;
        this.select_ui.height = this.h;
        const ctx = this.select_ui.getContext('2d');
        ctx.save();
        ctx.globalAlpha = 0.33;
        ctx.fillStyle = "hsl(0, 0%, 50%)";
        ctx.fillRect(0, 0, this.w, this.h);
        for (let path of paths) ctx.clip(path);
        ctx.clearRect(0, 0, this.w, this.h);
        ctx.restore();
    }

    /* Save a snapshot of a single layer in the undo stack.
     * Meanwhile, the redo stack is reset. */
    snap(options)
    {
        if (options.state === undefined)
            options.state = this.layers[options.index].state;

        this.redos = [];
        this.undos.splice(0, 0, options);
        this.undos.splice(UNDO_OPS_LIMIT);
    }

    /* Create an empty layer at a given position in the stack,
     * optionally from a previously saved `Layer` state. */
    createLayer(index, state)
    {
        if (index > this.layers.size) index = this.layers.size;

        const layer = new Layer(this);
        this.layers.splice(index, 0, layer);
        this.element.appendChild(layer.img);
        this.trigger('layer:add', layer, index);

        if (state)
            layer.state = state;
        else
            layer.crop(0, 0, this.w, this.h);

        this.setLayer(index);
        this.snap({index: index, action: UNDO_ADD_LAYER, state: null});
        return layer;
    }

    /* Select a layer to draw on. */
    setLayer(i)
    {
        if (i < 0 || this.layers.length <= i)
            return;

        this.trigger('layer:set', this.layer = i);

        let k = 0;
        for (let layer of this.layers)
            layer.restyle(k++ == this.layer, -k);
    }

    /* Remove a layer from the stack. */
    deleteLayer(i)
    {
        if (i < 0 || this.layers.length <= i)
            return;

        this.snap({index: i, action: UNDO_DEL_LAYER});
        this.layers.splice(i, 1)[0].img.remove();
        this.trigger('layer:del', i);
        this.setLayer(Math.min(this.layer, this.layers.length - 1));
    }

    /* Move a layer `delta` positions up the stack. Negative values shift down.
     * The layer is automatically selected for drawing. */
    moveLayer(i, delta)
    {
        if (i + Math.min(delta, 0) < 0 || this.layers.length <= i + Math.max(delta, 0))
            return;

        this.snap({index: i, action: UNDO_MOVE_LAYER, delta: delta, state: null});
        this.layers.splice(i + delta, 0, this.layers.splice(i, 1)[0]);
        this.trigger('layer:move', i, delta);
        this.setLayer(i + delta);
    }

    /* Remove a layer, drawing its contents onto the one below. That layer
     * is resized to fit the new contents. No-op if i-th layer is at the bottom. */
    mergeDown(i)
    {
        if (i < 0 || this.layers.length - 1 <= i)
            return;

        this.snap({index: i, action: UNDO_MERGE_DOWN, below: this.layers[i + 1].state});

        const top = this.layers.splice(i, 1)[0];
        const bot = this.layers[i];
        this.trigger('layer:del', i);

        bot.crop(Math.min(top.x, bot.x), Math.min(top.y, bot.y),
                 Math.max(top.w + top.x, bot.w + bot.x) - Math.min(top.x, bot.x),
                 Math.max(top.h + top.y, bot.h + bot.y) - Math.min(top.y, bot.y));

        const ctx = bot.img.getContext('2d');
        ctx.save();
        ctx.translate(-bot.x, -bot.y);
        top.drawOnto(ctx);
        top.img.remove();
        ctx.restore();

        this.setLayer(Math.min(this.layer, this.layers.length - 1));
        this.onLayerRedraw(bot);
    }

    /* Revert the action at the top of the undo stack. Supported actions:
     *   1. drawing (each stroke is a separate action);
     *   2. modifying layer parameters;
     *   3. adding/removing/moving/merging layers.
     */
    undo(reverse)
    {
        const redos = this.redos;
        const undos = reverse ? this.redos : this.undos;

        if (!undos.length)
            return;

        const data = undos.splice(0, 1)[0];

        switch (data.action) {
            case UNDO_ADD_LAYER:
                this.deleteLayer(data.index);
                break;

            case UNDO_DEL_LAYER:
                this.createLayer(data.index, data.state);
                break;

            case UNDO_MOVE_LAYER:
                this.moveLayer(data.index + data.delta, -data.delta);
                break;

            case UNDO_MERGE_DOWN:
                this.createLayer(data.index, data.state);
                this.layers[data.index + 1].state = data.below;
                // createLayer has pushed an UNDO_ADD_LAYER onto the undo stack.
                this.undos[0].action = UNDO_UNMERGE;
                break;

            case UNDO_UNMERGE:
                this.mergeDown(data.index);
                break;

            default:
                this.snap({index: data.index, action: UNDO_DRAW});
                this.layers[data.index].state = data.state;
                break;
        }

        // all these ops call `snap`, clearing the redo stack.
        this.redos = redos;

        if (!reverse)
            // there's an undo of an undo on top of the undo stack.
            // but an undo of an undo is a redo!
            this.redos.splice(0, 0, this.undos.splice(0, 1)[0]);
    }

    /* Undo a call to undo. Supports the same actions. */
    redo()
    {
        this.undo(true);
    }

    /* Serialize the contents of the area. Supported output types:
     *   1. "flatten" -- returns a canvas with all layers merged onto it;
     *   2. "png" -- returns an image/png data URL with the contents of that canvas;
     *   3. "svg" -- returns an image/svg+xml data URL where each layer is a separate
     *               object. preserves layer options, etc.
     */
    save(type)
    {
        switch (type) {
            case "flatten": {
                const tag = document.createElement('canvas');
                const ctx = tag.getContext('2d');
                tag.width  = this.w;
                tag.height = this.h;
                for (let n = this.layers.length; n--;) this.layers[n].drawOnto(ctx);
                return tag;
            }

            case "png":
                return this.save("flatten").toDataURL("image/png");

            case "svg": {
                const tag = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
                tag.setAttributeNS(null, 'width',  this.w);
                tag.setAttributeNS(null, 'height', this.h);
                tag.style.isolation = 'isolate';

                for (let n = this.layers.length; n--;) {
                    const ob = this.layers[n];
                    const it = document.createElementNS('http://www.w3.org/2000/svg', 'image');
                    it.setAttributeNS(null, 'x',      ob.x);
                    it.setAttributeNS(null, 'y',      ob.y);
                    it.setAttributeNS(null, 'width',  ob.w);
                    it.setAttributeNS(null, 'height', ob.h);
                    it.setAttributeNS('http://www.w3.org/1999/xlink', 'href',
                                      ob.img.toDataURL('image/png'));
                    if (ob.blendMode)      it.style.mixBlendMode = ob.blendMode;
                    if (!ob.visible)       it.setAttributeNS(null, 'visibility', 'hidden');
                    if (ob.opacity != '1') it.setAttributeNS(null, 'opacity', ob.opacity);
                    tag.appendChild(it);
                }

                return "data:image/svg+xml;base64," +
                        btoa(new XMLSerializer().serializeToString(tag));
            }

            default: return null;
        }
    }

    /* Deserialize an image and add it on top of the existing one. Supported
     * formats: image/png and image/svg+xml; the latter allows importing many
     * layers at once. Set forceSize = true to resize the area to fit the new layer.
     * Returns true on a successful import. */
    load(data, forceSize)
    {
        forceSize = forceSize || this.layers.length === 0;

        if (data.slice(0, 22) == 'data:image/png;base64,') {
            this.createLayer(0, {x: 0, y: 0, data});
            if (forceSize) {
                const img = new Image();
                img.onload = () => {
                    this.w = img.width;
                    this.h = img.height;
                };
                img.src = data;
            }
            return true;
        }

        if (data.slice(0, 26) == 'data:image/svg+xml;base64,') {
            const dom  = new DOMParser();
            const doc  = dom.parseFromString(atob(data.slice(26)), 'application/xml');
            const root = doc.documentElement;

            for (let x = root.firstChild; x !== null; x = x.nextSibling) {
                this.createLayer(0, {
                    x: parseInt(x.getAttribute('x')),
                    y: parseInt(x.getAttribute('y')),
                    w: parseInt(x.getAttribute('width')),
                    h: parseInt(x.getAttribute('height')),
                    data: x.getAttributeNS('http://www.w3.org/1999/xlink', 'href'),
                    visible: x.getAttribute('visibility') !== 'hidden',
                    opacity: x.getAttribute('opacity'),
                    blendMode: x.style.mixBlendMode,
                });
            }

            if (forceSize) {
                this.w = root.getAttribute('width')|0;
                this.h = root.getAttribute('height')|0;
            }
            return true;
        }

        return false;
    }

    /* Load the contents of every file in a drag-and-drop operation or the clipboard. */
    paste(data)
    {
        for (let i = 0; i < data.files.length; i++) {
            if (data.files[i].type.match(/image\/.*/)) {
                const file = new FileReader();
                file.onload = (r) => this.load(r.target.result);
                file.readAsDataURL(data.files[i]);
            }
        }

        for (let j = 0; j < data.types.length; j++)
            if (data.types[j] && data.types[j].match(/image\/.*/))
                this.load(data.getData(data.types[j]));
    }

    /* Apply new options to the currently selected tool. Options not specified
     * in the array are left untouched. */
    setToolOptions(options)
    {
        if (options.kind && this.drawing)
            return false;

        if (options.kind)
            this.tool = new options.kind(this, this.tool ? this.tool.options : {});

        this.tool.setOptions(options);
        this.restyleCrosshair();
        this.trigger('tool:options', this.tool.options, options);
        return true;
    }
}
