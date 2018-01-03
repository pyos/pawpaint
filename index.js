"use strict"; /* global $, Area */


(() => {
    window.CTRL  = false;
    window.SHIFT = false;
    window.ALT   = false;
    window.META  = false;
    const area = window.area = new Area(document.getElementById('area'));

    let beforeCtrl = null;

    area.on('key:27',   /* Esc */ () => $('.cover').click())
        .on('key:C-90',   /* Z */ () => area.undo())
        .on('key:C-89',   /* Y */ () => area.redo())
        .on('key:C-S-90', /* Z */ () => area.redo())
        .on('key:C-48',   /* 0 */ () => area.scale = 1)
        .on('key:C-187',  /* = */ () => area.scale *= 10/9)
        .on('key:C-189',  /* - */ () => area.scale *= 9/10)
        .on('key:78',     /* N */ () => area.createLayer(area.layer))
        .on('key:88',     /* X */ () => area.deleteLayer(area.layer))
        .on('key:77',     /* M */ () => area.mergeDown(area.layer))
        .on('key:87',     /* W */ () => area.setToolOptions({ kind: area.tool.options.last }))
        .on('key:69',     /* E */ () => area.setToolOptions({ kind: EraserTool }))
        .on('key:C-83',   /* S */ () => {
            const link = document.createElement('a');
            link.download = 'image.png';
            link.href     = area.save('png');
            link.click();
        });

    $(document.body)
        .on('keydown keyup', (e) => {
            window.CTRL  = e.ctrlKey;
            window.SHIFT = e.shiftKey;
            window.ALT   = e.altKey;
            window.META  = e.metaKey;

            if (e.target.tagName !== 'INPUT')
                if (e.type === 'keyup' && /* Shift/Ctrl/Alt */ 16 <= e.keyCode && e.keyCode <= 18)
                    if (area.trigger('key:' + e.keyCode))
                        e.preventDefault();
        })

        .on('keydown', (e) => {
            const n = (e.ctrlKey  ? 'C-' : '')
                    + (e.shiftKey ? 'S-' : '')
                    + (e.altKey   ? 'A-' : '')
                    + (e.metaKey  ? 'M-' : '') + e.keyCode;

            console.log('key event: ' + n);
            if (e.target.tagName !== 'INPUT' && area.trigger('key:' + n))
                e.preventDefault();
        })

      //.on('copy',     (e) => area.copy(e.originalEvent.clipboardData))
      //.on('cut',      (e) => area.copy(e.originalEvent.clipboardData))
        .on('paste',    (e) => { e.preventDefault(); area.paste(e.originalEvent.clipboardData); })
        .on('drop',     (e) => { e.preventDefault(); area.paste(e.originalEvent.dataTransfer);  })
        .on('dragover', (e) => { e.preventDefault() })

        .on('click', '.action-create-layer', () => area.createLayer(area.layer))
        .on('click', '.action-remove-layer', () => area.deleteLayer(area.layer))
        .on('click', '.action-merge-down',   () => area.mergeDown(area.layer))
        .on('click', '.action-undo',         () => area.undo())
        .on('click', '.action-redo',         () => area.redo())
        .on('click', '.cover', (e) => {
            if (e.target === e.currentTarget)  // ignore clicks on children of .cover
                e.target.remove();
        })

        .on('contextmenu', '.cover', function (e) {
            e.currentTarget.remove();
            e.preventDefault();
        })

        .on('click', '[data-control-click]', function (e) {
            e.preventDefault();
            let c = document.querySelector(this.getAttribute('data-control-click')).cloneNode(true);
            new Control(c, area, 0, 0, this);
        })

        .on('contextmenu', '[data-control-menu]', function (e) {
            e.preventDefault();
            let c = document.querySelector(this.getAttribute('data-control-menu')).cloneNode(true);
            new Control(c, area, e.clientX, e.clientY);
        });

    area.setToolOptions({kind: PenTool, last: PenTool});
    area.palette = 0;
    area.palettes = [];
    area.tools = [ RectSelectionTool
                 , MoveTool
                 , ColorpickerTool
                 , EraserTool
                 , PenTool
                 , ImagePenTool.make(document.getElementById('r-round-16'))
                 , ImagePenTool.make(document.getElementById('r-round-32'))
                 , ImagePenTool.make(document.getElementById('r-round-64'))
                 , ImagePenTool.make(document.getElementById('r-line'), 0)
                 ];

    let xhr = new XMLHttpRequest();
    xhr.onload = function () { area.palettes = JSON.parse(this.responseText); };
    xhr.open('GET', 'img/palettes.json', true);
    xhr.send();

    for (let c of document.querySelectorAll('[data-control]'))
        if (!c.$nearestParent('.templates'))
            new Control(c, area);

    let _storedToolOptions = () => {
        try {
            return JSON.parse(localStorage.toolOpts);
        } catch (err) {
            return {};
        }
    };

    if (localStorage.image) {
        area.load(localStorage.image, true);
        area.palette = +localStorage.palette;
        if (isNaN(area.palette)) area.palette = 0;

        if (!isNaN(+localStorage.tool) && +localStorage.tool < area.tools.length) {
            let opts = _storedToolOptions();
            opts.kind = area.tools[+localStorage.tool];
            area.setToolOptions(opts);
        }
    }

    if (!area.layers.length) {
        area.w = $('#area-container').innerWidth();
        area.h = $('#area-container').innerHeight();
        const layer = area.createLayer(area.layer);
        const ctx = layer.img.getContext('2d');
        ctx.fillStyle = 'white';
        ctx.fillRect(0, 0, layer.w, layer.h);
        area.onLayerRedraw(layer);
    }

    window.addEventListener('unload', () => {
        let opts = area.tool.options;
        localStorage.image    = area.save('svg');
        localStorage.palette  = area.palette;
        localStorage.tool     = area.tools.indexOf(beforeCtrl || area.tool.options.kind);
        localStorage.toolOpts = JSON.stringify({
            'H': opts.H, 'S': opts.S, 'L': opts.L, 'size': opts.size,
            'opacity': opts.opacity, 'rotation': opts.rotation, 'spacing': opts.spacing
        });
    });
})();
