#!/bin/sh

echo 'int main() { gst_pad_new(); }' > /tmp/test.c
gcc -m32 -fno-lto /tmp/test.c `PKG_CONFIG_PATH=/usr/local/lib/gstreamer-1.0/pkgconfig pkg-config --libs --static gstreamer-full-1.0` -lstdc++ -lmp3lame
