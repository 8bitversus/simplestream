#!/usr/bin/env bash

IP_PROTO="udp"
IP_PORT="4864"
IP_ADDR="127.0.0.1"
LAUNCHER=$(basename $0 .sh)
STAMP=$(date +"%C%j-%H%M%S")
LOG_LEVEL="warning"

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
  # Play a video stream with low latency
  # - https://stackoverflow.com/questions/16658873/how-to-minimize-the-delay-in-a-live-streaming-with-ffmpeg
  TEST_MPV=$(which mpv)
  if [ $? -eq 0 ]; then
    # TODO: Eval if these are also required: `--no-cache --untimed`
    mpv --profile=low-latency --title="${LAUNCHER} - mpv" "${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
  else
    ffplay -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
      -fflags nobuffer+fastseek+flush_packets -flags low_delay -strict experimental -sync ext -framedrop -window_title "${LAUNCHER} - ffplay" -i "${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
  fi
elif [ "${LAUNCHER}" == "record-stream" ]; then
  # Record a video stream in a Matroska container.
  ffmpeg -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
    -fflags nobuffer+fastseek+flush_packets -flags low_delay -strict experimental -i ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS} -c:a copy -c:v copy "${LAUNCHER}-${STAMP}.mkv"
fi