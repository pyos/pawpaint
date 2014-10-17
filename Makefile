%.coffee:

js/%.js: js/%.coffee
	sed 's/^---$$//g' "$<" | coffee scripts/compile.coffee -- "$@"

%.html: %.hamlike
	python3 -m dg -m hamlike --trim < "$<" > "$@"

all: js/area.js js/dynamic.js js/index.js js/layer.js js/selector.js js/tools.js js/util.js index.html

watch: all
	bash scripts/watch.sh
