#!/usr/bin/env bash

RES_X=1280
RES_Y=720

# Get the window we want to resize
# - https://unix.stackexchange.com/questions/14159/how-do-i-find-the-window-dimensions-and-position-accurately-including-decoration
TMP_XWININFO=$(mktemp -u)
echo -e "Please select the window you\nwould like to resize & thumbnail by clicking the\nmouse in that window."
xwininfo | tee ${TMP_XWININFO} > /dev/null
WINDOW_ID=$(grep "Window id:" ${TMP_XWININFO} | head -n1 | cut -d':' -f3 | cut -d' ' -f2)
rm -f ${TMP_XWININFO}

echo "Resizing: ${WINDOW_ID} to ${RES_X}x${RES_Y}"
# Set the resolution
wmctrl -i -r ${WINDOW_ID} -e 0,0,0,${RES_X},${RES_Y}
# Raise the window
wmctrl -i -R ${WINDOW_ID}
# Take the screenshot
if [ -e $(which scrot) ]; then
  scrot --focused --quality 90 ${HOME}/thumbnail.jpg
elif [ -e $(which mate-screenshot) ]; then
  mate-screenshot --window --remove-border
else
  echo "WARNING! No supported screenshot tool found."
fi