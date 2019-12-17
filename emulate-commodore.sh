#!/usr/bin/env bash

# The purpose of this script is to launch VICE emualting a "breadbin"
# Commodore 64 in a predictable way for streaming. We're based in the UK so
# keen to emulate PAL refresh rates and timings to recreate (as best we can)
# the computers we owned and loved in the 1980s.

x64 -default \
  -model c64 \
  -pal \
  -joydev1 4 \
  -joydev2 5 \
  -VICIIdsize \
  -VICIIdscan \
  -VICIIhwscale \
  -VICIIfilter 1 \
  -VICIIintpal \
  -VICIIsaturation 1600 \
  -VICIIcontrast 1400 \
  -VICIIbrightness 1100 \
  -VICIIgamma 3600 \
  -VICIItint 1100 \
  -VICIIcrtblur 0 \
  -VICIIcrtscanlineshade 650 \
  -VICIIoddlinesphase 1000 \
  -VICIIoddlinesoffset 1100 \
  -soundvolume 70 \
  "$@"