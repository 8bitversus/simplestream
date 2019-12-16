#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! Must be root."
    exit 1
fi

# Essentials components
apt install -y coreutils grep pulseaudio-utils scrot sed vainfo x11-utils

# FFMPEG
snap install ffmpeg

# Caprice32
snap install caprice32

# FUSE
apt install -y fuse-emulator-gtk fuse-emulator-sdl spectrum-roms

# VICE
apt install -y vice

# VICE ROMS
cd /tmp
wget http://downloads.sourceforge.net/project/vice-emu/releases/vice-3.3.tar.gz -O vice-3.3.tar.gz
tar zxf vice-3.3.tar.gz

find vice-*/data \
  -mindepth 1 \
  -type d \
  -exec cp -rnv {} /usr/lib/vice/ \;

# MPV
apt install -y mpv