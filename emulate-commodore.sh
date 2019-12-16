#!/usr/bin/env bash

x64 -default \
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
  "$@"
