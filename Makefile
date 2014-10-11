%.coffee:

%.js: js/%.coffee
	tail -n +3 "$<" | coffee scripts/compile.coffee 4> "js/$@" 5> "js/$@.map"

all: area.js dynamic.js index.js layer.js selector.js tools.js util.js

watch: all
	bash scripts/watch.sh js
