#!/usr/bin/env bash

IP_PROTO="udp"
IP_PORT="4864"
IP_ADDR="127.0.0.1"
LAUNCHER=$(basename $0 .sh)
STAMP=$(date +"%C%j-%H%M%S")
LOG_LEVEL="error"

if [ -e /snap/bin/ffmpeg ]; then
  FFMPEG="/snap/bin/ffmpeg"
else
  FFMPEG=$(which ffmpeg)
fi

# Use the appropriate container based on the protocol selected.
case ${IP_PROTO} in
  rtp)
    VID_CONTAINER="rtp"
    STREAM_OPTIONS=""
    ;;
  tcp)
    VID_CONTAINER="mpegts"
    STREAM_OPTIONS="?listen"
    ;;
  udp)
    VID_CONTAINER="mpegts"
    STREAM_OPTIONS="?fifo_size=10240"
    ;;
esac

TEST_NVENC=$(nvidia-smi -q | grep Encoder | wc -l)
TEST_CUDA=$(${FFMPEG} -hide_banner -hwaccels | grep cuda | sed -e 's/ //g')

if [ ${TEST_NVENC} -ge 1 ]  && [ "${TEST_CUDA}" == "cuda" ]; then
  VID_CODEC="h264_nvenc"
else
  VID_CODEC="libx264"
fi

# Use the appropriate preset based on the encoider selected.
case ${VID_CODEC} in
  "h264_nvenc") VID_PRESET="llhq";;
  "libx264") VID_PRESET="ultrafast";;
esac

# Framerate to stream and Group of Pictures (GOP)
VID_FPS="50"
VID_GOP=$((VID_FPS * 2))

# Disable capturing the mouse xcursor; change to 1 to capture mouse xcursor
VID_MOUSE=0

# Colour space
VID_COLORSPACE="yuv420p"

# Get the audio loopback device to record from; excludes Microphones.
# - https://unix.stackexchange.com/questions/488063/record-screen-and-internal-audio-with-ffmpeg
# - https://askubuntu.com/questions/516899/how-do-i-stream-computer-audio-only-with-ffmpeg
AUD_DEVICE=$(pacmd list-sources | grep -PB 1 "analog.*monitor>" | head -n 1 | cut -d':' -f2 | sed -e 's/ //g')

# Get the window we want to stream
# - https://unix.stackexchange.com/questions/14159/how-do-i-find-the-window-dimensions-and-position-accurately-including-decoration
TMP_XWININFO=$(mktemp -u)
echo -e "Please select the window about which you\nwould like information by clicking the\nmouse in that window."
xwininfo | tee ${TMP_XWININFO}
CAPTURE_X=$(sed -n -e "s/^ \+Absolute upper-left X: \+\([0-9]\+\).*/\1/p" ${TMP_XWININFO})
CAPTURE_Y=$(sed -n -e "s/^ \+Absolute upper-left Y: \+\([0-9]\+\).*/\1/p" ${TMP_XWININFO})
CAPTURE_WIDTH=$(sed -n -e "s/^ \+Width: \+\([0-9]\+\).*/\1/p" ${TMP_XWININFO})
[ $((CAPTURE_WIDTH%2)) -ne 0 ] && ((CAPTURE_WIDTH--))
CAPTURE_HEIGHT=$(sed -n -e "s/^ \+Height: \+\([0-9]\+\).*/\1/p" ${TMP_XWININFO})
[ $((CAPTURE_HEIGHT%2)) -ne 0 ] && ((CAPTURE_HEIGHT--))
rm -f ${TMP_XWININFO}
VID_CAPTURE="${DISPLAY}+${CAPTURE_X},${CAPTURE_Y}"
VID_SIZE="${CAPTURE_WIDTH}x${CAPTURE_HEIGHT}"

if [ "${LAUNCHER}" == "stream" ]; then
  # Stream the window and loopback audio as a low latency MPEG2-TS
  # - https://dennismungai.wordpress.com/2018/02/06/low-latency-live-streaming-for-your-desktop-using-ffmpeg-and-netcat/
  # - https://www.ostechnix.com/20-ffmpeg-commands-beginners/
  ${FFMPEG} -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
    -f pulse -thread_queue_size 64 -i ${AUD_DEVICE} \
    -f x11grab -draw_mouse ${VID_MOUSE} -video_size ${VID_SIZE} -framerate ${VID_FPS} -i ${VID_CAPTURE} \
    -c:a aac -b:a 128k -ac 2 -ar 44100 \
    -c:v ${VID_CODEC} -pix_fmt ${VID_COLORSPACE} -preset ${VID_PRESET} -g ${VID_GOP} -tune zerolatency -bsf:v h264_mp4toannexb -f ${VID_CONTAINER} ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}
elif [ "${LAUNCHER}" == "capture" ]; then
  # Capture the window and loopback audio as H.264/AAC in a Matroska container
  ${FFMPEG} -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
    -f pulse -i ${AUD_DEVICE} \
    -f x11grab -draw_mouse ${VID_MOUSE} -video_size ${VID_SIZE} -framerate ${VID_FPS} -i ${VID_CAPTURE} \
    -c:a aac -b:a 128k -ac 2 -ar 44100 \
    -c:v ${VID_CODEC} -pix_fmt ${VID_COLORSPACE} -preset ${VID_PRESET} "${LAUNCHER}-${STAMP}.mkv"
fi