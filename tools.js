"use strict"; /* global Dynamic, Path2D */


// Something to draw with.
//
// Options::
//
//   dynamic  :: [Dynamic] -- see `dynamic.js`
//   size     :: float -- greater than 0
//   H, S, L  :: int -- same ranges as in CSS3 `hsl` function. Same purpose, too.
//   opacity  :: float -- 0 to 1, transparent to opaque
//   rotation :: float -- 0 to 2pi
//   spacing  :: float -- greater or equal to 1, only affects pattern brushes
//
class Tool {
    get spacingAdjust() {
        // multiply by the size to get additional spacing between draw events.
        // a transparent edge will become opaque when drawn too many times
        // near the same spot.
        return 0.1;
    }

    get glyph() {
        // Can be a string specifying a FontAwesome character to use an an icon.
        return null;
    }

    constructor(area, options) {
        this.area = area;
        this.options = {};
        this.setOptions({
            dynamic: Dynamic.DEFAULT_SET,
            rotation: 0,
            spacing:  1,
            opacity:  1,
            size:     1,
            H: 0, S: 0, L: 0
        });

        this.setOptions(options);
    }

    /* Change some of the values. The rest remain intact. */
    setOptions(options) {
        for (let k in options)
            if (options.hasOwnProperty(k))
                this.options[k] = options[k];
    }

    // Lifecycle of a tool::
    //
    //   * When some options are modified, `crosshair` is called with a context of an
    //     `options.size`x`options.size` canvas. The tool must use it to draw something
    //     that represents the outline of whatever it will paint onto the layer.
    //   * `symbol` is basically the same thing, but requires a filled shape at specific
    //     center coordinates. That shape will be displayed as an icon for that tool.
    //   * At the start of a single stroke, `start` is called.
    //   * Then `move` is called for each movement event. (All positions are absolute.)
    //   * When the mouse button is released, `stop` is called.
    //
    crosshair(ctx) { /* empty crosshair is a simple cursor */ }
    start(ctx, x, y, pressure, rotation) {}
    move (ctx, x, y, pressure, rotation) {}
    stop (ctx) {}

    symbol(ctx, x, y)
    {
        if (this.glyph) {
            const opts = this.options;
            ctx.save();
            ctx.font = `${opts.size}px FontAwesome`;
            ctx.fillStyle = `hsla(${opts.H},${opts.S}%,${opts.L}%,${opts.opacity})`;
            // these coordinates are the left end of the baseline segment.
            ctx.fillText(this.glyph, x - opts.size / 2, y + opts.size / 2.5);
            ctx.restore();
        } else {
            this.start(ctx, x, y, 1, 0);
            this.stop (ctx);
        }
    }
}


class ColorpickerTool extends Tool
{
    get glyph()
    {
        return '\uf1fb';  // a dropper
    }

    start(ctx, x, y)
    {
        const img = this.area.save('flatten');
        this.stride = img.width;
        this.imdata = img.getContext('2d').getImageData(0, 0, img.width, img.height).data;
        this.move(ctx, x, y);
    }

    move(ctx, x, y)
    {
        const i = 4 * (Math.floor(x) + this.stride * Math.floor(y)),
              r = this.imdata[i + 0] / 255,
              g = this.imdata[i + 1] / 255,
              b = this.imdata[i + 2] / 255;

        const m = Math.min(r, g, b),
              M = Math.max(r, g, b),
              L = (m + M) / 2,
              S = M - m < 0.001 ? 0 : (M - m) / (L < 0.5 ? M + m : 2 - M - m),
              H = M - m < 0.001 ? 0 :
                  M == r ?     (g - b) / (M - m) :
                  M == g ? 2 + (b - r) / (M - m) :
                  M == b ? 4 + (r - g) / (M - m) : 0;

        this.area.setToolOptions({H: H * 60, S: S * 100, L: L * 100});
    }

    stop(ctx)
    {
        this.imdata = null;
    }
}


class MoveTool extends Tool
{
    get glyph()
    {
        return '\uf047';  // arrows in 4 directions
    }

    start(ctx, x, y)
    {
        this.layer = this.area.layers[this.area.layer];
        this.lastX = x;
        this.lastY = y;
    }

    move(ctx, x, y)
    {
        this.layer.move(this.layer.x + (x - this.lastX), this.layer.y + (y - this.lastY));
        this.lastX = x;
        this.lastY = y;
    }
}


class SelectionTool extends Tool
{
    start(ctx, x, y)
    {
        this.old = this.area.selection;
        this.startX = x;
        this.startY = y;
        this.dX = 0;
        this.dY = 0;
    }

    move(ctx, x, y)
    {
        let dx = x - this.startX;
        let dy = y - this.startY;

        if (window.SHIFT && dx !== 0 && dy !== 0) {  // Shift+drag: lock aspect ratio at 1
            const m = Math.min(Math.abs(dx), Math.abs(dy));
            dy *= m / Math.abs(dy);
            dx *= m / Math.abs(dx);
        }

        this.dX = Math.abs(dx);
        this.dY = Math.abs(dy);

        const path = new Path2D();
        const paths = [];
        this.select(path, this.startX + Math.min(0, dx),
                          this.startY + Math.min(0, dy), this.dX, this.dY);

        if (window.CTRL && window.ALT) {  // Ctrl+Alt+drag -- XOR
            for (let p of this.old)
                paths.push(p);

            paths.push(path);
        } else if (window.CTRL && this.old) {  // Ctrl+drag -- union
            for (let p of this.old) {
                const upath = new Path2D();
                upath.addPath(path);
                upath.addPath(p);
                paths.push(upath);
            }
        } else if (window.ALT) {  // Alt+drag -- subtraction
            for (let p of this.old)
                paths.push(p);

            const npath = new Path2D();
            // fill the whole image with a rectangle of negative winding.
            // (`path` has positive winding to counteract it.)
            // the dimensions are greater than `this.area.w * this.area.h`
            // because the area may increase in size later.
            npath.rect(0, 100000, 100000, -100000);
            npath.addPath(path);
            paths.push(npath);
        } else {  // no modifiers -- replace
            paths.push(path);
        }

        this.area.selection = paths;
    }

    stop(ctx)
    {
        if (this.dX + this.dY < 5 && !window.CTRL && !window.ALT && !window.SHIFT)
            this.area.selection = [];
    }

    symbol(ctx, x, y)
    {
        const opts = this.options;
        ctx.save();
        ctx.lineWidth = 1;
        ctx.globalAlpha = opts.opacity;
        ctx.setLineDash([5, 5]);
        ctx.strokeStyle = `hsl(${opts.H},${opts.S}%,${opts.L}%)`;
        ctx.beginPath();
        this.select(ctx, x - opts.size / 2, y - opts.size / 2, opts.size, opts.size);
        ctx.stroke();
        ctx.restore();
    }
}


class RectSelectionTool extends SelectionTool
{
    select(path, x, y, dx, dy)
    {
        path.rect(x, y, dx, dy);
    }
}


class EllipseSelectionTool extends SelectionTool
{
    select(path, x, y, dx, dy)
    {
        path.ellipse(x + dx / 2, y + dy / 2, dx / 2, dy / 2, 0, 0, Math.PI * 2);
    }
}


class PenTool extends Tool
{
    crosshair(ctx)
    {
        const eraser = this.options.eraser;
        const opts = {H: 0, S: 0, L: 50, opacity: this.options.opacity / 2, dynamic: [], eraser: false};
        Object.setPrototypeOf(opts, this.options);
        this.options = opts;
        this.start(ctx, 0, 0, 1, 0);
        this.stop (ctx);
        if (eraser) {
            this.options.eraser = true;
            this.options.size -= Math.min(this.options.size, 2);
            this.options.opacity *= 1.5;
            this.start(ctx, 0, 0, 1, 0);
            this.stop (ctx);
        }
        this.options = Object.getPrototypeOf(opts);
    }

    start(ctx, x, y, pressure, rotation)
    {
        this.prevX = x;
        this.prevY = y;
        const opts = this.options;
        ctx.save();
        ctx.lineWidth   = opts.size;
        ctx.globalAlpha = opts.opacity;
        ctx.strokeStyle = ctx.fillStyle = `hsl(${opts.H},${opts.S}%,${opts.L}%)`;
        if (opts.eraser)
            ctx.globalCompositeOperation = "destination-out";
        for (let dyn of opts.dynamic) {
            dyn.reset(ctx, this, x, y);
            dyn.start(ctx, this, 0, 0, pressure, rotation);
            dyn.step(ctx, this, 1);
        }
        this.step(ctx, x, y);
        for (let dyn of this.options.dynamic)
            dyn.stop(ctx, this);

    }

    move(ctx, x, y, pressure, rotation)
    {
        const dx = x - this.prevX;
        const dy = y - this.prevY;
        const sp = this.options.spacing + ctx.lineWidth * this.spacingAdjust;
        const steps = Math.floor(Math.sqrt(dx * dx + dy * dy) / sp);
        if (!steps)
            return;
        for (let dyn of this.options.dynamic)
            dyn.start(ctx, this, dx, dy, pressure, rotation);
        const dx_step = dx / steps;
        const dy_step = dy / steps;
        x = this.prevX;
        y = this.prevY;
        for (let k = 0; k < steps; k++) {
            for (let dyn of this.options.dynamic)
                dyn.step(ctx, this, steps);
            // TODO: interpolate; browsers tend to skip lots of events during fast movements
            this.step(ctx, x += dx_step, y += dy_step);
        }
        for (let dyn of this.options.dynamic)
            dyn.stop(ctx, this);
        this.prevX = x;
        this.prevY = y;
    }

    step(ctx, x, y)
    {
        ctx.beginPath();
        ctx.arc(x, y, ctx.lineWidth / 2, 0, 2 * Math.PI);
        ctx.fill();
    }

    stop(ctx)
    {
        for (let dyn of this.options.dynamic)
            dyn.restore(ctx, this);

        ctx.restore();
    }
}


class ImagePenTool extends PenTool
{
    get img()
    {
        return null;
    }

    start(ctx, x, y, pressure, rotation)
    {
        const size = this.options.size;
        this.pattern = document.createElement('canvas');
        this.pattern.width  = size;
        this.pattern.height = size;
        const imctx = this.pattern.getContext('2d');
        imctx.fillStyle = `hsl(${this.options.H},${this.options.S}%,${this.options.L}%)`;
        imctx.fillRect(0, 0, size, size);
        imctx.globalCompositeOperation = "destination-in";
        imctx.drawImage(this.img, 0, 0, size, size);
        super.start(ctx, x, y, pressure, rotation);
    }

    step(ctx, x, y)
    {
        const ds = ctx.lineWidth;
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(this.options.rotation);
        ctx.drawImage(this.pattern, -ds / 2, -ds / 2, ds, ds);
        ctx.restore();
    }

    static make(element, spacing)
    {
        if (spacing === undefined)
            spacing = 0.1;

        class T extends ImagePenTool
        {
            get img()
            {
                return element;
            }

            get spacingAdjust()
            {
                return spacing;
            }
        }

        return T;
    }
}
