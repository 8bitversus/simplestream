# Simple Stream

Low latency point-to-point game streamer & player; best suited for 8-bit
computer emulators. Can also capture locally and record streams.

## What it do?

Simple Stream uses `ffmpeg` to stream a window as low latency MPEG2-TS
(H.246/AAC) via either SRT, TCP or UDP. Audio is sourced from all desktop audio
(excluding microphones) or just the audio of emulators Simple Stream is aware
of.

The SRT, TCP and UDP streams created are intended for a remote observer to watch
or be included in an [OBS Studio](https://obsproject.com/) scene via Media Source.

Video can be encoded using `libx264`, `h264_nvenc` and `h264_vaapi`. `libx264`
and `h264_nvenc` are recommended as they are both tuned for low latency.

Simple Stream is currently *"aware"* of the following emulators, which means it
knows how to crop out menus and status areas to optimise the stream and also how
to automatically route just their audio.

  * [Caprice32 - Amstrad CPC Emulator](https://github.com/ColinPitrat/caprice32)
  * [Fuse - the Free Unix Spectrum Emulator](http://fuse-emulator.sourceforge.net/)
  * [VICE - the Versatile Commodore Emulator](http://vice-emu.sourceforge.net/)

In order to stream point-to-point the receiving party must configure NAT on
their router to allow the appropriate port (4864 by default) to be allowed
through. When streaming via TCP (the default), `play-stream.sh` must be started
by the receiving party before the streamer starts `stream.sh`.

### Example

Fred wants to stream game play to his friend Barny.

#### Barny

  1. Barny configures NAT on his router to accept TCP/UDP on port 4864 and routes that to his PC.
  2. Barny runs `./play-stream.sh -ip 24.65.43.257`, where 24.65.43.257 is his routers Internet facing IP address.
  3. Barny tells Fred he is ready to receive and his IP address.

#### Fred

  1. Fred runs `./stream.sh -ip 24.65.43.257`
  2. When prompted Fred clicks on the window of the game he wants to stream.
  3. Fred is now streaming to Barny.

#### Barny

  1. Barny will see a window of Fred's game appear.
  2. When Barny closes the stream it will automatically disconnect Fred's stream.

# Requirements

Simple Stream is a shell script that uses the following awesome software.

  - `bc`
  - `coreutils`
  - `grep`
  - `ffmpeg` (snap preferred since it enables h264_nvenc and h264_vaapi)
  - `nvidia-settings` (optional; required for reliable capture when using nvidia drivers)
  - `nvidia-utils-xyx` (optional; required for h264_nvenc)
  - `mpv` (optional)
  - `pulseaudio-utils`
  - `scrot`
  - `sed`
  - `vainfo` (optional; required for h264_vaapi)
  - `x11-utils`

## Install

### Ubuntu 18.04 or newer

Run `install.sh` included in this repository.

# Documentation

The scripts in Simple Stream try and do the right thing by default, but if you
need to tweak their behaviour this is how to do it.

## Video streaming and local capture

  * `stream.sh` - Streams the selected window and loopback audio (MPEG2-TS).
  * `capture.sh` - Captures the selected window and loopback audio (Matroska).

```
Usage
  stream [--abitrate 96k] [--acodec mp2] [--asamplerate 44100] [--channels 1] [--colspace bt601]
              [--ffmpeg /snap/bin/obs-studio.ffmpeg] [--fps 60] [--ip 192.168.0.1] [--mouse] [--pixfmt nv12] [--port 4864] [--protocol srt|tcp|udp]
              [--signal PAL] [--stream-options '?fifo_size=10240'] [--vaapi-device /dev/dri/renderD128]
              [--vbitrate 640000] [--vcodec libx264] [--vsync auto|passthrough|cfr|vfr|drop] [--help]

You can also pass optional parameters
  --abitrate      : Set audio codec bitrate for the stream in kbits/sec.
  --acodec        : Set audio codec for the stream. [aac|mp2|mp3]
  --asamplerate   : Set audio sample rate for the stream.
  --channels      : Set audio channels [1|2].
  --colspace      : Set color space. [bt601|bt709]
  --ffmpeg        : Set the full path to ffmpeg.
  --fps           : Set framerate to stream at.
  --ip            : Set the IP address to stream to.
  --mouse         : Enable capture of mouse cursor; disabled by default.
  --pixfmt        : Set the pixel format [nv12|yuv420p]
  --port          : Set the tcp/udp port to stream to.
  --protocol      : Set the protocol to stream over. [tcp|udp]
  --signal        : Set video signal. [PAL|NTSC]
  --steam-options : Set tcp/udp stream options; such as '?fifo_size=10240'.
  --vaapi-device  : Set the full path to the VA-API device; such as /dev/dri/renderD128
  --vbitrate      : Set video codec bitrate for the stream in bits/sec.
  --vcodec        : Set video codec for the stream. [libx264|h264_nvenc|h264_vaapi]
  --vsync         : Set vsync method in the video encoder; 'auto' by default.
  --help          : This help.
```

## Video player and recorder

  * `play-stream.sh` - Plays a SRT, TCP or UDP stream using `ffplay`
  * `record-stream.sh` - Records a SRT, TCP or UDP stream using `ffmpeg`.

```
Usage
  play-stream [--ip 192.168.0.1] [--player [ffplay|mpv] [--port 4864] [--protocol srt|tcp|udp] [--help]

You can also pass optional parameters
  --ip       : Set the IP address to play from.
  --player   : Set the player. [ffplay|mpv]
  --port     : Set the tcp/udp port to connect to.
  --protocol : Set the protocol to play over. [srt|tcp|udp]
  --help     : This help.
```
