'use strict';

for (let T of [window.NodeList, window.HTMLCollection, window.TouchList])
    if (T !== undefined)
        T.prototype[Symbol.iterator] = Array.prototype[Symbol.iterator];


function $preventDefault(ev) {
    ev.preventDefault();
}


Node.prototype.$nearestParent = function (selector) {
    let n = this;
    while (n && !n.matches(selector))
        n = n.parentElement;
    return n;
};


Node.prototype.$insertAt = function (e, i) {
    if (i >= this.children.length)
        this.appendChild(e);
    else
        this.insertBefore(e, this.children[i]);
};


EventTarget.prototype.$defaultEventListener = function (ev, f) {
    this.addEventListener(ev, $preventDefault);
    this.addEventListener(ev, f);
};


HTMLCanvasElement.prototype.$getResolution = function () {
    const dpr = window.devicePixelRatio || 1;
    const ctx = this.getContext('2d');
    const bsr = ctx.webkitBackingStorePixelRatio || ctx.mozBackingStorePixelRatio ||
                ctx.msBackingStorePixelRatio     || ctx.oBackingStorePixelRatio   ||
                ctx.backingStorePixelRatio       || 1;
    return dpr / bsr;
};


HTMLCanvasElement.prototype.$forceNativeResolution = function () {
    const scale = this.$getResolution();
    if (scale != 1) {
        this.style.width  = this.width + 'px';
        this.style.height = this.height + 'px';
        this.width  *= scale;
        this.height *= scale;
        this.getContext('2d').scale(scale, scale);
    }
};
