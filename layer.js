"use strict";


class Layer
{
    constructor(area)
    {
        this.area = area;
        this.img  = document.createElement('canvas');
        this.img.width  = 1;
        this.img.height = 1;
        this.img.classList.add('layer');
        this._x = this._y = 0;
    }

    get visible( ) { return this.img.style.display != 'none'; }
    set visible(v) {        this.img.style.display = v ? '' : 'none'; }

    get opacity( ) { return this.img.style.opacity || '1'; }
    set opacity(v) {        this.img.style.opacity = v; }

    get blendMode( ) { return this.img.style.mixBlendMode; }
    set blendMode(v) {        this.img.style.mixBlendMode = v; }

    get x( ) { return this._x; }
    get y( ) { return this._y; }
    get w( ) { return this.img.width;  }
    get h( ) { return this.img.height; }
    set x(x) { this.move(x, this._y); }
    set y(y) { this.move(this._x, y); }
    set w(w) { this.crop(this._x, this._y, w, this.h); }
    set h(h) { this.crop(this._x, this._y, this.w, h); }

    restyle(active, zIndex)
    {
        if (active)
            this.img.classList.add('active');
        else
            this.img.classList.remove('active');
        this.img.style.zIndex = zIndex;
        this.img.style.left   = this.x + 'em';
        this.img.style.top    = this.y + 'em';
        this.img.style.width  = this.w + 'em';
        this.img.style.height = this.h + 'em';
    }

    move(x, y)
    {
        this._x = x;
        this._y = y;
        this.area.onLayerRedraw(this);
    }

    crop(x, y, w, h)
    {
        const img = this.img.getContext('2d').getImageData(0, 0, this.w, this.h);
        this.img.width  = w;
        this.img.height = h;
        this.img.getContext('2d').putImageData(img, this._x - x, this._y - y);
        this.move(x, y);
    }

    resize(w, h)
    {
        const data = this.img.getContext('2d').getImageData(0, 0, this.w, this.h);
        const copy = document.createElement('canvas');
        copy.width  = this.w;
        copy.height = this.h;
        copy.getContext('2d').putImageData(data, 0, 0);

        this.img.width  = w;
        this.img.height = h;
        this.img.getContext('2d').drawImage(copy, 0, 0, w, h);
        this.area.onLayerRedraw(this);
    }

    get state()
    {
        return {
            x: this.x, y: this.y, w: this.w, h: this.h,
            data: this.img.getContext('2d').getImageData(0, 0, this.w, this.h),
            blendMode: this.blendMode, opacity: this.opacity, visible: this.visible
        };
    }

    set state(state)
    {
        this._x = state.x;
        this._y = state.y;

        if (state.blendMode !== undefined) this.blendMode = state.blendMode;
        if (state.opacity   !== undefined) this.opacity   = state.opacity;
        if (state.visible   !== undefined) this.visible   = state.visible;

        if (typeof state.data !== 'string') {
            this.img.width  = state.w;
            this.img.height = state.h;
            this.img.getContext('2d').putImageData(state.data, 0, 0);
            return this.area.onLayerRedraw(this);
        }

        const img = new Image();

        img.onload = () => {
            this.img.width  = img.width;
            this.img.height = img.height;
            this.img.getContext('2d').drawImage(img, 0, 0);
            this.area.onLayerRedraw(this);
        };

        img.src = state.data;
    }

    drawOnto(ctx)
    {
        if (!this.visible) return;
        ctx.save();
        ctx.globalAlpha = parseFloat(this.opacity);
        ctx.globalCompositeOperation = !this.blendMode ? 'source-over' : this.blendMode;
        ctx.drawImage(this.img, this.x, this.y);
        ctx.restore();
    }
}
