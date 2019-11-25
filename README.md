# simplestream

Low latency point-to-point game streamer & player; best suited for 8-bit
computer emulators. Can also capture locally and record streams.

## Video streaming and local capture

  * `stream.sh` - Streams the selected window and loopback audio as low latency MPEG2-TS (H.246/AAC) via UDP or TCP.
  * `capture.sh` - Captures the selected window and loopback audio as H.246/AAC in a Matroska container.

## Video player and recorder

  * `play-stream.sh` - Plays a UDP or TCP stream using low latency `ffplay` or `mpv`.
  * `record-stream.sh` - Records a UDP or TCP stream in a Matroska container.

# Requirements

  - `ffmpeg`
  - `nvidia-utils-xyx` (optional; required for h264_nvenc)
  - `mpv` (optional)
  - `vainfo` (optional; required for h264_vaapi)