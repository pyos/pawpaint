#!/usr/bin/bash
inotifywait -e close_write -e delete -e move --format "%e %f" -mq "$1" | while read event; do
	if [ "${event##*.}" = "coffee" ]; then
    EVENT="${event%% *}"
    FNAME="${event#* }"

    case "$EVENT" in
      DELETE|MOVED_FROM)          echo "D $FNAME"; rm "$1/${FNAME%.*}.js"{,.map};;
      CLOSE_WRITE,CLOSE|MOVED_TO) echo "M $FNAME"; make "${FNAME%.*}.js" >/dev/null;;
    esac
  fi
done