#!/usr/bin/env bash

# The purpose of this script is to launch VICE emualting a "breadbin"
# Commodore 64 in a predictable way for streaming. We're based in the UK so
# keen to emulate PAL refresh rates and timings to recreate (as best we can)
# the computers we owned and loved in the 1980s.

MODEL="c64"
SIGNAL="pal"
VOLUME="20"
BORDERS="3"

function usage {
  echo "HELP! There is no help here. Ask Wimpy!"
  exit 1
}

# Check for optional parameters
while [ $# -gt 0 ]; do
  case "${1}" in
    -borders|--borders)
      BORDERS="0"
      shift;;
    -signal|--signal)
      SIGNAL="$2"
      shift
      shift;;
    -volume|--volume)
      VOLUME="$2"
      shift
      shift;;
    -model|--model)
      MODEL="$2"
      shift
      shift;;
    -h|--h|-help|--help)
      usage;;
    *)
      break;;
  esac
done

if [ "${MODEL}" != "c64" ] && [ "${MODEL}" != "ntsc" ]; then
  echo "ERROR! Unknown machine type: ${MODEL}. Quitting."
  exit 1
elif [ "${MODEL}" == "ntsc" ]; then
  SIGNAL="ntsc"
fi

case ${SIGNAL} in
  PAL|pal)
    SIGNAL="pal"
    ;;
  NTSC|ntsc)
    SIGNAL="ntsc"
    ;;
  *)
    echo "ERROR! Unknown video signal: ${SIGNAL}. Quitting."
    exit 1
    ;;
esac

if [ "${BORDERS}" != "0" ] && [ "${BORDERS}" != "3" ]; then
  echo "ERROR! Unknown border type: ${BORDERS}. Quitting."
  exit 1
fi

x64 -default \
  +confirmonexit \
  -model "${MODEL}" \
  -${SIGNAL} \
  -joydev1 4 \
  -joydev2 5 \
  -keepaspect \
  -refresh 1 \
  -sound \
  -soundrate 44100 \
  -soundoutput 1 \
  -soundvolume "${VOLUME}" \
  +trueaspect \
  -virtualdev \
  -VICIIborders "${BORDERS}" \
  -VICIIdsize \
  -VICIIdscan \
  -VICIIhwscale \
  -VICIIfilter 0 \
  -VICIIintpal \
  -VICIIbrightness 1100 \
  -VICIIcontrast 1400 \
  -VICIIsaturation 1600 \
  -VICIItint 1100 \
  -VICIIgamma 3600 \
  -VICIIcrtblur 0 \
  -VICIIcrtscanlineshade 550 \
  -VICIIoddlinesphase 1000 \
  -VICIIoddlinesoffset 1200 \
  "$@"