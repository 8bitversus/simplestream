#!/usr/bin/env bash

# The purpose of this script is to launch FUSE emualting a ZX Spectrum 48k
# in a predictable way for streaming. We're based in the UK so keen to
# emulate PAL refresh rates and timings to recreate (as best we can) the 
# computers we owned and loved in the 1980s.

fuse-gtk --graphics-filter paltv2x \
         --joystick-1-output 2 \
         --joystick-2-output 2 \
         --kempston \
         --machine 128 \
         --pal-tv2x \
         --sound \
         --volume-beeper 20 \
         "$@"
