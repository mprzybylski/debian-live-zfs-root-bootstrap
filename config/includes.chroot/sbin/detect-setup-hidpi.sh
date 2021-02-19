#!/bin/bash

widest_mode="$(awk 'BEGIN{widest_mode=0}
    match($0, /^U:([0-9]+)-[0-9]+p-0$/, a){if(a[1] > widest_mode){widest_mode=a[1]}}
    END{print widest_mode}' < /sys/class/graphics/fb0/modes)"

# shellcheck disable=SC2086
if [ $widest_mode -gt 1600 ]; then
  # Use a bigger font on the console
  setfont Uni3-Terminus32x16
fi
exit 0
