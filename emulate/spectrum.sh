#!/usr/bin/env bash

# The purpose of this script is to launch FUSE emualting a ZX Spectrum 48k
# in a predictable way for streaming. We're based in the UK so keen to
# emulate PAL refresh rates and timings to recreate (as best we can) the 
# computers we owned and loved in the 1980s.

if [ -x /usr/bin/fuse-gtk ]; then
  FUSE="/usr/bin/fuse-gtk"
elif [ -x /usr/bin/fuse-sdl ]; then
  FUSE="/usr/bin/fuse-sdl"
else
  FUSE=""
fi

MACHINE="48"
BEEPER="20"
VOLUME="30"

function usage {
  echo "HELP! There is no help here. Ask Wimpy!"
  exit 1
}

# Check for optional parameters
while [ $# -gt 0 ]; do
  case "${1}" in
    -128|--128)
      MACHINE="128"
      shift;;
    -48|--48)
      MACHINE="48"
      shift;;
    -beeper|--beeper)
      BEEPER="$2"
      shift
      shift;;
    -machine|--machine)
      MACHINE="$2"
      shift
      shift;;
    -volume|--volume)
      VOLUME="$2"
      shift
      shift;;
    -h|--h|-help|--help)
      usage;;
    *)
      break;;
  esac
done

if [ ! -e "${FUSE}" ]; then
  echo "ERROR! Could not find FUSE. Quitting."
  exit 1
fi

if [ "${MACHINE}" != "48" ] && [ "${MACHINE}" != "128" ]; then
  echo "ERROR! Unknown machine type: ${MACHINE}. Quitting."
  exit 1
fi

${FUSE} --graphics-filter 2x \
         --joystick-1-output 2 \
         --joystick-2-output 2 \
         --kempston \
         --machine "${MACHINE}" \
         --sound \
         --volume-ay "${VOLUME}" \
         --volume-beeper "${BEEPER}" \
         "$@"