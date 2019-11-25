#!/usr/bin/env bash

if [ -x /snap/bin/ffmpeg ]; then
  FFMPEG="/snap/bin/ffmpeg"
elif [ -x /usr/bin/ffmpeg ]; then
  FFMPEG="/usr/bin/ffmpeg"
else
  FFMPEG=""
fi
LAUNCHER=$(basename $0 .sh)
STAMP=$(date +"%C%j-%H%M%S")
LOG_LEVEL="warning"

# Network settings
IP_PROTO="tcp"
IP_PORT="4864"
IP_ADDR="127.0.0.1"

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
AUD_CODEC="aac"
AUD_SAMPLERATE=22050
AUD_BITRATE=96k
AUD_COMBINE="8-bit-vs-combine"
AUD_COMBINE_DESC="8-bit-Vs-Combine"
STREAM_OPTIONS=""

# More encoder threads beyond a certain threshold increases latency and will
# have a higher encoding memory footprint. Quality degradation is more
# prominent with higher thread counts in constant bitrate modes and
# near-constant bitrate mode called VBV (video buffer verifier), due to
# increased encode delay. 
CPU_CORES=$(cat /proc/cpuinfo | grep "cpu cores" | head -n 1 | cut -d':' -f2 | sed 's/ //g')
if [ ${CPU_CORES} -ge 4 ]; then
  THREADS=$((CPU_CORES / 2))
else
  THREADS=0
fi

function usage {
  echo
  echo "Usage"
  echo "  ${LAUNCHER} [--ffmpeg /snap/bin/ffmpeg ] [--fps 60 ] [--ip 192.168.0.1]"
  echo "              [--mouse] [--port 4864] [--protocol tcp|udp]"
  echo "              [--stream-options '?fifo_size=10240' [--vbitrate 640k]"
  echo "              [--vcodec libx264] [--vsync] [--help]"
  echo
  echo "You can also pass optional parameters"
  echo "  --ffmpeg        : Set the full path to ffmpeg."
  echo "  --fps           : Set framerate to stream at."
  echo "  --ip            : Set the IP address to stream to."
  echo "  --mouse         : Enable capture of mouse cursor; disabled by default."
  echo "  --port          : Set the tcp/udp port to stream to."
  echo "  --protocol      : Set the protocol to stream over. [tcp|udp]"
  echo "  --steam-options : Set tcp/udp stream options; such as '?fifo_size=10240'."
  echo "  --vbitrate      : Set video codec bitrate for the stream."
  echo "  --vcodec        : Set video codec for the stream. [libx264|h264_nvenc]"
  echo "  --vsync         : Enable vsync in the video encoder; disabled by default."
  echo "  --help          : This help."
  echo
  exit 1
}

# TODO - validate the inputs
# Check for optional parameters
while [ $# -gt 0 ]; do
  case "${1}" in
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
    -stream-options|--stream-options)
      STREAM_OPTIONS="$2"
      shift
      shift;;
    -vbitrate|--vbitrate)
      VID_BITRATE="$2"
      shift
      shift;;
    -vcodec|--vcodec)
      VID_CODEC="$2"
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
  tcp|udp) VID_CONTAINER="mpegts";;
esac

# Get the window we want to stream
# - https://unix.stackexchange.com/questions/14159/how-do-i-find-the-window-dimensions-and-position-accurately-including-decoration
TMP_XWININFO=$(mktemp -u)
echo -e "Please select the window you\nwould like to stream/capture by clicking the\nmouse in that window."
xwininfo | tee ${TMP_XWININFO}

# Crop menus and status areas from known emulators.
WIN_ID=$(grep "Window id:" ${TMP_XWININFO})
if [[ ${WIN_ID} == *"VICE"* ]]; then
  TOP_OFFSET=30
  BOT_OFFSET=$((TOP_OFFSET + 49))
# Fuse SDL doesn't require cropping
elif [[ ${WIN_ID} == *"Fuse -"* ]]; then
  TOP_OFFSET=0
  BOT_OFFSET=0
# Fuse GTK does require cropping
elif [[ ${WIN_ID} == *"Fuse"* ]]; then
  TOP_OFFSET=30
  BOT_OFFSET=$((TOP_OFFSET + 26))
else
  TOP_OFFSET=0
  BOT_OFFSET=0
fi

CAPTURE_X=$(sed -n -e "s/^ \+Absolute upper-left X: \+\([0-9]\+\).*/\1/p" ${TMP_XWININFO})
CAPTURE_Y=$(sed -n -e "s/^ \+Absolute upper-left Y: \+\([0-9]\+\).*/\1/p" ${TMP_XWININFO})
CAPTURE_Y=$((CAPTURE_Y + TOP_OFFSET))
CAPTURE_WIDTH=$(sed -n -e "s/^ \+Width: \+\([0-9]\+\).*/\1/p" ${TMP_XWININFO})
[ $((CAPTURE_WIDTH%2)) -ne 0 ] && ((CAPTURE_WIDTH--))
CAPTURE_HEIGHT=$(sed -n -e "s/^ \+Height: \+\([0-9]\+\).*/\1/p" ${TMP_XWININFO})
CAPTURE_HEIGHT=$((CAPTURE_HEIGHT - BOT_OFFSET))
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
  VID_PRESET="llhq"
  VID_CODEC_TUNING="-b:v ${VID_BITRATE} -g ${VID_GOP} -vsync ${VID_VSYNC}"
else
  if [ "${VID_CODEC}" != "libx264" ]; then
    echo "WARNING! nvenc does not appear to be available. Falling back to libx264."
  fi
  VID_CODEC="libx264"
  VID_PRESET="veryfast"
  VID_CODEC_TUNING="-x264opts no-sliced-threads:no-scenecut -tune zerolatency -bsf:v h264_mp4toannexb -b:v ${VID_BITRATE} -sc_threshold 0 -g ${VID_GOP} -vsync ${VID_VSYNC}"
fi

function audio_cleanup() {
  pactl unload-module ${AUD_COMBINE_MODULE} 2>/dev/null
}

# Call audio_cleanup() function on Ctrl+C 
trap "audio_cleanup" SIGINT SIGTERM

# Get the audio loopback device to record from; excludes Microphones.
# - https://obsproject.com/forum/resources/include-exclude-audio-sources-using-pulseaudio-linux.95/
# - https://unix.stackexchange.com/questions/488063/record-screen-and-internal-audio-with-ffmpeg
# - https://askubuntu.com/questions/516899/how-do-i-stream-computer-audio-only-with-ffmpeg

# Get default audio monitor
AUD_DEFAULT_MONITOR_DEVICE=$(pactl list short sources | grep RUNNING | grep monitor | grep -v 8-bit-vs-combine | head -n 1 | cut -f1 | sed 's/ //g')
AUD_DEFAULT_MONITOR_NAME=$(pactl list short sources | grep RUNNING | grep monitor | grep -v 8-bit-vs-combine | head -n 1 | cut -f2 | sed -e 's/ //g')

# Create a combine-sink, with just the default monitor as a slave
# - https://askubuntu.com/questions/60837/record-a-programs-output-with-pulseaudio/910879#910879
AUD_COMBINE_MODULE=$(pactl load-module module-combine-sink sink_name=${AUD_COMBINE} slaves=${AUD_DEFAULT_MONITOR_DEVICE} sink_properties=device.description=${AUD_COMBINE_DESC})

# Look up sink-input index by property
# - https://stackoverflow.com/questions/39736580/look-up-pulseaudio-sink-input-index-by-property
TMP_SINKINPUTS=$(mktemp -u)
pacmd list-sink-inputs | grep -v "sink input(s) available." | tr '\n' '\r' | perl -pe 's/ *index: ([0-9]+).+?application\.name = "([^\r]+)"\r.+?(?=index:|$)/\2:\1\r/g' | tr '\r' '\n' > ${TMP_SINKINPUTS}

# Move sinks for knowns apps to our combine-sink
AUD_MOVED_SINKS=0
while IFS="" read -r SINK_INPUT || [ -n "$SINK_INPUT" ]; do
  SINK_APP=$(echo "${SINK_INPUT}" | cut -d':' -f1)
  SINK_INDEX=$(echo "${SINK_INPUT}" | cut -d':' -f2)
  # Only move the sink if it is a known application
  if [[ ${SINK_APP} == *"VICE"* ]] || [[ ${SINK_APP} == *"fuse-gtk"* ]] || [[ ${SINK_APP} == *"Caprice32"* ]]; then
    echo "Moving audio for ${SINK_APP} (index:${SINK_INDEX}) to ${AUD_COMBINE}"
    pactl move-sink-input ${SINK_INDEX} ${AUD_COMBINE}
    AUD_MOVED_SINKS=1
  fi
done < $TMP_SINKINPUTS
rm -f $TMP_SINKINPUTS

# If we moved some sinks the make our combine-sink monitor the recording source
if [ ${AUD_MOVED_SINKS} -eq 1 ]; then
  AUD_COMBINE_MONITOR_DEVICE=$(pactl list short sources | grep ${AUD_COMBINE}.monitor | head -n 1 | cut -f1 | sed 's/ //g')
  AUD_RECORD_DEVICE=${AUD_COMBINE_MONITOR_DEVICE}
else
  AUD_RECORD_DEVICE=${AUD_DEFAULT_MONITOR_DEVICE}
fi

# Stream/Capture the window and loopback audio as a low latency
# H.264/AAC in MPEG2-TS (stream) or Matroska (capture) container
if [ "${LAUNCHER}" == "stream" ]; then
  echo "Streaming: ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
  OUTPUT="-f ${VID_CONTAINER} ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
elif [ "${LAUNCHER}" == "capture" ]; then
  echo "Capturing: ${LAUNCHER}-${STAMP}.mkv"
  OUTPUT="${LAUNCHER}-${STAMP}.mkv"
fi

# The ffmpeg pipeline
echo " - ${VID_SIZE}@${VID_FPS}fps using ${VID_CODEC}/${VID_PRESET} (${VID_BITRATE}) and ${AUD_CODEC} (${AUD_BITRATE}) [${VID_PROFILE}@L${VID_LEVEL}]"
${FFMPEG} -hide_banner -threads ${THREADS} -loglevel ${LOG_LEVEL} -stats \
-video_size ${VID_SIZE} -framerate ${VID_FPS} \
-f x11grab -thread_queue_size 128 -draw_mouse ${VID_MOUSE} -r ${VID_FPS} -i ${VID_CAPTURE} \
-f pulse -thread_queue_size 128 -channels 2 -sample_rate ${AUD_SAMPLERATE} -guess_layout_max 0 -i ${AUD_RECORD_DEVICE} \
-c:v ${VID_CODEC} -pix_fmt ${VID_COLORSPACE} -preset ${VID_PRESET} -profile:v ${VID_PROFILE} -level:v ${VID_LEVEL} ${VID_CODEC_TUNING} ${VID_BT709} \
-c:a ${AUD_CODEC} -b:a ${AUD_BITRATE} -ac 2 -r:a ${AUD_SAMPLERATE} -strict experimental \
${OUTPUT}
audio_cleanup