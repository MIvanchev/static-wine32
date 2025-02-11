#!/bin/sh

echo 'int main() { eglGetProcAddress(); }' > /tmp/test.c
gcc -m32 -fno-lto /tmp/test.c `pkg-config --libs --static egl`
