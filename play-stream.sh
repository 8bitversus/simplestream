#!/usr/bin/env bash

if [ -x /snap/bin/ffmpeg.ffplay ]; then
  PLAYER="/snap/bin/ffmpeg.ffplay"
elif [ -x /usr/bin/ffplay ]; then
  PLAYER="/usr/bin/ffplay"
else
  PLAYER="ffplay"
fi

LAUNCHER=$(basename $0 .sh)
STAMP=$(date +"%C%j-%H%M%S")
LOG_LEVEL="warning"

# Network settings
IP_PROTO="tcp"
IP_PORT="4864"
IP_ADDR="127.0.0.1"

function usage {
  echo
  echo "Usage"
  echo "  ${LAUNCHER} [--ip 192.168.0.1] [--player [ffplay|mpv] [--port 4864] [--protocol tcp|udp] [--help]"
  echo
  echo "You can also pass optional parameters"
  echo "  --ip       : Set the IP address to play from."
  echo "  --player   : Set the player. [ffplay|mpv]"
  echo "  --port     : Set the tcp/udp port to connect to."
  echo "  --protocol : Set the protocol to play over. [tcp|udp]"
  echo "  --help     : This help."
  echo
  exit 1
}

function cleanup_trap() {
  CLEANUP_PLAYER=$(killall ${PLAYER} 2>/dev/null)
  exit
}

# TODO - validate the inputs
# Check for optional parameters
while [ $# -gt 0 ]; do
  case "${1}" in
    -ip|--ip)
      IP_ADDR="$2"
      shift
      shift;;
    -player|--player)
      PLAYER="$2"
      shift
      shift;;
    -port|--port)
      IP_PORT="$2"
      shift
      shift;;
    -protocol|--protocol)
      IP_PROTO="$2"
      shift
      shift;;
    -h|--h|-help|--help)
      usage;;
    *)
      echo "ERROR! \"${1}\" is not a supported parameter."
      usage;;
  esac
done

TEST_PLAYER=$(which "${PLAYER}")
if [ $? -eq 1 ]; then
  echo "ERROR! Could not find ${PLAYER}. Quitting."
  exit 1
fi

if [ "${IP_PROTO}" != "tcp" ] && [ "${IP_PROTO}" != "udp" ]; then
  echo "ERROR! Unknown IP protocol: ${IP_PROTO}. Quitting."
  exit 1
fi

case ${IP_PROTO} in
  tcp) STREAM_OPTIONS="?listen";;
  udp) STREAM_OPTIONS="";;
esac

# Do we have nvdec capable hardware?
TEST_NVENC=$(nvidia-smi -q | grep Encoder | wc -l)
TEST_CUVID=$(${PLAYER} -hide_banner -decoders | grep h264_cuvid | wc -l)
if [ ${TEST_NVENC} -ge 1 ]  && [ ${TEST_CUVID} -ge 1 ]; then
  DECODER="h264_cuvid"
  THREADS=1
else
  DECODER="h264"
  THREADS=2
fi

# Call cleanup_trap() function on Ctrl+C 
trap "cleanup_trap" SIGINT SIGTERM

if [ "${LAUNCHER}" == "play-stream" ]; then
  # Run the player in an infinite loop so is it always listening. Exit with Ctrl+C.
  while true; do
    WIN_TITLE="${LAUNCHER} - ${PLAYER}"
    case ${PLAYER} in
      /snap/bin/ffmpeg.ffplay|/usr/bin/ffplay|ffplay)
        # Play a video stream with low latency
        # - https://stackoverflow.com/questions/16658873/how-to-minimize-the-delay-in-a-live-streaming-with-ffmpeg
        echo "Playing: ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
        ffplay -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
          -probesize 4M -fflags nobuffer+fastseek+flush_packets -flags low_delay -sync ext -framedrop -window_title "${WIN_TITLE}" -i "${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
        ;;
      mpv)
        mpv --no-cache --untimed --profile=low-latency --title="${WIN_TITLE}" "${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
        ;;
    esac
  done
elif [ "${LAUNCHER}" == "record-stream" ]; then
  echo "Recording: ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
  # Record a video stream in a Matroska container.
  ffmpeg -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
    -probesize 4M -fflags nobuffer+fastseek+flush_packets -flags low_delay -strict experimental -i ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS} -c:a copy -c:v copy "${LAUNCHER}-${STAMP}.mkv"
fi