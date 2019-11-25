#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! Must be root."
    exit 1
fi

# FFMPEG
snap install ffmpeg

# MPV
apt install -y mpv vainfo

# FUSE & VICE
apt install -y fuse-emulator-gtk fuse-emulator-sdl spectrum-roms vice

# VICE ROMS
cd /tmp
wget http://downloads.sourceforge.net/project/vice-emu/releases/vice-3.3.tar.gz -O vice-3.3.tar.gz
tar zxf vice-3.3.tar.gz

find vice-*/data \
  -mindepth 1 \
  -type d \
  -exec sudo cp -rnv {} /usr/lib/vice/ \;