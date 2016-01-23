"use strict";


class Layer extends EventSystem
{
    // A single raster layer. Emits the following events:
    //
    //   resize (layer: Layer)  -- when the dimensions change
    //   redraw (layer: Layer)  -- when the contents change
    //   reprop (layer: Layer)  -- when some other property (e.g. opacity) changes
    //
    constructor(area)
    {
        super();
        this.area    = area;
        this.element = $([]);
        this.x = this.y = this.w = this.h = 0;
    }

    get active( ) { return this.element.hasClass('active'); }
    set active(v) { v ? this.element.addClass('active') : this.element.removeClass('active'); }

    get hidden( ) { return this.element.css('display') == 'none'; }
    set hidden(v) { return this.element.css('display', v ? 'none' : ''); }

    get opacity( ) { return this.element.css('opacity'); }
    set opacity(v) { return this.element.css('opacity', v); }

    get blendMode( ) { return this.element.css('mix-blend-mode'); }
    set blendMode(v) { return this.element.css('mix-blend-mode', v); }

    get fill( ) { return 'transparent'; }
    set fill(v)
    {
        var opt = this.area.tool.options;
        var ctx = this.img().getContext('2d');
        ctx.fillStyle = v == 'toolColor' ? `hsl(${opt.H},${opt.S}%,${opt.L}%)` : v;
        ctx.fillRect(0, 0, this.w, this.h);
        this.trigger('redraw', this);
    }

    // Remove the contents of this layer. (And the element that represents it.)
    clear()
    {
        this.element.remove();
        this.element = $([]);
        this.trigger('redraw', this);
    }

    // Change the position of this layer relative to the image.
    move(x, y)
    {
        this.x = x;
        this.y = y;
        this.trigger('resize', this);
    }

    // Change the size of this layer without modifying its contents.
    // The offset is relative to the image.
    crop(x, y, w, h)
    {
        var dx = this.x - x;
        var dy = this.y - y;
        this.w = w;
        this.h = h;
        this.move(x, y);
        this.replace(this.element, dx, dy, false);
    }

    // Change the size of this layer and scale the contents at the same time.
    resize(w, h)
    {
        this.w = w;
        this.h = h;
        this.trigger('resize', this);
        this.replace(this.element, 0, 0, true);
    }

    // Recreate the element that represents this layer from a set of canvases/images.
    // Optionally, rescale them to fit the new size.
    replace(imgs, x, y, rescale)
    {
        var tag = new Canvas(this.w, this.h).addClass('layer');
        var ctx = tag[0].getContext('2d');

        for (var i = 0; i < imgs.length; i++)
            if (rescale)
                ctx.drawImage(imgs[i], x, y, this.w, this.h);
            else
                ctx.drawImage(imgs[i], x, y);

        this.element.remove();
        this.element = tag.appendTo(this.area.element);
        this.trigger('redraw', this);
    }

    // Update the style of the element that represents this layer.
    restyle(index, scale)
    {
        this.element.css({
            'z-index': index,
            'left':   this.x * scale,
            'top':    this.y * scale,
            'width':  this.w * scale,
            'height': this.h * scale,
        });
    }

    // Load a layer from an old state. A state should contain fields `x`, `y`,
    // `w`, `h`, and `data`, plus optionally the values for the properties.
    // `data` may be either an URL or a Canvas image data array. If it is an URL,
    // it is loaded asynchronously, and `w`/`h` may be omitted.
    load(state)
    {
        if (typeof state.data !== 'string')
            return this.loadFromData(state, null);

        var img = new Image();
        img.onload = () => this.loadFromData(state, img);
        img.src = state.data;
    }

    loadFromData(state, img)
    {
        if (state.w === undefined)
            state.w = img.width;

        if (state.h === undefined)
            state.h = img.height;

        this.clear();
        this.crop(state.x, state.y, state.w, state.h);

        if (img)
            this.replace([img], 0, 0, false);
        else {
            this.replace([], 0, 0, false);  // create an empty canvas
            this.img().getContext('2d').putImageData(state.data, 0, 0);
            this.trigger('redraw', this);
        }

        if (state.blendMode !== undefined) this.blendMode = state.blendMode;
        if (state.opacity   !== undefined) this.opacity   = state.opacity;
        if (state.hidden    !== undefined) this.hidden    = state.hidden;
    }

    // Get the image/canvas that represents the contents of this layer.
    // Unlike `element[0]`, guaranteed to be defined.
    img()
    {
        return this.element.length ? this.element[0] : document.createElement('canvas');
    }

    // Draw the contents of this layer onto a 2D canvas context.
    drawOnto(ctx)
    {
        if (this.hidden)
            return;

        ctx.save();
        ctx.globalAlpha = parseFloat(this.opacity);
        ctx.globalCompositeOperation = this.blendMode === 'normal' ? 'source-over' : this.blendMode;
        ctx.drawImage(this.img(), this.x, this.y);
        ctx.restore();
    }

    // Encode the contents of this layer as a data URL.
    url()
    {
        return this.img().toDataURL('image/png');
    }

    // Encode the contents of this layer as an SVG shape.
    svg()
    {
        var tag = $(`<svg:image xlink:href='${this.url()}'>`);
        tag.attr({'x': this.x, 'y': this.y, 'width': this.w, 'height': this.h});
        if (this.blendMode != 'normal') tag.css('mix-blend-mode', this.blendMode);
        if (this.opacity != '1') tag.attr('opacity', this.opacity);
        if (this.hidden) tag.attr('visibility', 'hidden');
        return tag;
    }

    // Return a snapshot the state of this layer.
    state(as_image_data)
    {
        return {
            x: this.x, y: this.y, w: this.w, h: this.h, data: as_image_data
                ? this.img().getContext('2d').getImageData(0, 0, this.w, this.h)
                : this.url(),
            blendMode: this.blendMode, opacity: this.opacity, hidden: this.hidden
        };
    }
}
