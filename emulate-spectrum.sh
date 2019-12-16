#!/usr/bin/env bash

cp configs/zxspectrum48k.conf ${HOME}/.fuserc
fuse-gtk -g paltv2x --pal-tv2x "$@"
