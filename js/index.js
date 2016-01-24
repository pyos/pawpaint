$(function () {
    var area = window.area = new Area($('.main-area .layers')[0],
        [ RectSelectionTool
        , MoveTool
        , ColorpickerTool
        , EraserTool
        , PenTool
        , ImagePenTool.make(document.getElementById('r-round-16'))
        , ImagePenTool.make(document.getElementById('r-round-32'))
        , ImagePenTool.make(document.getElementById('r-round-64'))
        , ImagePenTool.make(document.getElementById('r-line'), 0)
        ]);

    var xhr = new XMLHttpRequest();
    xhr.open('GET', 'img/palettes.dat', true);
    xhr.responseType = 'arraybuffer';
    xhr.onload = function () { area.palettes = Canvas.palettes(new Uint8Array(this.response)) };
    xhr.send();

    $(window).on('unload', () => {
        localStorage.image   = area.export('svg');
        localStorage.palette = area.palette;
    });

    $('body').keymappable()
        .on('key:C-90',   (_, e) => { e.preventDefault(); area.undo(); }) // Ctrl+Z
        .on('key:C-89',   (_, e) => { e.preventDefault(); area.redo(); }) // Ctrl+Y
        .on('key:C-S-90', (_, e) => { e.preventDefault(); area.redo(); }) // Ctrl+Shift+Z
        .on('key:C-48',   (_, e) => { e.preventDefault(); area.setScale(1); })  // Ctrl+0
        .on('key:C-187',  (_, e) => { e.preventDefault(); area.setScale(area.scale * 1.1); })  // Ctrl+=
        .on('key:C-189',  (_, e) => { e.preventDefault(); area.setScale(area.scale * 0.9); })  // Ctrl+-
        .on('key:27',     (_, e) => { e.preventDefault(); $('.cover').click(); })  // Esc
        .on('key:C-83',   (_, e) => {  // Ctrl+S
            e.preventDefault();
            var link = document.createElement('a');
            link.download = 'image.png';
            link.href     = area.export('png');
            link.click();
        })

        .on('key:78' /* N */, () => area.createLayer(0))
        .on('key:88' /* X */, () => area.deleteLayer(area.layer))
        .on('key:77' /* M */, () => area.mergeDown(area.layer))
        .on('key:87' /* W */, () => area.setToolOptions({ kind: area.tool.options.last }))
        .on('key:69' /* E */, () => area.setToolOptions({ kind: EraserTool }))

      //.on('copy',     (e) => area.copy(e.originalEvent.clipboardData))
      //.on('cut',      (e) => area.copy(e.originalEvent.clipboardData))
        .on('paste',    (e) => { e.preventDefault(); area.paste(e.originalEvent.clipboardData); })
        .on('drop',     (e) => { e.preventDefault(); area.paste(e.originalEvent.dataTransfer);  })
        .on('dragover', (e) => { e.preventDefault() })

        .on('click', '.action-add-layer', () => area.createLayer(0))
        .on('click', '.action-del-layer', () => area.deleteLayer(area.layer))
        .on('click', '.action-undo',      () => area.undo())
        .on('click', '.action-redo',      () => area.redo())
        .on('click', '.cover', function (e) {
            // ???????
            if (e.target === e.currentTarget)
                $(this).fadeOut(100, $(this).remove.bind($(this)));
        })

        .on('click', '.tabbar li', function () {
            var attr = this.getAttribute('data-target');
            var self = $(this);
            self.addClass('active').siblings().removeClass('active');
            self.parent().parent().find('.tab').removeClass('active').filter(attr).addClass('active');
        })

        .on('click contextmenu', '[data-selector], [data-selector-menu]', function (ev) {
            var sel = $(this).attr(ev.which > 1 ? 'data-selector-menu' : 'data-selector');
            if (sel) {
                ev.preventDefault();
                $(`.templates .selector-${sel}`)[`selector_${sel}`](area,
                    ev.which > 1 ? ev.clientX : this.offsetLeft,
                    ev.which > 1 ? ev.clientY : this.offsetTop,
                    ev.which <= 1).appendTo('body');
            }
        });

    var main = $('.main-area');
    var tool = $('.action-tool');
    var menu = $('.layer-menu');
    menu.selector_layers(area, '.templates .selector-layer-config');

    area.on('tool:options', (v) => {
        tool.css('background', `hsl(${v.H}, ${v.S}%, ${v.L}%)`);
        tool.find('canvas').each(function () {
            var ctx = this.getContext('2d');
            ctx.clearRect(0, 0, this.width, this.height);
            var obj = new v.kind(null, { size: min(this.width, this.height) * 0.75, L: v.L > 50 ? 0 : 100 });
            obj.symbol(ctx, this.width / 2, this.height / 2);
        });
    });

    area.setToolOptions({kind: PenTool, last: PenTool});

    if (localStorage.image) {
        area.import(localStorage.image, true);
        area.palette = localStorage.palette;
    }

    if (!area.layers.length) {
        area.setSize(main.innerWidth(), main.innerHeight());
        area.createLayer(0).fill = 'white';
    }
});
