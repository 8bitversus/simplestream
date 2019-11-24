#!/usr/bin/env bash

PLAYER="ffplay"
IP_PROTO="tcp"
IP_PORT="4864"
IP_ADDR="127.0.0.1"
LAUNCHER=$(basename $0 .sh)
STAMP=$(date +"%C%j-%H%M%S")
LOG_LEVEL="warning"
WIN_TITLE="${LAUNCHER} - ${PLAYER}"

case ${IP_PROTO} in
  rtp)
    STREAM_OPTIONS=""
    ;;
  tcp)
    STREAM_OPTIONS="?listen"
    ;;
  udp)
    # Add "?fifo_size=10240" if you are experiencing packet loss or video corruption. This will add latency.
    STREAM_OPTIONS=""
    ;;
esac

function usage {
  echo
  echo "Usage"
  echo "  ${LAUNCHER} [--ip 192.168.0.1] [--help]"
  echo
  echo "You can also pass optional parameters"
  echo "  --ip     : Set the IP address to play from."
  echo "  --help   : This help."
  echo
  exit 1
}

# Check for optional parameters
while [ $# -gt 0 ]; do
  case "${1}" in
    -i|--i|-ip|--ip)
      IP_ADDR="$2"
      shift
      shift;;
    -h|--h|-help|--help|-?)
      usage;;
    *)
      echo "ERROR! \"${1}\" is not s supported parameter."
      usage;;
  esac
done

if [ "${LAUNCHER}" == "play-stream" ]; then
  case ${PLAYER} in
    ffplay)
      # Play a video stream with low latency
      # - https://stackoverflow.com/questions/16658873/how-to-minimize-the-delay-in-a-live-streaming-with-ffmpeg
      echo "Playing: ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
      ffplay -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
        -fflags nobuffer+fastseek+flush_packets -flags low_delay -sync ext -framedrop -window_title "${WIN_TITLE}" -i "${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
      ;;  
    mpv)
      mpv --no-cache --untimed --profile=low-latency --title="${WIN_TITLE}" "${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
      ;;
  esac
elif [ "${LAUNCHER}" == "record-stream" ]; then
  echo "Recording: ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
  # Record a video stream in a Matroska container.
  ffmpeg -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
    -fflags nobuffer+fastseek+flush_packets -flags low_delay -strict experimental -i ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS} -c:a copy -c:v copy "${LAUNCHER}-${STAMP}.mkv"
fi