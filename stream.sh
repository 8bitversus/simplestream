#!/usr/bin/env bash

FFMPEG="/snap/bin/ffmpeg"
IP_PROTO="tcp"
IP_PORT="4864"
IP_ADDR="127.0.0.1"
LAUNCHER=$(basename $0 .sh)
STAMP=$(date +"%C%j-%H%M%S")
LOG_LEVEL="warning"

# Select the video codec; change to "libx264" for software encoding. Derive other encoding configuration.
VID_CODEC="h264_nvenc"
VID_FPS="60"
VID_GOP=$((VID_FPS * 2))
VID_BITRATE="640k"
VID_COLORSPACE="yuv420p"
VID_PROFILE="high"
VID_LEVEL="4.2"
#  Format colour matrix to BT.709 to prevent colours "washing out"
#  - https://stackoverflow.com/questions/37255690/ffmpeg-format-settings-matrix-bt709
#  - https://kdenlive.org/en/project/color-hell-ffmpeg-transcoding-and-preserving-bt-601/
VID_BT709="-vf scale=out_color_matrix=bt709 -color_primaries bt709 -color_trc bt709 -colorspace bt709"
# Disable capturing the mouse xcursor; change to 1 to capture mouse xcursor
VID_MOUSE=0
# Disable vsync in the encoder/streamer; change to 1 to enable vsync
VID_VSYNC=0

# Audio encoding settings
AUD_SAMPLERATE=22050
AUD_BITRATE=96k

function usage {
  echo
  echo "Usage"
  echo "  ${LAUNCHER} [--ffmpeg /snap/bin/ffmpeg ] [--fps 60 ] [--ip 192.168.0.1]"
  echo "              [--mouse] [--port 4864] [--protocol tcp|udp]"
  echo "              [--vbitrate 640k] [--vcodec libx264] [--vsync] [--help]"
  echo
  echo "You can also pass optional parameters"
  echo "  --ffmpeg   : Set the full path to ffmpeg."
  echo "  --fps      : Set framerate to stream at."
  echo "  --ip       : Set the IP address to stream to."
  echo "  --mouse    : Enable capture of mouse cursor; disabled by default."
  echo "  --port     : Set the tcp/udp port to stream to."
  echo "  --protocol : Set the protocol to stream over. [tcp|udp]"
  echo "  --vbitrate : Set video codec bitrate for the stream."
  echo "  --vcodec   : Set video codec for the stream. [libx264|h264_nvenc]"
  echo "  --vsync    : Enable vsync in the video encoder; disabled by default."
  echo "  --help     : This help."
  echo
  exit 1
}

# TODO - validate the inputs
# Check for optional parameters
while [ $# -gt 0 ]; do
  case "${1}" in
    -bitrate|--bitrate)
      VID_BITRATE="$2"
      shift
      shift;;
    -codec|--codec)
      VID_CODEC="$2"
      shift
      shift;;
    -ffmpeg|--ffmpeg)
      FFMPEG="$2"
      shift
      shift;;
    -fps|--fps)
      VID_FPS="$2"
      shift
      shift;;
    -ip|--ip)
      IP_ADDR="$2"
      shift
      shift;;
    -mouse|--mouse)
      VID_MOUSE=1
      shift;;
    -port|--port)
      IP_PORT="$2"
      shift
      shift;;
    -protocol|--protocol)
      IP_PROTO="$2"
      shift
      shift;;
    -vsync|--vsync)
      VID_VSYNC=1
      shift;;
    -h|--h|-help|--help)
      usage;;
    *)
      echo "ERROR! \"${1}\" is not s supported parameter."
      usage;;
  esac
done

if [ ! -e "${FFMPEG}" ]; then
  echo "ERROR! Could not find ${FFMPEG}. Quitting."
  exit 1
fi

# Use the appropriate container based on the protocol selected.
case ${IP_PROTO} in
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

#TODO - Isolate the emulator audio only
# - https://obsproject.com/forum/resources/include-exclude-audio-sources-using-pulseaudio-linux.95/
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

TEST_NVENC=$(nvidia-smi -q | grep Encoder | wc -l)
TEST_CUDA=$(${FFMPEG} -hide_banner -hwaccels | grep cuda | sed -e 's/ //g')

# TODO: Tune the encoders
# - https://devblogs.nvidia.com/turing-h264-video-encoding-speed-and-quality/
# - https://superuser.com/questions/1296374/best-settings-for-ffmpeg-with-nvenc
if [ ${TEST_NVENC} -ge 1 ]  && [ "${TEST_CUDA}" == "cuda" ]  &&  [ "${VID_CODEC}" == "h264_nvenc" ]; then
  VID_PRESET="llhp"
  VID_CODEC_TUNING="-rc cbr_ld_hq -b:v ${VID_BITRATE} -g ${VID_GOP} -vsync ${VID_VSYNC}"
else
  if [ "${VID_CODEC}" != "libx264" ]; then
    echo "WARNING! nvenc does not appear to be available. Falling back to libx264."
  fi
  VID_CODEC="libx264"
  VID_PRESET="veryfast"
  VID_CODEC_TUNING="-x264opts no-sliced-threads -tune zerolatency -bsf:v h264_mp4toannexb -b:v ${VID_BITRATE} -g ${VID_GOP} -vsync ${VID_VSYNC}"
fi

if [ "${LAUNCHER}" == "stream" ]; then
  echo "Streaming ${VID_CODEC}: ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
  # Stream the window and loopback audio as a low latency MPEG2-TS
  # - https://dennismungai.wordpress.com/2018/02/06/low-latency-live-streaming-for-your-desktop-using-ffmpeg-and-netcat/
  ${FFMPEG} -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
    -video_size ${VID_SIZE} -framerate ${VID_FPS} \
    -f x11grab -thread_queue_size 128 -draw_mouse ${VID_MOUSE} -r ${VID_FPS} -i ${VID_CAPTURE} \
    -f pulse -thread_queue_size 128 -channels 2 -sample_rate ${AUD_SAMPLERATE} -guess_layout_max 0 -i ${AUD_DEVICE} \
    -c:v ${VID_CODEC} -pix_fmt ${VID_COLORSPACE} -preset ${VID_PRESET} -profile:v ${VID_PROFILE} -level:v ${VID_LEVEL} ${VID_CODEC_TUNING} ${VID_BT709} \
    -c:a aac -b:a ${AUD_BITRATE} -ac 2 -r:a ${AUD_SAMPLERATE} -strict experimental \
    -f ${VID_CONTAINER} "${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
elif [ "${LAUNCHER}" == "capture" ]; then
  echo "Capturing ${VID_CODEC}: ${LAUNCHER}-${STAMP}.mkv"
  # Capture the window and loopback audio as H.264/AAC in a Matroska container
  ${FFMPEG} -hide_banner -threads 0 -loglevel ${LOG_LEVEL} -stats \
    -video_size ${VID_SIZE} -framerate ${VID_FPS} \
    -f x11grab -thread_queue_size 128 -draw_mouse ${VID_MOUSE} -r ${VID_FPS} -i ${VID_CAPTURE} \
    -f pulse -thread_queue_size 128 -channels 2 -sample_rate ${AUD_SAMPLERATE} -guess_layout_max 0 -i ${AUD_DEVICE} \
    -c:v ${VID_CODEC} -pix_fmt ${VID_COLORSPACE} -preset ${VID_PRESET} -profile:v ${VID_PROFILE} -level:v ${VID_LEVEL} ${VID_CODEC_TUNING} ${VID_BT709} \
    -c:a aac -b:a ${AUD_BITRATE} -ac 2 -r:a ${AUD_SAMPLERATE} -strict experimental \
    "${LAUNCHER}-${STAMP}.mkv"
fi