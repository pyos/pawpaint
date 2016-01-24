"use strict";


// A way to change some parameters based on some other parameters.
//
// Options::
//   max   -- each result (in 0..1) is scaled to fit into this range
//   min   --
//   type  -- which parameter to use (velocity, direction, pressure, rotation, random)
//   avgOf -- size of the window to use for smoothing the values
//
class Dynamic
{
    constructor(options)
    {
        this.type  = 0;
        this.min   = 0;
        this.max   = 1;
        this.avgOf = 10;

        for (var k in options)
            this[k] = options[k];
    }

    // Lifecycle of a `Dynamic`:
    //
    //   1. When the user begins drawing: `reset(context)`
    //   2. Before a single path leg is drawn: `start(context, tool, dx, dy, steps)`
    //      where `steps` is how many times `step` will be called.
    //   3. While drawing a single path leg: `step(context)` should gradually change
    //      something to the desired value.
    //   4. After a path leg is drawn: `stop(context)`.
    //   5. When done drawing: `restore(context)`.
    //
    reset(ctx, tool)
    {
        var value = 0;
        var count = 0;
        var array = [];

        this._f = (current) => {
            if (count === 0) {
                for (var i = 0; i < this.avgOf; i++)
                    array.push(current);

                value = current;
            } else {
                value += (current - array[count % this.avgOf]) / this.avgOf;
                array[count % this.avgOf] = current;
            }

            count++;
            return value;
        };
    }

    start(ctx, tool, dx, dy, pressure, rotation)
    {
        var v;

        switch (this.type) {
            case 1:  v = atan2(dy, dx) / 2 / PI + 0.5; break;
            case 2:  v = pressure; break;
            case 3:  v = rotation / 2 / PI; break;
            case 4:  v = Math.random(); break;
            default: v = pow(dx * dx + dy * dy, 0.5) / 20; break;
        }

        return this.min + (this.max - this.min) * min(1, max(0, this._f(v)));
    }

    step(ctx, tool, total) {}
    stop(ctx, tool) {}
    restore(ctx, tool) {}
}


// A dynamic that changes some property of the canvas that has an associated
// tool option (e.g. `context.lineWidth` <=> `tool.options.size`).
//
// Options::
//   source -- the option to use as an upper limit (see `Tool.options`)
//   target -- the property of a 2d context to update with the result
//   tgcopy -- the option of the tool to update with the result
//
class OptionDynamic extends Dynamic
{
    reset(ctx, tool)
    {
        super.reset();
        this._limit   = this.source ? tool.options[this.source] : 1;
        this._restore = this.tgcopy ? tool.options[this.tgcopy] : 0;
        this._first   = true;
    }

    start(ctx, tool, dx, dy, pressure, rotation)
    {
        this._value = super.start(ctx, tool, dx, dy, pressure, rotation) * this._limit;

        if (this._first) {
            this.stop(ctx, tool);
            this._delta = 0;
            this._first = false;
        } else if (this.target) {
            this._delta = this._value - ctx[this.target];
        } else {
            this._delta = this._value - tool.options[this.tgcopy];
        }
    }

    step(ctx, tool, total)
    {
        if (this.tgcopy)
            tool.options[this.tgcopy] += this._delta / total;

        if (this.target)
            ctx[this.target] += this._delta / total;
    }

    stop(ctx, tool)
    {
        if (this.tgcopy)
            tool.options[this.tgcopy] = this._value;

        if (this.target)
            ctx[this.target] = this._value;
    }

    restore(ctx, tool)
    {
        if (this.tgcopy)
            tool.options[this.tgcopy] = this._restore;
    }
}
