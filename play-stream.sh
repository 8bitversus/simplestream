#!/usr/bin/env bash

IP_PORT="23000"
IP_ADDR="127.0.0.1"
LAUNCHER=$(basename $0 .sh)
STAMP=$(date +"%C%j-%H%M%S")
LOG_LEVEL="panic"

if [ "${LAUNCHER}" == "play-stream" ]; then
  # Play a video stream over udp with low latency
  # - https://stackoverflow.com/questions/16658873/how-to-minimize-the-delay-in-a-live-streaming-with-ffmpeg
  ffplay -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
    -fflags nobuffer -flags low_delay -strict experimental -probesize 32 -sync ext -framedrop -window_title "${LAUNCHER}" -i udp://${IP_ADDR}:${IP_PORT}
elif [ "${LAUNCHER}" == "record-stream" ]; then
  # Record a udp video stream in a Matroska container.
  ffmpeg -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
    -fflags nobuffer -flags low_delay -strict experimental -i udp://${IP_ADDR}:${IP_PORT} -c:a copy -c:v copy "${LAUNCHER}-${STAMP}.mkv"
fi