# simplestream

Low latency streamer and player/recorder for Linux.

## Video streaming and local capture

  * `stream.sh` - Streams the selected window and loopback audio as low latency MPEG2-TS (H.246/AAC) via UDP.
  * `capture.sh` - Captures the selected window and loopback audio as H.246/AAC in a Matroska container.

## Video player and recorder

  * `play-stream.sh` - Plays a UDP stream using low latency `ffplay`.
  * `record-stream.sh` - Records a UDP stream in a Matroska container.