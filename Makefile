%.js: %.coffee
	sed 's/^---$$//g' "$<" | coffee scripts/compile.coffee -- "$@"

%.css: %.sass
	(sed 's/^---$$//g' "$<" > _tmp.sass && sass --style compressed _tmp.sass "$@"); rm _tmp.sass

%.html: %.hamlike
	python3 -m dg -m hamlike --trim < "$<" > "$@"

all: js/selector.js js/tools.js css/index.css index.html

watch: all
	bash scripts/watch.sh
