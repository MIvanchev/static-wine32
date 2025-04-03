#!/bin/sh

echo 'int main() { gp_camera_new(); }' > /tmp/test.c
gcc -m32 -fno-lto /tmp/test.c `pkg-config --libs --static libgphoto2`
echo 'int main() { gp_port_info_list_new(); }' > /tmp/test.c
gcc -m32 -fno-lto /tmp/test.c `pkg-config --libs --static libgphoto2_port`
