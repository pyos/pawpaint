"use strict";
window.$id   = document.getElementById.bind(document);
window.min   = Math.min;
window.max   = Math.max;
window.sin   = Math.sin;
window.cos   = Math.cos;
window.atan2 = Math.atan2;
window.abs   = Math.abs;
window.pow   = Math.pow;
window.exp   = Math.exp;
window.sqrt  = Math.sqrt;
window.round = Math.round;
window.ceil  = Math.ceil;
window.floor = Math.floor;
window.PI    = Math.PI;

window.CTRL  = false;
window.SHIFT = false;
window.ALT   = false;
window.META  = false;


// A shortcut for creating <canvas> elements.
window.Canvas = function (w, h) { return $(`<canvas width='${w}' height='${h}'>`); };


class EventSystem
{
    constructor()
    {
        this._events = {};
    }

    on(name, fn)
    {
        for (var n of name.split(' ')) {
            this._events[n] = this._events[n] || [];
            this._events[n].push(fn);
        }

        return this;
    }

    trigger(name, ...args)
    {
        for (var fn of this._events[name] || [])
            fn.apply(this, args);
        return this;
    }
}


window.evdev = {
    // When using tablets, evdev may bug and send the cursor jumping when doing
    // fine movements. To prevent this, we're going to ignore extremely fast
    // mouse movement events.
    lastX: 0,
    lastY: 0,

    // Mark a start point given a mouse event.
    reset: (ev) => {
        this.lastX = ev.pageX;
        this.lastY = ev.pageY;
        return true;
    },

    // Check that a mouse event is not bugged.
    ok: (ev) => {
        if (abs(ev.pageX - this.lastX) + abs(ev.pageY - this.lastY) < 200) {
            this.lastX = ev.pageX;
            this.lastY = ev.pageY;
            return true;
        }

        return false;
    }
};


// Listen for key events and emit events such as `key:ctrl+shift+127`.
// Mostly useless since browsers hog key combos for themselves.
$.fn.keymappable = function () {
    return this
        .on('keydown', (ev) => {
            var n = (ev.ctrlKey  ? 'ctrl+'  : '')
                  + (ev.shiftKey ? 'shift+' : '')
                  + (ev.altKey   ? 'alt+'   : '')
                  + (ev.metaKey  ? 'meta+'  : '');
            return $(this).trigger(`key:${n}${ev.keyCode}`, [ev]);
        })

        .on('keydown keyup', (ev) => {
            window.CTRL  = ev.ctrlKey;
            window.SHIFT = ev.shiftKey;
            window.ALT   = ev.altKey;
            window.META  = ev.metaKey;
            return true;
        });

};
