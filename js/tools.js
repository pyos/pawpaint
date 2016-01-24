"use strict";


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
class Tool
{
    get spacingAdjust()
    {
        // multiply by the size to get additional spacing between draw events.
        // a transparent edge will become opaque when drawn too many times
        // near the same spot.
        return 0.1;
    }

    get glyph()
    {
        // Can be a string specifying a FontAwesome character to use an an icon.
        return null;
    }

    constructor(area, options)
    {
        this.area = area;
        this.options = {};
        this.setOptions({
            dynamic: [],
            rotation: 0,
            spacing:  1,
            opacity:  1,
            size:     1,
            H: 0, S: 0, L: 0
        });

        this.setOptions(options);
    }

    /* Change some of the values. The rest remain intact. */
    setOptions(options)
    {
        for (var k in options)
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
            ctx.save();
            ctx.rotate(this.options.rotation);
            ctx.font = `${this.options.size}px FontAwesome`;
            ctx.fillStyle = `hsla(${this.options.H},${this.options.S}%,${this.options.L}%,${this.options.opacity})`;
            // these coordinates are the left end of the baseline segment.
            ctx.fillText(this.glyph, x - this.options.size / 2, y + this.options.size / 2.5);
            ctx.restore();
        } else {
            this.start(ctx, x, y, 1, 0);
            this.move (ctx, x, y, 1, 0);
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
        var canvas = this.area.export('flatten');
        this.stride = canvas.width;
        this.imdata = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
        this.move(ctx, x, y);
    }

    move(ctx, x, y)
    {
        var i = floor(x) * 4 + this.stride * floor(y) * 4,
            r = this.imdata[i + 0] / 255,
            g = this.imdata[i + 1] / 255,
            b = this.imdata[i + 2] / 255;

        var m = min(r, g, b),
            M = max(r, g, b),
            L = (m + M) / 2,
            S = M - m < 0.001 ? 0 : (M - m) / (L < 0.5 ? M + m : 2 - M - m),
            H = M - m < 0.001 ? 0 :
                M == r ?     (g - b) / (M - m) :
                M == g ? 2 + (b - r) / (M - m) :
                M == b ? 4 + (r - g) / (M - m) : 0;

        this.area.setToolOptions({H: round(H * 60), S: round(S * 100), L: round(L * 100)});
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
        var dx = x - this.startX;
        var dy = y - this.startY;

        if (SHIFT) {  // Shift+drag: lock aspect ratio at 1
            var m = min(abs(dx), abs(dy));
            dy *= m / abs(dy);
            dx *= m / abs(dx);
        }

        this.dX = dx;
        this.dY = dy;

        var path = new Path2D();
        this.select(path, this.startX + min(0, dx), this.startY + min(0, dy), abs(dx), abs(dy));
        var paths = [];

        if (CTRL && ALT) {  // Ctrl+Alt+drag -- XOR
            for (var p of this.old)
                paths.push(p);

            paths.push(path);
        } else if (CTRL) {  // Ctrl+drag -- union
            for (var q of this.old) {
                var upath = new Path2D();
                upath.addPath(path);
                upath.addPath(q);
                paths.push(upath);
            }
        } else if (ALT) {  // Alt+drag -- subtraction
            for (var r of this.old)
                paths.push(r);

            var npath = new Path2D();
            // fill the whole image with a rectangle of negative winding.
            // (`path` has positive winding to counteract it.)
            // the dimensions are greater than `this.area.w * this.area.h`
            // because the area may increase in size later.
            npath.rect(0, 100000, 100000, -100000);
            npath.addPath(path);
            paths.push(npath);
        } else {  // no modifiers -- replace
            paths = [path];
        }

        this.area.setSelection(paths);
    }

    stop(ctx)
    {
        if (this.dX + this.dY < 5 && !CTRL && !ALT && !SHIFT)
            this.area.setSelection([]);
    }

    symbol(ctx, x, y)
    {
        ctx.save();
        ctx.lineWidth = 1;
        ctx.globalAlpha = this.options.opacity;
        ctx.setLineDash([5, 5]);
        ctx.strokeStyle = `hsl(${this.options.H},${this.options.S}%,${this.options.L}%)`;
        ctx.beginPath();
        this.select(ctx, x - this.options.size / 2, y - this.options.size / 2, this.options.size, this.options.size);
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
        path.ellipse(x + dx / 2, y + dy / 2, dx / 2, dy / 2, 0, 0, PI * 2);
    }
}


class PenTool extends Tool
{
    crosshair(ctx)
    {
        var opts = {H: 0, S: 0, L: 50, opacity: 0.5, dynamic: []};
        Object.setPrototypeOf(opts, this.options);
        this.options = opts;
        this.start(ctx, 0, 0, 1, 0);
        this.move (ctx, 0, 0, 1, 0);
        this.stop (ctx);
        this.options = Object.getPrototypeOf(opts);
    }

    start(ctx, x, y, pressure, rotation)
    {
        ctx.save();
        ctx.lineWidth   = this.options.size;
        ctx.globalAlpha = this.options.opacity;
        ctx.strokeStyle = ctx.fillStyle = `hsl(${this.options.H},${this.options.S}%,${this.options.L}%)`;
        for (var dyn of this.options.dynamic)
            dyn.reset(ctx, this, x, y);
        this.windowX = [this.prevX = x, x, x];
        this.windowY = [this.prevY = y, y, y];
        this.empty = 1;
        this.count = 0;
    }

    move(ctx, x, y, pressure, rotation)
    {
        // target = moving average of 5 last points including (x, y)
        var i = this.count % this.windowX.length;
        var dx = (x - this.windowX[i]) / this.windowX.length;
        var dy = (y - this.windowY[i]) / this.windowY.length;
        var sp = this.options.spacing + ctx.lineWidth * this.spacingAdjust;
        var steps = floor(pow(dx * dx + dy * dy, 0.5) / sp) || this.empty;

        if (steps) {
            this.count++;
            this.windowX[i] = x;
            this.windowY[i] = y;
            for (var dyn of this.options.dynamic)
                dyn.start(ctx, this, dx, dy, pressure, rotation);

            dx /= steps;
            dy /= steps;
            var sx = this.prevX;
            var sy = this.prevY;

            for (var k = 0; k < steps; k++) {
                for (var dyn of this.options.dynamic)
                    dyn.step(ctx, this, steps);

                this.step(ctx, sx, sy, sx += dx, sy += dy);
            }

            for (var dyn of this.options.dynamic)
                dyn.stop(ctx, this);

            this.empty = 0;
            this.prevX = sx;
            this.prevY = sy;
        }
    }

    step(ctx, x, y, nx, ny)
    {
        ctx.beginPath();
        ctx.arc(nx, ny, ctx.lineWidth / 2, 0, 2 * PI);
        ctx.fill();
    }

    stop(ctx)
    {
        for (var dyn of this.options.dynamic)
            dyn.restore(ctx, this);

        ctx.restore();
    }
}


class EraserTool extends PenTool
{
    get glyph()
    {
        return '\uf12d';  // an eraser, duh
    }

    crosshair(ctx)
    {
        ctx.save();
        ctx.lineWidth   = 1;
        ctx.globalAlpha = 0.5;
        ctx.beginPath();
        ctx.arc(0, 0, this.options.size / 2, 0, 2 * PI, false);
        ctx.stroke();
        ctx.restore();
    }

    start(ctx, x, y, pressure, rotation)
    {
        super.start(ctx, x, y, pressure, rotation);
        ctx.globalCompositeOperation = "destination-out";
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
        var size = this.options.size;
        this.pattern = new Canvas(size, size)[0];
        var imctx = this.pattern.getContext('2d');
        imctx.fillStyle = `hsl(${this.options.H},${this.options.S}%,${this.options.L}%)`;
        imctx.fillRect(0, 0, size, size);
        imctx.globalCompositeOperation = "destination-in";
        imctx.drawImage(this.img, 0, 0, size, size);
        super.start(ctx, x, y, pressure, rotation);
    }

    step(ctx, x, y, nx, ny)
    {
        var ds = ctx.lineWidth;
        ctx.save();
        ctx.translate(nx, ny);
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
