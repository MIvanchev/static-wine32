#!/bin/sh

echo 'int main() { wl_egl_window_create(); }' > /tmp/test.c
gcc -m32 -fno-lto /tmp/test.c `pkg-config --libs --static wayland-egl`
