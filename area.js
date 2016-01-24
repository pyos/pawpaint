"use strict";


class Area
{
    static get UNDO_OPS_LIMIT  () { return 25; }
    static get UNDO_DRAW       () { return 0; }
    static get UNDO_ADD_LAYER  () { return 1; }
    static get UNDO_DEL_LAYER  () { return 2; }
    static get UNDO_MOVE_LAYER () { return 3; }
    static get UNDO_MERGE_DOWN () { return 4; }

    constructor(element)
    {
        this.element    = element;
        this._scale     = 1;
        this.layer      = 0;
        this.w          = 0;
        this.h          = 0;
        this.layers     = [];  // :: [Layer]
        this.undos      = [];  // :: [{action, index, state, ...}]
        this.redos      = [];
        this.events     = {};
        this._selection = [];  // :: [Path2D]
        this.select_ui  = $('<canvas width="0" height="0">').addClass('hidden selection').appendTo(element)[0];
        this.crosshair  = $('<canvas width="0" height="0">').addClass('crosshair').appendTo('body')[0];
        this.drawing    = false;

        let context = null;

        const onDown = (ev) =>
        {
            if (!this.layers.length || !this.tool)
                return false;

            const layer = this.layers[this.layer];
            context = layer.img().getContext('2d');
            context.save();
            context.translate(0.5 - layer.x, 0.5 - layer.y);

            for (const path of this.selection)
                context.clip(path);

            const r = element.getBoundingClientRect();
            const x = (ev.clientX - r.left) / this.scale;
            const y = (ev.clientY - r.top)  / this.scale;
            this.drawing = true;
            this.snap({index: this.layer, action: Area.UNDO_DRAW});
            this.tool.start(context, x, y, ev.force || 0, (ev.rotationAngle || 0) / 360);
            return true;
        };

        const onMove = (ev) =>
        {
            const r = element.getBoundingClientRect();
            const x = (ev.clientX - r.left) / this.scale;
            const y = (ev.clientY - r.top)  / this.scale;
            this.tool.move(context, x, y, ev.force || 0, (ev.rotationAngle || 0) / 360);
        };

        const onUp = () =>
        {
            this.tool.stop(context);
            this.trigger('layer:redraw', this.layers[this.layer], this.layer);
            this.drawing = false;
            context.restore();
            context = null;
        };

        // When using tablets, evdev may bug out and send the cursor jumping when doing
        // fine movements. To prevent this, we're going to ignore extremely fast
        // mouse movement events.
        let lastX = 0;
        let lastY = 0;

        const isValidMouseEvent = (ev) => {
            if (Math.abs(ev.pageX - lastX) + Math.abs(ev.pageY - lastY) < 200) {
                lastX = ev.pageX;
                lastY = ev.pageY;
                return true;
            }

            return false;
        };

        const onMouseDown = (ev) =>
        {
            if (ev.which === 1 && (ev.buttons === undefined || ev.buttons === 1)) {
                // FIXME this prevents unwanted selection, but breaks focusing.
                ev.preventDefault();
                lastX = ev.pageX;
                lastY = ev.pageY;

                if (onDown(ev)) {
                    element.addEventListener('mouseup',    onMouseUp);
                    element.addEventListener('mouseleave', onMouseUp);
                    element.addEventListener('mousemove',  onMouseMove);
                    element.addEventListener('mouseenter', onMouseDown);
                }
            }
        };

        const onMouseMove = (ev) => { if (isValidMouseEvent(ev)) onMove(ev); };
        const onMouseUp = (ev) =>
        {
            if (ev.type === "mouseup" || isValidMouseEvent(ev)) {
                onUp();
                element.removeEventListener('mouseup',    onMouseUp);
                element.removeEventListener('mouseleave', onMouseUp);
                element.removeEventListener('mousemove',  onMouseMove);
                if (ev.type !== 'mouseleave')
                    element.removeEventListener('mouseenter', onMouseDown);
            }
        };

        const onTouchDown = (ev) =>
        {
            if (ev.touches.length === 1 && ev.which === 0) {
                // FIXME this one is even worse depending on the device.
                //   On Chromium OS, this will prevent "back/forward" gestures from
                //   interfering with drawing, but will not focus the broswer window
                //   if the user taps the canvas.
                ev.preventDefault();

                if (onDown(ev.touches[0])) {
                    element.addEventListener('touchmove', onTouchMove);
                    element.addEventListener('touchend',  onTouchUp);
                }
            }
        };

        const onTouchMove = (ev) => { onMove(ev.touches[0]); };
        const onTouchUp = (ev) =>
        {
            if (ev.touches.length === 0) {
                onUp();
                element.removeEventListener('touchmove', onTouchMove);
                element.removeEventListener('touchend',  onTouchUp);
            }
        };

        element.addEventListener('mousedown',  onMouseDown);
        element.addEventListener('touchstart', onTouchDown);
        element.addEventListener('mouseleave', (ev) => { this.crosshair.style.display = 'none' });
        element.addEventListener('touchstart', (ev) => { this.crosshair.style.display = 'none' });
        element.addEventListener('mousemove',  (ev) => {
            this.crosshair.style.left = ev.pageX + 'px';
            this.crosshair.style.top  = ev.pageY + 'px';
            this.crosshair.style.display = '';
        });
    }

    on(name, fn)
    {
        for (const n of name.split(' ')) {
            this.events[n] = this.events[n] || [];
            this.events[n].push(fn);
        }

        return this;
    }

    trigger(name, ...args)
    {
        if (!this.events.hasOwnProperty(name))
            return false;

        for (const fn of this.events[name] || [])
            fn.apply(this, args);

        return true;
    }

    onLayerRedraw(layer)
    {
        this.trigger('layer:redraw', layer, this.layers.indexOf(layer));
        this.restyleLayers();
    }

    onLayerResize(layer)
    {
        this.trigger('layer:resize', layer, this.layers.indexOf(layer));
        this.restyleLayers();
    }

    restyleCrosshair()
    {
        const sz = this.tool.options.size * this.scale;
        const cr = $(this.crosshair);
        cr.attr({'width': sz, 'height': sz});
        cr.css({'margin-left': -sz / 2, 'margin-top': -sz / 2});

        if (this.tool.options.size > 5)
            cr.removeClass('hidden');
        else
            cr.addClass('hidden');

        const ctx = this.crosshair.getContext('2d');
        ctx.translate(sz / 2, sz / 2);
        ctx.scale(this.scale, this.scale);
        this.tool.crosshair(ctx);  // FIXME this goes out of bounds sometimes
    }

    restyleLayers()
    {
        for (const n in this.layers) {
            this.layers[n].active = n == this.layer;
            this.layers[n].restyle(this.layers.length - n, this.scale);
        }
    }

    /* Change the size of the area. The sizes of the layers do not change.
     * Uncovered part of the image is transparent, while the overflow is hidden. */
    setSize(w, h)
    {
        this.w = w;
        this.h = h;
        this.element.style.width  = (this.select_ui.width  = w * this.scale) + "px";
        this.element.style.height = (this.select_ui.height = h * this.scale) + "px";
        this.selection = this.selection;  // refresh the selection UI
    }

    get scale()
    {
        return this._scale;
    }

    set scale(x)
    {
        this._scale = Math.max(0, Math.min(20, x));
        this.setSize(this.w, this.h);
        this.restyleCrosshair();
        this.restyleLayers();
        // TODO make the viewport centered at the same position as it was
    }

    get selection()
    {
        return this._selection;
    }

    set selection(paths)
    {
        this._selection = paths;

        if (paths.length) {
            this.select_ui.className = "selection";
            // TODO an animated dashed border instead of this:
            const ctx = this.select_ui.getContext('2d');
            ctx.save();
            ctx.scale(this.scale, this.scale);
            ctx.fillStyle = "hsl(0, 0%, 50%)";
            ctx.fillRect(0, 0, this.w, this.h);
            for (const path of paths) ctx.clip(path);
            ctx.clearRect(0, 0, this.w, this.h);
            ctx.restore();
        } else {
            this.select_ui.className = "hidden selection";
        }
    }

    /* Save a snapshot of a single layer in the undo stack.
     * Meanwhile, the redo stack is reset. */
    snap(options)
    {
        if (options.state === undefined)
            options.state = this.layers[options.index].state(true);

        this.redos = [];
        this.undos.splice(0, 0, options);
        this.undos.splice(Area.UNDO_OPS_LIMIT);
    }

    /* Create an empty layer at a given position in the stack,
     * optionally from a previously saved `Layer` state. */
    createLayer(index, state)
    {
        const layer = new Layer(this);
        this.layers.splice(index, 0, layer);
        this.trigger('layer:add', layer, index);

        if (state)
            layer.load(state);
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

        this.restyleLayers();
        this.trigger('layer:set', this.layer = i);
    }

    /* Remove a layer from the stack. */
    deleteLayer(i)
    {
        if (i < 0 || this.layers.length <= i)
            return;

        this.snap({index: i, action: Area.UNDO_DEL_LAYER});
        this.layers[i].clear();
        this.layers.splice(i, 1);
        this.trigger('layer:del', i);
        this.setLayer(Math.min(this.layer, this.layers.length - 1));
    }

    /* Move a layer `delta` positions up the stack. Negative values shift down.
     * The layer is automatically selected for drawing. */
    moveLayer(i, delta)
    {
        if (i + Math.min(delta, 0) < 0 || this.layers.length <= i + Math.max(delta, 0))
            return;

        this.snap({index: i, action: Area.UNDO_MOVE_LAYER, delta: delta});
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

        this.snap({index: i, action: Area.UNDO_MERGE_DOWN, below: this.layers[i + 1].state(true)});

        const top = this.layers[i];
        const bot = this.layers[i + 1];

        bot.crop(Math.min(top.x, bot.x), Math.min(top.y, bot.y),
                 Math.max(top.w + top.x, bot.w + bot.x) - Math.min(top.x, bot.x),
                 Math.max(top.h + top.y, bot.h + bot.y) - Math.min(top.y, bot.y));

        const ctx = bot.img().getContext('2d');
        ctx.save();
        ctx.translate(-bot.x, -bot.y);
        top.drawOnto(ctx);
        top.clear();
        ctx.restore();

        this.onLayerRedraw(bot);
        this.layers.splice(i, 1);
        this.trigger('layer:del', i);
        this.setLayer(Math.min(this.layer, this.layers.length - 1));
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
                if (reverse) {
                    this.mergeDown(data.index);
                    break;
                }

                this.createLayer(data.index, data.state);
                this.layers[data.index + 1].load(data.below);
                // createLayer has pushed an UNDO_ADD_LAYER onto the undo stack.
                this.undos[0].action = Area.UNDO_MERGE_DOWN;
                break;

            default:
                this.snap({index: data.index, action: Area.UNDO_DRAW});
                this.layers[data.index].load(data.state);
                break;
        }

        // The above operations all call `snap`, which resets the redo stack and adds something
        // to `undos`. We don't want the former, and possibly the latter, too.
        this.redos = redos;

        if (!reverse)
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
    export(type)
    {
        switch (type) {
            case "flatten":
                const cnv = document.createElement('canvas');
                cnv.width  = this.w;
                cnv.height = this.h;
                const ctx = cnv.getContext('2d');
                for (let n = this.layers.length; n;) this.layers[--n].drawOnto(ctx);
                return cnv;

            case "png":
                return this.export("flatten").toDataURL("image/png");

            case "svg":
                const tag = $("<svg:svg xmlns:svg='http://www.w3.org/2000/svg' width='" + this.w + "' "
                                + "xmlns:xlink='http://www.w3.org/1999/xlink' height='" + this.h + "'>");
                for (const layer of this.layers) tag.prepend(layer.svg());
                // force the bottommost layer to have a "normal" blending mode
                // should this image be inserted into an html document.
                tag.css('isolation', 'isolate');
                return "data:image/svg+xml;base64," + btoa(new XMLSerializer().serializeToString(tag[0]));

            default: return null;
        }
    }

    /* Deserialize an image and add it on top of the existing one. Supported
     * formats: image/png and image/svg+xml; the latter allows importing many
     * layers at once. Set forceSize = true to resize the area to fit the new layer.
     * Returns true on a successful import. */
    import(data, forceSize)
    {
        forceSize = forceSize || this.layers.length === 0;

        if (data.slice(0, 22) == 'data:image/png;base64,') {
            const img = new Image();
            img.onload = () => {
                const state = {x: 0, y: 0, w: img.width, h: img.height, data: data};

                this.createLayer(0, state);

                if (forceSize)
                    this.setSize(img.width, img.height);
            };
            img.src = data;
            return true;
        }

        if (data.slice(0, 26) == 'data:image/svg+xml;base64,') {
            const doc = $(atob(data.slice(26)));

            doc.children().each((_, x) =>
                this.createLayer(0, {
                    x: parseInt(x.getAttribute('x')),
                    y: parseInt(x.getAttribute('y')),
                    w: parseInt(x.getAttribute('width')),
                    h: parseInt(x.getAttribute('height')),
                    data: x.getAttribute('xlink:href'),
                    hidden: x.getAttribute('visibility') == 'hidden',
                    blendMode: x.style.mixBlendMode,
                })
            );

            if (forceSize)
                this.setSize(parseInt(doc.attr('width')), parseInt(doc.attr('height')));

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
                file.onload = (r) => this.import(r.target.result);
                file.readAsDataURL(data.files[i]);
            }
        }

        for (let j = 0; j < data.types.length; j++)
            if (data.types[j] && data.types[j].match(/image\/.*/))
                this.import(data.getData(data.types[j]));
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

        if (options.kind)
            // if the tool has changed, emit every event.
            options = this.tool.options;

        for (const k in options)
            this.trigger('tool:' + k, options[k], this.tool.options);

        this.trigger('tool:options', this.tool.options);
        return true;
    }
}
