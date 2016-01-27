"use strict";


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
            link.href     = area.export('png');
            link.click();
        })
        .on('key:C-17', () => {
            if (beforeCtrl === null) {
                beforeCtrl = area.tool.options.kind;
                area.setToolOptions({ kind: ColorpickerTool });
            }
        })
        .on('key:17', () => {
            if (beforeCtrl !== null) {
                area.setToolOptions({ kind: beforeCtrl });
                beforeCtrl = null;
            }
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
            $(this.getAttribute('data-control-click')).clone().control(area, 0, 0, this);
            e.preventDefault();
        })

        .on('contextmenu', '[data-control-menu]', function (e) {
            $(this.getAttribute('data-control-menu')).clone().control(area, e.clientX, e.clientY);
            e.preventDefault();
        });

    area.setToolOptions({kind: PenTool, last: PenTool});
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

    $('[data-control]:not(.templates [data-control])').control(area);

    if (localStorage.image) {
        area.import(localStorage.image, true);
        area.palette = parseInt(localStorage.palette);
        if (isNaN(area.palette)) area.palette = 0;
    }

    if (!area.layers.length) {
        area.setSize($('#area-container').innerWidth(), $('#area-container').innerHeight());

        const layer = area.createLayer(area.layer);
        const ctx = layer.img.getContext('2d');
        ctx.fillStyle = 'white';
        ctx.fillRect(0, 0, layer.w, layer.h);
        area.onLayerRedraw(layer);
    }

    window.addEventListener('unload', () => {
        localStorage.image   = area.export('svg');
        localStorage.palette = area.palette;
    });
})();
