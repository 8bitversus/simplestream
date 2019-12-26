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
VID_BITRATE="0k"
VID_PIXELFORMAT="nv12"
# Set the colour space to use; bt601 preserves the colour from emulators so is the default.
VID_COLORSPACE="bt601"
VID_SIGNAL="PAL"
VID_PROFILE="high"
VID_LEVEL="4.2"
# Disable capturing the mouse xcursor; change to 1 to capture mouse xcursor
VID_MOUSE=0
# Select vsync in the encoder/streamer; default is -1 (auto)
VID_VSYNC="-1"

# Audio encoding settings
AUD_CODEC="mp2"
AUD_SAMPLERATE="22050"
AUD_BITRATE="96k"
AUD_COMBINE="8-bit-vs-combine"
AUD_COMBINE_DESC="8-bit-Vs-Combine"
STREAM_OPTIONS=""
VAAPI_DEVICE="/dev/dri/renderD128"

function usage {
  echo
  echo "Usage"
  echo "  ${LAUNCHER} [--abitrate 96k] [--asamplerate 22050] [--ffmpeg /snap/bin/ffmpeg]"
  echo "              [--fps 60] [--ip 192.168.0.1] [--mouse] [--port 4864] [--protocol tcp|udp]"
  echo "              [--stream-options '?fifo_size=10240'] [--vaapi-device /dev/dri/renderD128]"
  echo "              [--vbitrate 640k] [--vcodec libx264] [--vsync auto|passthrough|cfr|vfr|drop] [--help]"
  echo
  echo "You can also pass optional parameters"
  echo "  --abitrate      : Set audio codec bitrate for the stream."
  echo "  --asamplerate   : Set audio sample rate for the stream."
  echo "  --ffmpeg        : Set the full path to ffmpeg."
  echo "  --fps           : Set framerate to stream at."
  echo "  --ip            : Set the IP address to stream to."
  echo "  --mouse         : Enable capture of mouse cursor; disabled by default."
  echo "  --port          : Set the tcp/udp port to stream to."
  echo "  --protocol      : Set the protocol to stream over. [tcp|udp]"
  echo "  --steam-options : Set tcp/udp stream options; such as '?fifo_size=10240'."
  echo "  --vaapi-device  : Set the full path to the VA-API device; such as /dev/dri/renderD128"
  echo "  --vbitrate      : Set video codec bitrate for the stream."
  echo "  --vcodec        : Set video codec for the stream. [libx264|h264_nvenc|h264_vaapi]"
  echo "  --vsync         : Set vsync method in the video encoder; 'auto' by default."
  echo "  --help          : This help."
  echo
  exit 1
}

# TODO - validate the inputs
# Check for optional parameters
while [ $# -gt 0 ]; do
  case "${1}" in
    -abitrate|--abitrate)
      AUD_BITRATE="$2"
      shift
      shift;;
    -asamplerate|--asamplerate)
      AUD_SAMPLERATE="$2"
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
    -stream-options|--stream-options)
      STREAM_OPTIONS="$2"
      shift
      shift;;
    -vaapi-device|--vaapi-device)
      VAAPI_DEVICE="$2"
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
      VID_VSYNC="$2"
      shift
      shift;;
    -h|--h|-help|--help)
      usage;;
    *)
      echo "ERROR! \"${1}\" is not a supported parameter."
      usage;;
  esac
done

if [ ! -e "${FFMPEG}" ]; then
  echo "ERROR! Could not find ${FFMPEG}. Quitting."
  exit 1
fi

if [ "${IP_PROTO}" != "tcp" ] && [ "${IP_PROTO}" != "udp" ]; then
  echo "ERROR! Unknown IP protocol: ${IP_PROTO}. Quitting."
  exit 1
fi

if [ "${AUD_CODEC}" == "aac" ]; then
  AUD_CODEC_EXTRA="-bsf:a aac_adtstoasc"
else
  AUD_CODEC_EXTRA=""
fi

if [ "${VID_CODEC}" != "libx264" ] && [ "${VID_CODEC}" != "h264_nvenc" ] && [ "${VID_CODEC}" != "h264_vaapi" ]; then
  echo "ERROR! Unknown video codec: ${VID_CODEC}. Quitting."
  exit 1
fi

if [ "${VID_VSYNC}" != "auto" ] && \
   [ "${VID_VSYNC}" != "passthrough" ] && \
   [ "${VID_VSYNC}" != "cfr" ] && \
   [ "${VID_VSYNC}" != "vfr" ] && \
   [ "${VID_VSYNC}" != "drop" ] && \
   [ "${VID_VSYNC}" != "-1" ] && \
   [ "${VID_VSYNC}" != "0" ] && \
   [ "${VID_VSYNC}" != "1" ] && \
   [ "${VID_VSYNC}" != "2" ]; then
  echo "ERROR! Unknown vsync method: ${VID_VSYNC}. Quitting."
  exit 1
fi

# Set the appropriate colour space/matrix variables
#  - https://stackoverflow.com/questions/37255690/ffmpeg-format-settings-matrix-bt709
#  - https://kdenlive.org/en/project/color-hell-ffmpeg-transcoding-and-preserving-bt-601/
case ${VID_COLORSPACE} in
  bt601)
    # FIXME! This is a crude way to distinguish PAL/NTSC video
    case ${VID_SIGNAL} in
      PAL)
        VID_COLORMATRIX="gamma28"
        VID_COLORSPACE="bt470bg"
      ;;
      NTSC)
        VID_COLORMATRIX="smpte170m"
        VID_COLORSPACE="smpte170m"
      ;;
    esac
    ;;
  bt709)
    VID_COLORMATRIX="bt709"
    ;;
esac

# Use the appropriate container based on the protocol selected.
case ${IP_PROTO} in
  tcp|udp) VID_CONTAINER="mpegts";;
esac

# Get the window we want to stream
# - https://unix.stackexchange.com/questions/14159/how-do-i-find-the-window-dimensions-and-position-accurately-including-decoration
TMP_XWININFO=$(mktemp -u)
echo -e "Please select the window you\nwould like to stream/capture by clicking the\nmouse in that window."
xwininfo | tee ${TMP_XWININFO} > /dev/null

# Crop menus and status areas from known emulators.
WIN_ID=$(grep "Window id:" ${TMP_XWININFO})
if [[ ${WIN_ID} == *"VICE"* ]]; then
  TOP_OFFSET=28
  BOT_OFFSET=$((TOP_OFFSET + 49))
  LEFT_OFFSET=0
  RIGHT_OFFSET=0
# Fuse SDL doesn't require cropping
elif [[ ${WIN_ID} == *"Fuse -"* ]]; then
  TOP_OFFSET=47
  BOT_OFFSET=$((TOP_OFFSET + 47))
  LEFT_OFFSET=64
  RIGHT_OFFSET=64
# Fuse GTK does require cropping
elif [[ ${WIN_ID} == *"Fuse"* ]]; then
  TOP_OFFSET=77
  BOT_OFFSET=$((TOP_OFFSET + 73))
  LEFT_OFFSET=64
  RIGHT_OFFSET=64
else
  TOP_OFFSET=0
  BOT_OFFSET=0
  LEFT_OFFSET=0
  RIGHT_OFFSET=0
fi

CAPTURE_X=$(sed -n -e "s/^ \+Absolute upper-left X: \+\([0-9]\+\).*/\1/p" ${TMP_XWININFO})
CAPTURE_X=$((CAPTURE_X + LEFT_OFFSET))
CAPTURE_Y=$(sed -n -e "s/^ \+Absolute upper-left Y: \+\([0-9]\+\).*/\1/p" ${TMP_XWININFO})
CAPTURE_Y=$((CAPTURE_Y + TOP_OFFSET))
CAPTURE_WIDTH=$(sed -n -e "s/^ \+Width: \+\([0-9]\+\).*/\1/p" ${TMP_XWININFO})
CAPTURE_WIDTH=$((CAPTURE_WIDTH - LEFT_OFFSET - RIGHT_OFFSET))
[ $((CAPTURE_WIDTH%2)) -ne 0 ] && ((CAPTURE_WIDTH--))
CAPTURE_HEIGHT=$(sed -n -e "s/^ \+Height: \+\([0-9]\+\).*/\1/p" ${TMP_XWININFO})
CAPTURE_HEIGHT=$((CAPTURE_HEIGHT - BOT_OFFSET))
[ $((CAPTURE_HEIGHT%2)) -ne 0 ] && ((CAPTURE_HEIGHT--))
rm -f ${TMP_XWININFO}
VID_CAPTURE="${DISPLAY}+${CAPTURE_X},${CAPTURE_Y}"
VID_SIZE="${CAPTURE_WIDTH}x${CAPTURE_HEIGHT}"

# If video bitrate was not manually provided, dynamically calculate it
if [ "${VID_BITRATE}" == "0k" ]; then
  VID_BITRATE=$(( (((CAPTURE_WIDTH/8) * VID_FPS)/10) + (CAPTURE_HEIGHT/3) ))
  [ $((VID_BITRATE%2)) -ne 0 ] && ((VID_BITRATE++))
  VID_BITRATE="${VID_BITRATE}k"
fi

# Do we have nvenc capable hardware?
TEST_NVENC=$(nvidia-smi -q | grep Encoder | wc -l)
TEST_CUDA=$(${FFMPEG} -hide_banner -hwaccels | grep cuda | sed -e 's/ //g')

# Do we have VA-API capable hardware?
TEST_VAINFO=$(vainfo 2>/dev/null)
TEST_VAAPI=$?

# More encoder threads beyond a certain threshold increases latency
# (~1 frame per thread) and will have a higher encoding memory footprint.
# Quality degradation is more prominent with higher thread counts in
# constant bitrate modes and near-constant bitrate mode called VBV
# (video buffer verifier), due to increased encode delay.
# 
# Therefore use 1 thread when using h264_nvenc/h264_vaapi encoding and 2 threads when using libx264
if [ ${TEST_NVENC} -ge 1 ]  && [ "${TEST_CUDA}" == "cuda" ]  &&  [ "${VID_CODEC}" == "h264_nvenc" ]; then
  VID_PRESET="ll"
  VID_PRESET_FULL="-preset ${VID_PRESET}"
  VID_CODEC_COMMON="-b:v ${VID_BITRATE} -g ${VID_GOP} -vsync ${VID_VSYNC} -sc_threshold 0"
  VID_CODEC_EXTRA="-filter:v scale=out_color_matrix=${VID_COLORMATRIX} -no-scenecut 1"
  VID_CODEC_COLORS="-color_primaries ${VID_COLORSPACE} -color_trc ${VID_COLORMATRIX} -colorspace ${VID_COLORSPACE} -color_range 1"
  THREADS=1
  DISABLE_FLIPPING=$(nvidia-settings -a ${DISPLAY}/AllowFlipping=0)
elif [ ${TEST_VAAPI} -eq 0 ] && [ "${VID_CODEC}" == "h264_vaapi" ]; then
  VID_PIXELFORMAT="vaapi_vld"
  VID_PRESET_FULL=""
  VID_CODEC_COMMON="-b:v ${VID_BITRATE} -g ${VID_GOP} -vsync ${VID_VSYNC} -sc_threshold 0"
  VID_CODEC_EXTRA="-vaapi_device ${VAAPI_DEVICE} -filter:v format=${VID_PIXELFORMAT},hwupload"
  VID_CODEC_COLORS=""
  THREADS=1
  if [ ! -e "${VAAPI_DEVICE}" ]; then
    echo "ERROR! Could not find VA-API device: ${VAAPI_DEVICE}. Quitting."
    exit 1
  fi
else
  if [ "${VID_CODEC}" != "libx264" ]; then
    echo "WARNING! nvenc does not appear to be available. Falling back to libx264."
  fi
  VID_CODEC="libx264"
  VID_PRESET="veryfast"
  VID_PRESET_FULL="-preset ${VID_PRESET}"
  VID_CODEC_COMMON="-b:v ${VID_BITRATE} -g ${VID_GOP} -vsync ${VID_VSYNC} -sc_threshold 0"
  VID_CODEC_EXTRA="-filter:v scale=out_color_matrix=${VID_COLORMATRIX} -x264opts no-sliced-threads:no-scenecut -tune zerolatency -bsf:v h264_mp4toannexb"
  VID_CODEC_COLORS="-color_primaries ${VID_COLORSPACE} -color_trc ${VID_COLORMATRIX} -colorspace ${VID_COLORSPACE} -color_range 1"
  CPU_CORES=$(cat /proc/cpuinfo | grep "cpu cores" | head -n 1 | cut -d':' -f2 | sed 's/ //g')
  if [ ${CPU_CORES} -ge 2 ]; then
    THREADS=2
  else
    THREADS=1
  fi
fi

function cleanup_trap() {
  pactl unload-module ${AUD_COMBINE_MODULE} 2>/dev/null

  # Are there any module-combine-sink left behind?
  local TMP_COMBINE_MODULES=$(mktemp -u)
  pactl list modules short | grep module-combine-sink | grep "${AUD_COMBINE}" > "${TMP_COMBINE_MODULES}"
  if [ -s "${TMP_COMBINE_MODULES}" ]; then
    echo "Found: module-combine-sink for ${AUD_COMBINE}"
    while IFS="" read -r MODULE_INPUT || [ -n "${MODULE_INPUT}" ]; do
      # Resolve module index
      local MODULE_INDEX=$(echo "${MODULE_INPUT}" | cut -f1 | sed -e 's/ //g')
      echo " - Unloading: ${MODULE_INDEX}"
      pactl unload-module "${MODULE_INDEX}"
    done < "${TMP_COMBINE_MODULES}"
  fi
  rm -f "${TMP_COMBINE_MODULES}"
}

# Call cleanup_trap() function on Ctrl+C 
trap "cleanup_trap" SIGINT SIGTERM

# Get the audio loopback device to record from; excludes Microphones.
# - https://obsproject.com/forum/resources/include-exclude-audio-sources-using-pulseaudio-linux.95/
# - https://unix.stackexchange.com/questions/488063/record-screen-and-internal-audio-with-ffmpeg
# - https://askubuntu.com/questions/516899/how-do-i-stream-computer-audio-only-with-ffmpeg

# Get default audio device
AUD_DEFAULT_DEVICE=$(pactl list short sinks | grep RUNNING | grep -v ${AUD_COMBINE} | head -n 1 | cut -f2 | sed 's/ //g')

# Create a combine-sink, with just the default audio device as a slave
# - https://askubuntu.com/questions/60837/record-a-programs-output-with-pulseaudio/910879#910879
AUD_COMBINE_MODULE=$(pactl load-module module-combine-sink sink_name=${AUD_COMBINE} slaves=${AUD_DEFAULT_DEVICE} sink_properties=device.description=${AUD_COMBINE_DESC})

# Get a list of sink-inputs; apps capable of playing audio
TMP_SHORT_INPUTS=$(mktemp -u)
TMP_LONG_INPUTS=$(mktemp -u)
pactl list short sink-inputs > "${TMP_SHORT_INPUTS}"
pacmd list-sink-inputs > "${TMP_LONG_INPUTS}"

# Move sinks for known apps to our combine-sink
AUD_MOVED_SINKS=0
while IFS="" read -r SINK_INPUT || [ -n "${SINK_INPUT}" ]; do
  # Resolve sink-index client to app name
  SINK_INDEX=$(echo "${SINK_INPUT}" | cut -f1 | sed -e 's/ //g')
  SINK_CLIENT=$(echo "${SINK_INPUT}" | cut -f3 | sed -e 's/ //g' -e 's/-//g')
  if [ -n "${SINK_CLIENT}" ]; then
    SINK_APP=$(grep client "${TMP_LONG_INPUTS}" | grep ${SINK_CLIENT} | cut -d'<' -f2 | cut -d '>' -f1)
    # Only move the sink if it is a known application
    if [[ ${SINK_APP} == "VICE" ]] || [[ ${SINK_APP} == *"fuse-gtk"* ]] || [[ ${SINK_APP} == "Fuse"* ]] || [[ ${SINK_APP} == "Caprice32"* ]]; then
      echo "Moving audio for ${SINK_APP} [index:${SINK_INDEX}][client:${SINK_CLIENT}] to ${AUD_COMBINE}"
      pactl move-sink-input ${SINK_INDEX} ${AUD_COMBINE}
      AUD_MOVED_SINKS=1
    fi
  fi
done < "${TMP_SHORT_INPUTS}"
rm -f "${TMP_SHORT_INPUTS}"
rm -f "${TMP_LONG_INPUTS}"

# If we moved some sinks the make our combine-sink monitor the recording source
if [ ${AUD_MOVED_SINKS} -eq 1 ]; then
  AUD_COMBINE_DEVICE=$(pactl list short sources | grep ${AUD_COMBINE}.monitor | head -n 1 | cut -f1 | sed 's/ //g')
  AUD_RECORD_DEVICE=${AUD_COMBINE_DEVICE}
else
  AUD_RECORD_DEVICE=${AUD_DEFAULT_DEVICE}
fi

# Stream/Capture the window and loopback audio as a low latency
# H.264/AAC in MPEG2-TS (stream) or Matroska (capture) container
if [ "${LAUNCHER}" == "stream" ]; then
  echo "Streaming: ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
  OUTPUT="-f ${VID_CONTAINER} -metadata service_name=8BitVersusStream -metadata service_provider=8BitVersus ${IP_PROTO}://${IP_ADDR}:${IP_PORT}${STREAM_OPTIONS}"
elif [ "${LAUNCHER}" == "capture" ]; then
  echo "Capturing: ${LAUNCHER}-${STAMP}.mkv"
  OUTPUT="${LAUNCHER}-${STAMP}.mkv"
fi

# The ffmpeg pipeline
# - TODO -af "aresample=async=1:min_hard_comp=0.100000:first_pts=0"
# - https://videoblerg.wordpress.com/2017/11/10/ffmpeg-and-how-to-use-it-wrong/
echo " - ${VID_SIZE}@${VID_FPS}fps using ${VID_CODEC}/${VID_PRESET} (${VID_BITRATE}) and ${AUD_CODEC} (${AUD_BITRATE}) [${VID_PROFILE}@L${VID_LEVEL}]"
${FFMPEG} -hide_banner -threads ${THREADS} -loglevel ${LOG_LEVEL} -stats \
-video_size ${VID_SIZE} -framerate ${VID_FPS} \
-fflags nobuffer+flush_packets -flags low_delay \
-f x11grab -thread_queue_size 256 -draw_mouse ${VID_MOUSE} -r ${VID_FPS} -src_range 0 -i ${VID_CAPTURE} \
-f pulse -thread_queue_size 256 -channels 2 -sample_rate ${AUD_SAMPLERATE} -guess_layout_max 0 -i ${AUD_RECORD_DEVICE} \
-c:v ${VID_CODEC} -pix_fmt ${VID_PIXELFORMAT} ${VID_PRESET_FULL} -profile:v ${VID_PROFILE} -level:v ${VID_LEVEL} ${VID_CODEC_COMMON} ${VID_CODEC_EXTRA} ${VID_CODEC_COLORS} -dst_range 0 \
-c:a ${AUD_CODEC} -b:a ${AUD_BITRATE} -ac 2 -r:a ${AUD_SAMPLERATE} -strict experimental ${AUD_CODEC_EXTRA} \
${OUTPUT}
cleanup_trap