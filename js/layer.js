"use strict";


class Layer
{
    constructor(area)
    {
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
        const opt = this.area.tool.options;
        const ctx = this.img().getContext('2d');
        ctx.fillStyle = v == 'toolColor' ? `hsl(${opt.H},${opt.S}%,${opt.L}%)` : v;
        ctx.fillRect(0, 0, this.w, this.h);
        this.area.onLayerRedraw(this);
    }

    // Remove the contents of this layer. (And the element that represents it.)
    clear()
    {
        this.element.remove();
        this.element = $([]);
        this.area.onLayerRedraw(this);
    }

    // Change the position of this layer relative to the image.
    move(x, y)
    {
        this.x = x;
        this.y = y;
        this.area.onLayerResize(this);
    }

    // Change the size of this layer without modifying its contents.
    // The offset is relative to the image.
    crop(x, y, w, h)
    {
        const dx = this.x - x;
        const dy = this.y - y;
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
        this.move(this.x, this.y);
        this.replace(this.element, 0, 0, true);
    }

    // Recreate the element that represents this layer from a set of canvases/images.
    // Optionally, rescale them to fit the new size.
    replace(imgs, x, y, rescale)
    {
        const tag = $(`<canvas width="${this.w}" height="${this.h}">`).addClass('layer');
        const ctx = tag[0].getContext('2d');

        for (let i = 0; i < imgs.length; i++)
            if (rescale)
                ctx.drawImage(imgs[i], x, y, this.w, this.h);
            else
                ctx.drawImage(imgs[i], x, y);

        this.element.remove();
        this.element = tag.appendTo(this.area.element);
        this.area.onLayerRedraw(this);
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

        const img = new Image();
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
            this.area.onLayerRedraw(this);
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
        const tag = $(`<svg:image xlink:href='${this.url()}'>`);
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
