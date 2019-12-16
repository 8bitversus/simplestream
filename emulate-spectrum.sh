#!/usr/bin/env bash

fuse-gtk --graphics-filter paltv2x \
         --joystick-1-output 2 \
         --joystick-2-output 2 \
         --kempston \
         --machine 48 \
         --pal-tv2x \
         --sound \
         --volume-beeper 10 \
         "$@"