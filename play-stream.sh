#!/usr/bin/env bash

IP_PROTO="tcp"
IP_PORT="4864"
IP_ADDR="127.0.0.1"
LAUNCHER=$(basename $0 .sh)
STAMP=$(date +"%C%j-%H%M%S")
LOG_LEVEL="warning"
PLAYER="ffplay"

case ${IP_PROTO} in
  rtp)
    STREAM_OPTIONS=""
    ;;
  tcp)
    STREAM_OPTIONS="?listen"
    ;;
  udp)
    STREAM_OPTIONS="?fifo_size=10240"
    ;;
esac

if [ "${LAUNCHER}" == "play-stream" ]; then
  case ${PLAYER} in
    ffplay)
      # Play a video stream with low latency
      # - https://stackoverflow.com/questions/16658873/how-to-minimize-the-delay-in-a-live-streaming-with-ffmpeg
      echo "Playing: ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
      ffplay -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
        -fflags nobuffer+fastseek+flush_packets -flags low_delay -sync ext -framedrop -window_title "${LAUNCHER} - ffplay" -i "${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
      ;;  
    mpv)
      mpv --no-cache --untimed --profile=low-latency --title="${LAUNCHER} - mpv" "${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
      ;;
  esac
elif [ "${LAUNCHER}" == "record-stream" ]; then
  echo "Recording: ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
  # Record a video stream in a Matroska container.
  ffmpeg -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
    -fflags nobuffer+fastseek+flush_packets -flags low_delay -strict experimental -i ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS} -c:a copy -c:v copy "${LAUNCHER}-${STAMP}.mkv"
fi