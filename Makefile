%.coffee:

%.js: js/%.coffee
	sed 's/^---$$//g' "$<" | coffee scripts/compile.coffee -- js "$@"

all: area.js dynamic.js index.js layer.js selector.js tools.js util.js

watch: all
	bash scripts/watch.sh js
