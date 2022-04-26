FROM ubuntu:20.04

SHELL ["/bin/bash", "-c"]

RUN apt update && \
    apt upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y build-essential pkg-config \
        gcc-multilib g++-multilib gcc-mingw-w64 flex bison python3 \
        python3-pip wget git cmake ninja-build gperf automake \
        libtool autopoint gettext && \
    pip3 install mako meson jinja2 && \
    DEBIAN_FRONTEND=noninteractive apt install -y nano xvfb x11-apps \
        imagemagick && \
    echo "#!/bin/sh" > /usr/bin/startx && \
    echo "Xvfb \"\$DISPLAY\" -screen 0 1200x800x24 &" >> /usr/bin/startx && \
    echo >> /usr/bin/startx && \
    chmod +x /usr/bin/startx

ENV DISPLAY=:1

COPY dependencies /build
COPY meson-cross-i386 /build/

ARG PATH="$PATH:/usr/local/bin"

ARG CONFIGURE_FLAGS="CFLAGS=\"-m32 -O2\" CPPFLAGS=\"-m32 -O2\" CXXFLAGS=\"-m32 -O2\" OBJCFLAGS=\"-m32 -O2\" LDFLAGS=-m32"
ARG CONFIGURE_PROLOGUE="--prefix=/usr/local"
ARG CONFIGURE_HOST="--host=i386-linux-gnu"
ARG MESON_PROLOGUE="--prefix=/usr/local --buildtype=release --cross-file=../meson-cross-i386 --default-library=static"

ARG DEP_BUILD_SCRIPT="\
[macros-util-macros] autoreconf -v --install\n\
[macros-util-macros] ./configure $CONFIGURE_PROLOGUE $CONFIGURE_FLAGS\n\
[macros-util-macros] make install\n\
[zlib] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --static\n\
[zlib] make install\n\
[libxkbcommon] meson setup build $MESON_PROLOGUE \
-Denable-wayland=false \
-Denable-docs=false \
-Denable-tools=false \n\
[libxkbcommon] cd build\n\
[libxkbcommon] meson compile xkbcommon xkbcommon-x11 xkbregistry\n\
[libxkbcommon] meson install --no-rebuild\n\
[fontconfig] ./configure $CONFIGURE_PROLOGUE --sysconfdir=/etc --enable-static --disable-shared --disable-docs $CONFIGURE_FLAGS\n\
[fontconfig] make install\n\
[SDL2] ./configure $CONFIGURE_PROLOGUE --enable-static --disable-shared \
--disable-atomic --disable-audio --disable-video --disable-render --disable-sensor \
--disable-power --disable-filesystem --disable-threads --disable-timers --disable-file \
--disable-loadso --disable-cpuinfo --disable-assembly $CONFIGURE_FLAGS\n\
[SDL2] make install\n\
[Linux-PAM] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --includedir=/usr/local/include/security --enable-static --disable-shared\n\
[Linux-PAM] make install\n\
[libcap] sed -i 's/.*\\$(MAKE) -C tests \\$@.*//' Makefile\n\
[libcap] sed -i 's/.*\\$(MAKE) -C progs \\$@.*//' Makefile\n\
[libcap] sed -i 's/.*\\$(MAKE) -C doc \\$@.*//' Makefile\n\
[libcap] COPTS=\"-m32 -O2\" lib=lib prefix=/usr/local SHARED=no make install\n\
[libcap-ng] ./autogen.sh\n\
[libcap-ng] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --enable-static --disable-shared --without-python3\n\
[libcap-ng] make install\n\
[util-linux] ./autogen.sh\n\
[util-linux] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --enable-static --disable-shared \
--without-python --disable-fdisks --disable-mount --disable-losetup --disable-zramctl \
--disable-fsck --disable-partx --disable-uuidd --disable-uuidgen --disable-blkid \
--disable-wipefs --disable-mountpoint --disable-fallocate --disable-unshare \
--disable-nsenter --disable-setpriv --disable-hardlink --disable-eject --disable-agetty \
--disable-cramfs --disable-bfs --disable-minix --disable-hwclock --disable-mkfs \
--disable-fstrim --disable-swapon --disable-lscpu --disable-lsfd --disable-lslogins \
--disable-wdctl --disable-cal --disable-logger --disable-whereis --disable-switch_root \
--disable-pivot_root --disable-lsmem --disable-chmem --disable-ipcmk --disable-ipcrm \
--disable-ipcs --disable-irqtop --disable-lsirq --disable-rfkill --disable-scriptutils \
--disable-kill --disable-last --disable-utmpdump --disable-mesg --disable-raw \
--disable-rename --disable-chfn-chsh --disable-login --disable-nologin --disable-sulogin \
--disable-su --disable-runuser --disable-ul --disable-more --disable-setterm \
--disable-schedutils --disable-wall --disable-bash-completion\n\
[util-linux] make install\n\
[systemd] sed -i 's/\\(input : .libudev.pc.in.,\\)/\\1 install_tag: '\"'\"'devel'\"'\"',/' src/libudev/meson.build\n\
[systemd] meson setup build $MESON_PROLOGUE -Drootlibdir=/usr/local/lib -Dstatic-libudev=true\n\
[systemd] cd build\n\
[systemd] meson compile basic:static_library udev:static_library libudev.pc\n\
[systemd] meson install --tags devel --no-rebuild --only-changed\n\
[systemd] rm /usr/local/lib/*.so\n\
[libdrm] meson setup build $MESON_PROLOGUE\n\
[libdrm] meson install -C build\n\
[tdb] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-python\n\
[tdb] make install\n\
[tdb] rm /usr/local/lib/libtdb.so*\n\
-Dshared-glapi=false\n\
[glib] sed -i 's/\\(input : .glibconfig.h.in.,\\)/\\1 install_tag : '\"'\"'devel'\"'\"',/' glib/meson.build\n\
[glib] meson setup build $MESON_PROLOGUE -Dtests=false\n\
[glib] cd build\n\
[glib] meson compile glib-2.0 gio-2.0 gthread-2.0 gmodule-2.0 gobject-2.0\n\
[glib] meson install --tags devel --no-rebuild\n\
[pulseaudio] sed -i 's/\\(input : .PulseAudioConfigVersion.cmake.in.,\\)/\\1 install_tag : '\"'\"'devel'\"'\"',/' meson.build\n\
[pulseaudio] find . -name meson.build -exec sed -i 's/=[[:space:]]*shared_library(/= library(/g' {} \\;\n\
[pulseaudio] meson setup build $MESON_PROLOGUE -Ddaemon=false -Ddoxygen=false \
-Dgcov=false -Dman=false -Dtests=false\n\
[pulseaudio] cd build\n\
[pulseaudio] meson compile pulse-simple \
pulsecommon-\$(echo "\$PWD" | sed 's/.*pulseaudio-\\([0-9]\\{1,\}\\.[0-9]\\{1,\\}\\).*/\\1/') \
pulse-mainloop-glib pulse pulsedsp\n\
[pulseaudio] meson install --tags devel --no-rebuild\n\
[libunwind] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE $CONFIGURE_HOST --enable-static --disable-shared\n\
[libunwind] make install\n\
[mesa] patch -p1 < ../patches/\$(basename \$PWD).patch\n\
[mesa] find -name 'meson.build' -exec sed -i 's/shared_library(/library(/' {} \\;\n\
[mesa] find -name 'meson.build' -exec sed -i 's/name_suffix : .so.,//' {} \\;\n\
[mesa] sed -i 's/extra_libs_libglx = \\[\\]/extra_libs_libglx = \\[libgallium_dri\\]/' src/glx/meson.build\n\
[mesa] sed -i 's/extra_deps_libgl = \\[\\]/extra_deps_libgl = \\[meson.get_compiler('\"'\"'cpp'\"'\"').find_library('\"'\"'stdc++'\"'\"')\\]/' src/glx/meson.build\n\
[mesa] echo '#!/usr/bin/env python3' > bin/install_megadrivers.py\n\
[mesa] echo >> /bin/install_megadrivers.py\n\
[mesa] meson setup build $MESON_PROLOGUE --sysconfdir=/etc \
-Dplatforms=x11 \
-Dgallium-drivers=swrast,i915,iris,crocus \
-Dgallium-vdpau=disabled \
-Dgallium-omx=disabled \
-Dgallium-va=disabled \
-Dgallium-xa=disabled \
-Dvulkan-drivers=\"\" \
-Dshared-glapi=enabled \
-Dgles1=disabled \
-Dgles2=disabled \
-Dglx=dri \
-Dgbm=disabled \
-Degl=disabled \
-Dllvm=disabled \
-Dvalgrind=disabled \
-Dlibunwind=enabled\n\
[mesa] cd build\n\
[mesa] meson compile GL glapi gallium_dri\n\
[mesa] meson install --no-rebuild --only-changed"

ARG DEF_BUILD_SCRIPT="\
ENABLE_STATIC_ARG=\n\
DISABLE_SHARED_ARG=\n\
DISABLE_DOCS_ARG=\n\
./configure --help | grep -q '\-\-enable\-static'\n\
if [ \$? -eq 0 ]; then ENABLE_STATIC_ARG=--enable-static; fi\n\
./configure --help | grep -q '\-\-enable-shared\|\-\-disable\-shared'\n\
if [ \$? -eq 0 ]; then DISABLE_SHARED_ARG=--disable-shared; fi\n\
./configure --help | grep -q '\-\-enable-docs\|\-\-disable\-docs'\n\
if [ \$? -eq 0 ]; then DISABLE_DOCS_ARG=--disable-docs; fi\n\
./configure $CONFIGURE_PROLOGUE \
  \$ENABLE_STATIC_ARG \
  \$DISABLE_SHARED_ARG \
  \$DISABLE_DOCS_ARG \
  $CONFIGURE_FLAGS\n\
ENABLE_STATIC_ARG=\n\
DISABLED_SHARED_ARG=\n\
DISABLE_DOCS_ARG=\n\
make install\n"

# pkg_file         = xcb-proto-1.14.1.tar.gz
# pkg_name         = xcb-proto
# pkg_ver          = 1.14.1
# pkg_dir          = xcb-proto-1.14.1
# pkg_build_script = xcb-proto-1.14.1.sh

RUN mkdir -p build && \
    cd build && \
    (for pkg_file in $(sed 's/.*\///' packages.txt | awk '{print $2 ? $2 : $1}' | tr '\n' ' '); \
     do \
       pkg_name=$(echo "$pkg_file" | sed 's/\(.\+\)-.*/\1/'); \
       pkg_ver=$(echo "$pkg_file" | sed 's/-\([0-9.]\+).tar/\1'); \
       pkg_dir=$(echo "$pkg_file" | sed 's/\.tar\.\(gz\|xz\|bz2\)$//'); \
       pkg_build_script="${pkg_dir}.sh"; \
       tar -xvf "$pkg_file" || exit; \
       { echo -e "$DEP_BUILD_SCRIPT" | grep "^\[$pkg_name\]" | sed "s/^\[$pkg_name\] //" > "$pkg_build_script"; } || exit; \
       if [[ ! -s "$pkg_build_script" ]]; \
       then \
         echo -e "$DEF_BUILD_SCRIPT" > "$pkg_build_script" || exit; \
       fi; \
       pushd "$pkg_dir" && cat "../$pkg_build_script" && . "../$pkg_build_script" && popd || exit; \
     done)
