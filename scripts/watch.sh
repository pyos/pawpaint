#!/usr/bin/bash
inotifywait -e close_write -e delete -e move --format "%e %w%f" -mqr . | while read event; do
  EVENT="${event%% *}"
  FNAME="${event#* }"
  FNAME="${FNAME#*/}"

	case "${FNAME##*.}" in
		coffee)  TARGET="${FNAME%.*}.js";;
		hamlike) TARGET="${FNAME%.*}.html";;
		sass)    TARGET="${FNAME%.*}.css";;
		*) continue;;
	esac

  case "$EVENT" in
    DELETE|MOVED_FROM)          echo "D $FNAME"; rm   "$TARGET"{,.map};;
    CLOSE_WRITE,CLOSE|MOVED_TO) echo "M $FNAME"; make "$TARGET" >/dev/null;;
  esac
done