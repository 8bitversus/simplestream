#!/usr/bin/env bash

# Reference
# xwininfo for a popped out Twitch.tv chat window that is the correct
# size for integrating into the 8-bit Versus OBS scenes.

#xwininfo: Window id: 0x6000031 "Creator Dashboard - Google Chrome"

#  Absolute upper-left X:  2221
#  Absolute upper-left Y:  1003
#  Relative upper-left X:  11
#  Relative upper-left Y:  41
#  Width: 338
#  Height: 436
#  Depth: 24
#  Visual: 0x21
#  Visual Class: TrueColor
#  Border width: 0
#  Class: InputOutput
#  Colormap: 0x20 (installed)
#  Bit Gravity State: NorthWestGravity
#  Window Gravity State: NorthWestGravity
#  Backing Store State: NotUseful
#  Save Under State: no
#  Map State: IsViewable
#  Override Redirect State: no
#  Corners:  +2221+1003  -2561+1003  -2561-1081  +2221-1081
#  -geometry 338x436+2210+962

# Get the window we want to resize
# - https://unix.stackexchange.com/questions/14159/how-do-i-find-the-window-dimensions-and-position-accurately-including-decoration
TMP_XWININFO=$(mktemp -u)
echo -e "Please select the window you\nwould like to resize by clicking the\nmouse in that window."
xwininfo | tee ${TMP_XWININFO} > /dev/null
WINDOW_ID=$(grep "Window id:" ${TMP_XWININFO} | head -n1 | cut -d':' -f3 | cut -d' ' -f2)
rm -f ${TMP_XWININFO}

echo "Resizing: ${WINDOW_ID}"
# Set the resolution
wmctrl -i -r ${WINDOW_ID} -e 0,0,0,1920,1080
# Change the window title to something predicatable
#wmctrl -i -r ${WINDOW_ID} -N "Twitch.tv Chat"
# Raise the window
wmctrl -i -R ${WINDOW_ID}
