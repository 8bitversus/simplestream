#!/usr/bin/env bash

FFMPEG="/snap/bin/ffmpeg"
IP_PROTO="tcp"
IP_PORT="4864"
IP_ADDR="127.0.0.1"
LAUNCHER=$(basename $0 .sh)
STAMP=$(date +"%C%j-%H%M%S")
LOG_LEVEL="warning"

# Framerate to stream and Group of Pictures (GOP)
VID_FPS="30"
VID_GOP=$((VID_FPS * 2))
# Select the video codec; change to "libx264" for software encoding.
VID_CODEC="h264_nvenc"
VID_BITRATE="640k"
VID_BUFSIZE=$((VID_BITRATE / VID_FPS))
VID_COLORSPACE="yuv420p"
VID_BT709="-vf scale=out_color_matrix=bt709 -color_primaries bt709 -color_trc bt709 -colorspace bt709"
# Disable capturing the mouse xcursor; change to 1 to capture mouse xcursor
VID_MOUSE=0
# Disable vsync in the encoder/streamer; change to 1 to enable vsync
VID_VSYNC=0

# Audio encoding settings
AUD_SAMPLERATE=22050
AUD_BITRATE=96k

if [ ! -e "${FFMPEG}" ]; then
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
    STREAM_OPTIONS=""
    ;;
  udp)
    VID_CONTAINER="mpegts"
    # Add "?fifo_size=10240" if you are experiencing packet loss or video corruption. This will add latency.
    STREAM_OPTIONS=""
    ;;
esac

TEST_NVENC=$(nvidia-smi -q | grep Encoder | wc -l)
TEST_CUDA=$(${FFMPEG} -hide_banner -hwaccels | grep cuda | sed -e 's/ //g')

# TODO: Tune the encoders
# - https://devblogs.nvidia.com/turing-h264-video-encoding-speed-and-quality/
# - https://superuser.com/questions/1296374/best-settings-for-ffmpeg-with-nvenc
if [ ${TEST_NVENC} -ge 1 ]  && [ "${TEST_CUDA}" == "cuda" ]  &&  [ "${VID_CODEC}" == "h264_nvenc" ]; then
  VID_PRESET="llhp"
  VID_CODEC_TUNING="-rc cbr_ld_hq -b:v ${VID_BITRATE} -g ${VID_GOP} -vsync ${VID_VSYNC}"
else
  VID_CODEC="libx264"
  VID_PRESET="ultrafast"
  VID_CODEC_TUNING="-x264opts no-sliced-threads -tune zerolatency -bsf:v h264_mp4toannexb -b:v ${VID_BITRATE} -g ${VID_GOP} -vsync ${VID_VSYNC}"
fi

# Get the audio loopback device to record from; excludes Microphones.
# - https://unix.stackexchange.com/questions/488063/record-screen-and-internal-audio-with-ffmpeg
# - https://askubuntu.com/questions/516899/how-do-i-stream-computer-audio-only-with-ffmpeg
AUD_DEVICE=$(pacmd list-sources | grep -PB 1 "analog.*monitor>" | head -n 1 | cut -d':' -f2 | sed -e 's/ //g')

# Get the window we want to stream
# - https://unix.stackexchange.com/questions/14159/how-do-i-find-the-window-dimensions-and-position-accurately-including-decoration
TMP_XWININFO=$(mktemp -u)
echo -e "Please select the window you\nwould like to stream/capture by clicking the\nmouse in that window."
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
  echo "Streaming ${VID_CODEC}: ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
  # Stream the window and loopback audio as a low latency MPEG2-TS
  # - https://dennismungai.wordpress.com/2018/02/06/low-latency-live-streaming-for-your-desktop-using-ffmpeg-and-netcat/
  ${FFMPEG} -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
    -video_size ${VID_SIZE} -framerate ${VID_FPS} \
    -f x11grab -thread_queue_size 128 -draw_mouse ${VID_MOUSE} -r ${VID_FPS} -i ${VID_CAPTURE} \
    -f pulse -thread_queue_size 128 -channels 2 -sample_rate ${AUD_SAMPLERATE} -guess_layout_max 0 -i ${AUD_DEVICE} \
    -c:v ${VID_CODEC} -pix_fmt ${VID_COLORSPACE} -preset ${VID_PRESET} ${VID_CODEC_TUNING} ${VID_BT709} \
    -c:a aac -b:a ${AUD_BITRATE} -ac 2 -r:a ${AUD_SAMPLERATE} -strict experimental \
    -f ${VID_CONTAINER} "${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
elif [ "${LAUNCHER}" == "capture" ]; then
  echo "Capturing ${VID_CODEC}: ${LAUNCHER}-${STAMP}.mkv"
  # Capture the window and loopback audio as H.264/AAC in a Matroska container
  ${FFMPEG} -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
    -video_size ${VID_SIZE} -framerate ${VID_FPS} \
    -f x11grab -thread_queue_size 128 -draw_mouse ${VID_MOUSE} -r ${VID_FPS} -i ${VID_CAPTURE} \
    -f pulse -thread_queue_size 128 -channels 2 -sample_rate ${AUD_SAMPLERATE} -guess_layout_max 0 -i ${AUD_DEVICE} \
    -c:v ${VID_CODEC} -pix_fmt ${VID_COLORSPACE} -preset ${VID_PRESET} ${VID_CODEC_TUNING} ${VID_BT709} \
    -c:a aac -b:a ${AUD_BITRATE} -ac 2 -r:a ${AUD_SAMPLERATE} -strict experimental \
    "${LAUNCHER}-${STAMP}.mkv"
fi