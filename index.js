"use strict";


(() => {
    window.CTRL  = false;
    window.SHIFT = false;
    window.ALT   = false;
    window.META  = false;
    const area = window.area = new Area(document.getElementById('area'));

    area.on('key:27',   /* Esc */ () => $('.cover').click())
        .on('key:C-90',   /* Z */ () => area.undo())
        .on('key:C-89',   /* Y */ () => area.redo())
        .on('key:C-S-90', /* Z */ () => area.redo())
        .on('key:C-48',   /* 0 */ () => area.scale = 1)
        .on('key:C-187',  /* = */ () => area.scale *= 10/9)
        .on('key:C-189',  /* - */ () => area.scale *= 9/10)
        .on('key:78',     /* N */ () => area.createLayer(0))
        .on('key:88',     /* X */ () => area.deleteLayer(area.layer))
        .on('key:77',     /* M */ () => area.mergeDown(area.layer))
        .on('key:87',     /* W */ () => area.setToolOptions({ kind: area.tool.options.last }))
        .on('key:69',     /* E */ () => area.setToolOptions({ kind: EraserTool }))
        .on('key:C-83',   /* S */ () => {
            const link = document.createElement('a');
            link.download = 'image.png';
            link.href     = area.export('png');
            link.click();
        });

    $(document.body)
        .on('keydown keyup', (e) => {
            window.CTRL  = e.ctrlKey;
            window.SHIFT = e.shiftKey;
            window.ALT   = e.altKey;
            window.META  = e.metaKey;
        })

        .on('keydown', (e) => {
            const n = (e.ctrlKey  ? 'C-' : '')
                    + (e.shiftKey ? 'S-' : '')
                    + (e.altKey   ? 'A-' : '')
                    + (e.metaKey  ? 'M-' : '') + e.keyCode;
            if (area.trigger('key:' + n))
                e.preventDefault();
        })

      //.on('copy',     (e) => area.copy(e.originalEvent.clipboardData))
      //.on('cut',      (e) => area.copy(e.originalEvent.clipboardData))
        .on('paste',    (e) => { e.preventDefault(); area.paste(e.originalEvent.clipboardData); })
        .on('drop',     (e) => { e.preventDefault(); area.paste(e.originalEvent.dataTransfer);  })
        .on('dragover', (e) => { e.preventDefault() })

        .on('click', '.action-add-layer',  () => area.createLayer(0))
        .on('click', '.action-del-layer',  () => area.deleteLayer(area.layer))
        .on('click', '.action-merge-down', () => area.mergeDown(area.layer))
        .on('click', '.action-undo',       () => area.undo())
        .on('click', '.action-redo',       () => area.redo())
        .on('click', '.cover', (e) => {
            if (e.target === e.currentTarget)  // ignore clicks on children of .cover
                e.target.remove();
        })

        .on('click', '[data-selector]', function (ev) {
            const sel = this.getAttribute('data-selector');
            $(`.templates .selector-${sel}`)[`selector_${sel}`](area, this.offsetLeft, this.offsetTop, true).appendTo('body');
        })

        .on('contextmenu', '[data-selector-menu]', function (ev) {
            const sel = this.getAttribute('data-selector-menu');
            $(`.templates .selector-${sel}`)[`selector_${sel}`](area, ev.clientX, ev.clientY).appendTo('body');
            ev.preventDefault();
        });

    area.on('tool:H tool:S tool:L', (_, v) =>
            $('.action-tool').css('background', `hsl(${v.H}, ${v.S}%, ${v.L}%)`))
        .on('tool:L tool:kind', (_, v) =>
            $('.action-tool canvas').each(function () {
                const ctx = this.getContext('2d');
                const obj = new v.kind(null, { size: this.width * 0.75, L: v.L > 50 ? 0 : 100 });
                ctx.clearRect(0, 0, this.width, this.height);
                obj.symbol(ctx, this.width / 2, this.height / 2);
            }));

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
    xhr.onload = function ()
    {
        const data = new Uint8Array(this.response);

        for (let i = 0; i < data.length; ) {
            if (data.length < i + 4) return;
            let n = data[i++] << 8 | data[i++];
            let k = data[i++] << 8 | data[i++];

            if (data.length < i + n + k * 3) return;
            let name   = new TextDecoder('utf-8').decode(new DataView(data.buffer, i, n));
            let colors = new Array(k);

            for (i += n; k--; i += 3)
                colors[k] = { H:  data[i + 0] << 2 | data[i + 1] >> 6
                            , S: (data[i + 1] << 1 | data[i + 2] >> 7) & 0x7F
                            , L:  data[i + 2] & 0x7F };

            area.palettes.push({ name, colors });
        }
    };

    xhr.responseType = 'arraybuffer';
    xhr.open('GET', 'img/palettes.dat', true);
    xhr.send();

    $('.layer-menu').selector_layers(area, '.templates .selector-layer-config');

    if (localStorage.image) {
        area.import(localStorage.image, true);
        area.palette = parseInt(localStorage.palette);
        if (isNaN(area.palette)) area.palette = 0;
    }

    window.addEventListener('unload', () => {
        localStorage.image   = area.export('svg');
        localStorage.palette = area.palette;
    });

    if (!area.layers.length) {
        area.setSize($('#area-container').innerWidth(), $('#area-container').innerHeight());

        const layer = area.createLayer(0);
        const ctx = layer.img().getContext('2d');
        ctx.fillStyle = 'white';
        ctx.fillRect(0, 0, layer.w, layer.h);
        area.onLayerRedraw(layer);
    }
})();
