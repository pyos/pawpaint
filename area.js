"use strict";


class Area
{
    static get UNDO_OPS_LIMIT  () { return 25; }
    static get UNDO_DRAW       () { return 0; }
    static get UNDO_ADD_LAYER  () { return 1; }
    static get UNDO_DEL_LAYER  () { return 2; }
    static get UNDO_MOVE_LAYER () { return 3; }
    static get UNDO_MERGE_DOWN () { return 4; }
    static get UNDO_UNMERGE    () { return 5; }

    constructor(element)
    {
        element.appendChild(this.select_ui = document.createElement('canvas'));
        element.appendChild(this.crosshair = document.createElement('canvas'));
        this.select_ui.style.top = this.select_ui.style.left = 0;
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
        this.scale      = 1;
        this.setSize(0, 0);

        let tools   = {};
        let context = null;

        const onDown = (dev, ev) =>
        {
            if (this.drawing++ === 0) {
                if (!this.layers.length || !this.tool)
                    return false;

                const layer = this.layers[this.layer];
                context = layer.img.getContext('2d');
                context.save();
                context.translate(0.5 - layer.x, 0.5 - layer.y);

                for (let path of this.selection)
                    context.clip(path);

                this.snap({index: this.layer, action: Area.UNDO_DRAW});
            }

            const r = element.getBoundingClientRect();
            const x = (ev.clientX - r.left) / this.scale;
            const y = (ev.clientY - r.top)  / this.scale;

            tools[dev] = new this.tool.options.kind(this, {});
            tools[dev].options = this.tool.options;  // FIXME should not share dynamics
            tools[dev].start(context, x, y, ev.force || 0, (ev.rotationAngle || 0) / 360);
            return true;
        };

        const onMove = (dev, ev) =>
        {
            if (tools.hasOwnProperty(dev)) {
                const r = element.getBoundingClientRect();
                const x = (ev.clientX - r.left) / this.scale;
                const y = (ev.clientY - r.top)  / this.scale;
                tools[dev].move(context, x, y, ev.force || 0, (ev.rotationAngle || 0) / 360);
            }
        };

        const onUp = (dev) =>
        {
            if (tools.hasOwnProperty(dev)) {
                tools[dev].stop(context);
                delete tools[dev];

                if (--this.drawing === 0) {
                    context.restore();
                    context = null;

                    if (this.layers.length)  // might have changed since `onDown`
                        this.trigger('layer:redraw', this.layers[this.layer], this.layer);
                }
            }
        };

        // When using tablets, evdev may bug out and send the cursor jumping when doing
        // fine movements. To prevent this, we're going to ignore extremely fast
        // mouse movement events.
        let lastX = 0;
        let lastY = 0;

        const onMouseDown = (ev) =>
        {
            if (ev.which === 1 && (ev.buttons === undefined || ev.buttons === 1)) {
                // FIXME this prevents unwanted selection, but breaks focusing.
                ev.preventDefault();
                lastX = ev.pageX;
                lastY = ev.pageY;

                if (onDown(0, ev)) {
                    element.addEventListener('mouseup',    onMouseUp);
                    element.addEventListener('mouseleave', onMouseUp);
                    element.addEventListener('mousemove',  onMouseMove);
                    element.addEventListener('mouseenter', onMouseDown);
                }
            }
        };

        const onMouseMove = (ev) =>
        {
            if (Math.abs(ev.pageX - lastX) + Math.abs(ev.pageY - lastY) < 200) {
                lastX = ev.pageX;
                lastY = ev.pageY;
                onMove(0, ev);
            }
        };

        const onMouseUp = (ev) =>
        {
            onUp(0);
            element.removeEventListener('mouseup',    onMouseUp);
            element.removeEventListener('mouseleave', onMouseUp);
            element.removeEventListener('mousemove',  onMouseMove);
            if (ev.type !== 'mouseleave')
                element.removeEventListener('mouseenter', onMouseDown);
        };

        const onTouchDown = (ev) =>
        {
            // FIXME this one is even worse depending on the device.
            //   On Chromium OS, this will prevent "back/forward" gestures from
            //   interfering with drawing, but will not focus the broswer window
            //   if the user taps the canvas.
            ev.preventDefault();

            for (let i = 0; i < ev.changedTouches.length; i++) {
                const touch = ev.changedTouches[i];
                if (onDown(touch.identifier + 1, touch)) {
                    element.addEventListener('touchmove', onTouchMove);
                    element.addEventListener('touchend',  onTouchUp);
                }
            }
        };

        const onTouchMove = (ev) =>
        {
            for (let i = 0; i < ev.changedTouches.length; i++) {
                const touch = ev.changedTouches[i];
                onMove(touch.identifier + 1, touch);
            }
        };

        const onTouchUp = (ev) =>
        {
            for (let i = 0; i < ev.changedTouches.length; i++)
                onUp(ev.changedTouches[i].identifier + 1);

            if (ev.touches.length === 0) {
                element.removeEventListener('touchmove', onTouchMove);
                element.removeEventListener('touchend',  onTouchUp);
            }
        };

        element.addEventListener('mousedown',  onMouseDown);
        element.addEventListener('touchstart', onTouchDown);
        element.addEventListener('mouseleave', (ev) => this.crosshair.style.display = 'none');
        element.addEventListener('touchstart', (ev) => this.crosshair.style.display = 'none');
        element.addEventListener('mousemove',  (ev) => {
            const r = element.getBoundingClientRect();
            this.crosshair.style.left = ev.clientX - r.left + 'px';
            this.crosshair.style.top  = ev.clientY - r.top  + 'px';
            this.crosshair.style.display = '';
        });
    }

    on(name, fn)
    {
        for (let n of name.split(' ')) {
            this.events[n] = this.events[n] || [];
            this.events[n].push(fn);
        }

        return this;
    }

    trigger(name, ...args)
    {
        if (!this.events.hasOwnProperty(name))
            return false;

        for (let fn of this.events[name])
            fn.apply(this, args);

        return true;
    }

    onLayerRedraw(layer)
    {
        const index = this.layers.indexOf(layer);
        layer.restyle(index == this.layer, -1 - index);
        this.trigger('layer:redraw', layer, index);
    }

    restyleCrosshair()
    {
        const sz = this.tool.options.size * this.scale;
        this.crosshair.width = this.crosshair.height = sz;
        this.crosshair.style.marginLeft = this.crosshair.style.marginTop = -sz / 2 + "px";

        const ctx = this.crosshair.getContext('2d');
        ctx.translate(sz / 2, sz / 2);
        ctx.scale(this.scale, this.scale);
        this.tool.crosshair(ctx);
    }

    get w( ) { return this._w; }
    get h( ) { return this._h; }
    set w(w) { this.setSize(w, this._h); }
    set h(h) { this.setSize(this._w, h); }

    /* Change the size of the area. The sizes of the layers do not change.
     * Uncovered part of the image is transparent, while the overflow is hidden. */
    setSize(w, h)
    {
        this.element.style.width  = (this._w = w) + "em";
        this.element.style.height = (this._h = h) + "em";
        this.selection = this.selection;  // refresh the selection UI
    }

    get scale()
    {
        return this._scale;
    }

    set scale(x)
    {
        this._scale = Math.max(0.05, Math.min(20, x));
        this.element.style.fontSize = `${this._scale}px`;
        this.restyleCrosshair();
        // TODO make the viewport centered at the same position as it was
    }

    get selection()
    {
        return this._selection;
    }

    set selection(paths)
    {
        this._selection = paths;  // TODO grayscale masks
        this.select_ui.width  = this.w;
        this.select_ui.height = this.h;
        this.select_ui.style.width  = this.w + "em";
        this.select_ui.style.height = this.h + "em";
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
        this.undos.splice(Area.UNDO_OPS_LIMIT);
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
        this.snap({index: index, action: Area.UNDO_ADD_LAYER, state: null});
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

        this.snap({index: i, action: Area.UNDO_DEL_LAYER});
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

        this.snap({index: i, action: Area.UNDO_MOVE_LAYER, delta: delta, state: null});
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

        this.snap({index: i, action: Area.UNDO_MERGE_DOWN, below: this.layers[i + 1].state});

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
            case Area.UNDO_ADD_LAYER:
                this.deleteLayer(data.index);
                break;

            case Area.UNDO_DEL_LAYER:
                this.createLayer(data.index, data.state);
                break;

            case Area.UNDO_MOVE_LAYER:
                this.moveLayer(data.index + data.delta, -data.delta);
                break;

            case Area.UNDO_MERGE_DOWN:
                this.createLayer(data.index, data.state);
                this.layers[data.index + 1].state = data.below;
                // createLayer has pushed an UNDO_ADD_LAYER onto the undo stack.
                this.undos[0].action = Area.UNDO_UNMERGE;
                break;

            case Area.UNDO_UNMERGE:
                this.mergeDown(data.index);
                break;

            default:
                this.snap({index: data.index, action: Area.UNDO_DRAW});
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
                img.onload = () => this.setSize(img.width, img.height);
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
                    data: x.getAttribute('xlink:href'),
                    visible: x.getAttribute('visibility') !== 'hidden',
                    opacity: x.getAttribute('opacity'),
                    blendMode: x.style.mixBlendMode,
                });
            }

            if (forceSize)
                this.setSize(parseInt(root.getAttribute('width')),
                             parseInt(root.getAttribute('height')));
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
