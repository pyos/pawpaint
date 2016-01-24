%.css: %.sass
	(sed 's/^---$$//g' "$<" > _tmp.sass && sass --style compressed _tmp.sass "$@"); rm _tmp.sass

%.html: %.hamlike
	python3 -m dg -m hamlike --trim < "$<" > "$@"

all: css/index.css index.html

watch: all
	bash scripts/watch.sh
