%.coffee:

%.js: js/%.coffee
	tail -n +4 "$<" | coffee Makefile.coffee 4> "js/$@" 5> "js/$@.map"

all: area.js dynamic.js index.js layer.js selector.js tools.js util.js
