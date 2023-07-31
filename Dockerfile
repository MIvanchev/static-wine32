FROM ubuntu:20.04

SHELL ["/bin/bash", "-c"]

RUN dpkg --add-architecture i386 && \
    apt update && \
    apt upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y build-essential pkg-config \
        gcc-multilib g++-multilib gcc-mingw-w64 libcrypt1-dev:i386 flex bison \
        python3 python3-pip wget git ninja-build gperf automake \
        autoconf-archive libtool autopoint gettext nasm glslang-tools && \
    pip3 install mako jinja2 && \
    wget -q https://github.com/Kitware/CMake/releases/download/v3.26.3/cmake-3.26.3-linux-x86_64.tar.gz -P $HOME && \
    tar xf $HOME/cmake-*-linux-x86_64.tar.gz -C /usr --strip-components=1 && \
    cmake --version && \
    git clone --depth 1 --branch 1.1.0 https://github.com/mesonbuild/meson.git "$HOME/meson" && \
    echo "#!/bin/sh" > /usr/bin/meson && \
    echo "python3 \"$HOME/meson/meson.py\" \$@" > /usr/bin/meson && \
    chmod +x /usr/bin/meson && meson --version && \
    DEBIAN_FRONTEND=noninteractive apt install -y nano xvfb x11-apps \
        imagemagick && \
    echo "#!/bin/sh" > /usr/bin/startx && \
    echo "Xvfb \"\$DISPLAY\" -screen 0 1200x800x24 &" >> /usr/bin/startx && \
    echo >> /usr/bin/startx && \
    chmod +x /usr/bin/startx

ENV DISPLAY=:1

COPY dependencies /build
COPY meson-cross-i386 /build/

# Set to "native" if building on the machine you're going to run Wine on
# or the value that matches your CPU's architecture from the from the
# possible values of the -march option of GCC. For example "broadwell" for
# the i7-5600u CPU. The values are available on
#
# https://gcc.gnu.org/onlinedocs/gcc/x86-Options.html
#
# or you can find them out by executing:
#
# gcc -E -march=foo -xc /dev/null 2>&1 | sed -n 's/.* valid arguments to .* are: //p' | tr ' ' '\n'
#
ARG PLATFORM=

# Leave empty or comment out to skip LLVM build
ARG BUILD_WITH_LLVM=

# Set to the desired number of parallel build jobs; this should losely
# correspond to the number of CPU cores.
ARG BUILD_JOBS=8

ARG PATH="$PATH:/usr/local/bin"

ARG CONFIGURE_PREFIX="--prefix=/usr/local"
ARG CONFIGURE_FLAGS="CFLAGS=\"-m32 -march=$PLATFORM -mfpmath=sse -O2 -flto -ffat-lto-objects -pipe\" \
                     CPPFLAGS=\"-m32 -march=$PLATFORM -mfpmath=sse -O2 -flto -ffat-lto-objects -pipe\" \
                     CXXFLAGS=\"-m32 -march=$PLATFORM -mfpmath=sse -O2 -flto -ffat-lto-objects -pipe\" \
                     OBJCFLAGS=\"-m32 -march=$PLATFORM -mfpmath=sse -O2 -flto -ffat-lto-objects -pipe\" \
                     LDFLAGS=\"-m32 -march=$PLATFORM -fno-lto\" \
                     AR=\"/usr/bin/gcc-ar\" \
                     RANLIB=\"/usr/bin/gcc-ranlib\" \
                     NM=\"/usr/bin/gcc-nm\""
ARG CONFIGURE_PROLOGUE="$CONFIGURE_PREFIX \
                        --sysconfdir=/etc \
                        --datarootdir=/usr/share \
                        --mandir=/usr/local/man"
ARG CONFIGURE_HOST="--host=i386-linux-gnu"
ARG MESON_PROLOGUE="--prefix=/usr/local \
                    --sysconfdir=/etc \
                    --datadir=/usr/share \
                    --mandir=/usr/local/man \
                    --buildtype=release \
                    --cross-file=../meson-cross-i386 \
                    --default-library=static \
                    --prefer-static"
ARG CMAKE_PROLOGUE="-DCMAKE_INSTALL_PREFIX=/usr/local \
                    -DCMAKE_AR=/usr/bin/gcc-ar \
                    -DCMAKE_RANLIB=/usr/bin/gcc-ranlib \
                    -DCMAKE_NM=gcc-nm \
                    -DSYSCONFDIR=/etc \
                    -DDATAROOTDIR=/usr/share \
                    -DMANDIR=/usr/local/man \
                    -DCMAKE_BUILD_TYPE=Release"

ARG DEP_BUILD_SCRIPTS="\
[macros-util-macros] autoreconf -i\n\
[macros-util-macros] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE\n\
[macros-util-macros] make install\n\
[zlib] $CONFIGURE_FLAGS ./configure $CONFIGURE_PREFIX --static\n\
[zlib] make install\n\
[zstd] mkdir build/cmake/builddir\n\
[zstd] cd build/cmake/builddir\n\
[zstd] $CONFIGURE_FLAGS cmake $CMAKE_PROLOGUE -DZSTD_BUILD_STATIC=ON -DZSTD_BUILD_SHARED=OFF -DZSTD_BUILD_PROGRAMS=OFF -DZSTD_BUILD_TESTS=OFF ..\n\
[zstd] make install\n\
[xz] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --enable-static --disable-shared \
--disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-lzma-links \
--disable-scripts --disable-doc\n\
[xz] make install\n\
[bzip2] sed -i 's/\(CFLAGS.*=.*\)/\\1 -m32/' Makefile\n\
[bzip2] make libbz2.a\n\
[bzip2] cp libbz2.a /usr/local/lib/\n\
[bzip2] cp bzlib.h /usr/local/include/\n\
[elfutils] sed -i 's/^\([ \t]*\)int code;$/\\1int code = 0;/' libdwfl/gzip.c\n\
[elfutils] sed -i 's/^\\(zstd_LIBS=.*\\)\"/\\1 \$(pkg-config --libs --static libzstd)\"/' configure.ac\n\
[elfutils] sed -i 's/^\\(zip_LIBS=.*\\)\"/\\1 \$(pkg-config --libs --static libzstd)\"/' configure.ac\n\
[elfutils] autoreconf -f\n\
[elfutils] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-libdebuginfod --disable-debuginfod\n\
[elfutils] make install\n\
[elfutils] rm /usr/local/lib/libasm*.so* /usr/local/lib/libdw*.so* /usr/local/lib/libelf*.so*\n\
[libjpeg-turbo] $CONFIGURE_FLAGS cmake $CMAKE_PROLOGUE -DENABLE_STATIC=TRUE -DENABLE_SHARED=FALSE -DWITH_TURBOJPEG=FALSE\n\
[libjpeg-turbo] make install\n\
[libexif] autoreconf -i\n\
[libexif] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --enable-static --disable-shared\n\
[libexif] make install\n\
[gmp] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE $CONFIGURE_HOST --libdir=/usr/local/lib --enable-static --disable-shared\n\
[gmp] make install\n\
[nettle] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE $CONFIGURE_HOST --enable-static --disable-shared --disable-assembler\n\
[nettle] make install\n\
[gnutls] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE $CONFIGURE_HOST --enable-static --disable-shared \
--with-included-unistring \
--with-included-libtasn1 \
--without-p11-kit \
--disable-libdane \
--enable-ssl3-support \
--enable-openssl-compatibility \
--host=i386-pc-linux --disable-tools --disable-tests --disable-doc\n\
[gnutls] make install\n\
[libxml2] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE $CONFIGURE_HOST --enable-static --disable-shared \
--without-python\n\
[libxml2] make install\n\
[libxkbcommon] meson setup build $MESON_PROLOGUE \
-Denable-wayland=false \
-Denable-docs=false \
-Denable-tools=false\n\
[libxkbcommon] cd build\n\
[libxkbcommon] meson compile xkbcommon xkbcommon-x11 xkbregistry\n\
[libxkbcommon] meson install --no-rebuild\n\
[fontconfig] ./configure $CONFIGURE_PROLOGUE --enable-static --disable-shared --disable-docs $CONFIGURE_FLAGS\n\
[fontconfig] make install\n\
[SDL] mkdir build\n\
[SDL] cd build\n\
[SDL] $CONFIGURE_FLAGS CFLAGS=\"\$CFLAGS -DSDL_VIDEO_DRIVER_X11_SUPPORTS_GENERIC_EVENTS=1\" cmake $CMAKE_PROLOGUE \
-DLIBTYPE=STATIC -DBUILD_SHARED_LIBS=OFF ..\n\
[SDL] make install\n\
[Linux-PAM] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --includedir=/usr/local/include/security --enable-static --disable-shared\n\
[Linux-PAM] make install\n\
[libcap] sed -i 's/.*\$(MAKE) -C tests \$@.*//' Makefile\n\
[libcap] sed -i 's/.*\$(MAKE) -C progs \$@.*//' Makefile\n\
[libcap] sed -i 's/.*\$(MAKE) -C doc \\\$@.*//' Makefile\n\
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
[systemd] sed -i 's/install : pkgconfiglibdir != .no.,/install : false,/' src/libsystemd/meson.build\n\
[systemd] sed -i 's/install : true,/install : false,/' meson.build\n\
[systemd] meson setup build $MESON_PROLOGUE -Drootlibdir=/usr/local/lib -Dstatic-libudev=true\n\
[systemd] cd build\n\
[systemd] meson compile basic:static_library udev:static_library systemd:static_library libudev.pc udev.pc systemd.pc\n\
[systemd] meson install --tags devel,libudev --no-rebuild\n\
[systemd] PC_FILE=/usr/local/lib/pkgconfig/libudev.pc\n\
[systemd] [ -f \$PC_FILE ] && echo 'Requires.private: libcap' >> \$PC_FILE\n\
[libdrm] meson setup build $MESON_PROLOGUE\n\
[libdrm] meson install -C build\n\
[tdb] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-python\n\
[tdb] make install\n\
[tdb] rm /usr/local/lib/libtdb*.so*\n\
[glib] meson setup build $MESON_PROLOGUE -Dtests=false\n\
[glib] ninja -C build install\n\
[libusb] sed -i 's/\\[udev_new\\], \\[\\], \\[\\(.*\\)\\]/[udev_new], [], [\\1], [\\$(pkg-config --libs --static libudev)]/' configure.ac\n\
[libusb] autoreconf -i\n\
[libusb] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE $CONFIGURE_HOST --enable-static --disable-shared\n\
[libusb] make install\n\
[libusb] PC_FILE=/usr/local/lib/pkgconfig/libusb-1.0.pc\n\
[libusb] [ -f \$PC_FILE ] && sed -i 's/-ludev//' \$PC_FILE\n\
[libusb] [ -f \$PC_FILE ] && echo 'Requires.private: libudev' >> \$PC_FILE\n\
[libusb] pkg-config --libs --static libusb-1.0\n\
[pcsc-lite] $CONFIGURE_FLAGS LIBUDEV_LIBS=`pkg-config --libs --static libudev` ./configure $CONFIGURE_PROLOGUE --enable-static --disable-shared --disable-libsystemd\n\
[pcsc-lite] make install\n\
[pulseaudio] sed -i 's/\\(input : .PulseAudioConfigVersion.cmake.in.,\\)/\\1 install_tag : '\"'\"'devel'\"'\"',/' meson.build\n\
[pulseaudio] find . -name meson.build -exec sed -i 's/=[[:space:]]*shared_library(/= library(/g' {} \\;\n\
[pulseaudio] meson setup build $MESON_PROLOGUE -Ddaemon=false -Ddoxygen=false \
-Dgcov=false -Dman=false -Dtests=false\n\
[pulseaudio] cd build\n\
[pulseaudio] meson compile pulse-simple \
pulsecommon-`echo "\$PWD" | sed 's/.*pulseaudio-\\([0-9]\\{1,\}\\.[0-9]\\{1,\\}\\).*/\\1/'` \
pulse-mainloop-glib pulse pulsedsp\n\
[pulseaudio] meson install --tags devel --no-rebuild\n\
[pulseaudio] PC_FILE=/usr/local/lib/pkgconfig/libpulse.pc\n\
[pulseaudio] [ -f \$PC_FILE ] && sed -i 's/Libs\\.private:\\(.*\\)/Libs.private:\\1 -ldl -lm -lrt/' \$PC_FILE\n\
[pulseaudio] [ -f \$PC_FILE ] && echo 'Requires.private: dbus-1' >> \$PC_FILE\n\
[pulseaudio] pkg-config --libs --static libpulse\n\
[alsa-lib] patch -p1 < ../patches/`basename \$PWD`.patch\n\
[alsa-lib] autoreconf -i\n\
[alsa-lib] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[alsa-lib] make install\n\
[alsa-plugins] patch -p1 < ../patches/`basename \$PWD`.patch\n\
[alsa-plugins] autoreconf -i\n\
[alsa-plugins] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[alsa-plugins] make install\n\
[alsa-plugins] PC_FILE=/usr/local/lib/pkgconfig/alsa.pc\n\
[alsa-plugins] [ -f \$PC_FILE ] && echo 'Requires.private: libpulse' >> \$PC_FILE\n\
[alsa-plugins] [ -f \$PC_FILE ] && sed -i 's/Libs\\.private: \\(.*\\)/Libs.private: \
-L\${libdir}\\/alsa-lib -lasound_module_conf_pulse -lasound_module_pcm_pulse \
-lasound_module_ctl_arcam_av -lasound_module_pcm_upmix -lasound_module_ctl_oss \
-lasound_module_pcm_usb_stream -lasound_module_ctl_pulse -lasound_module_pcm_vdownmix \
-lasound_module_rate_speexrate -lasound_module_pcm_oss \\1/' \$PC_FILE\n\
[alsa-plugins] pkg-config --libs --static alsa\n\
[libunwind] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE $CONFIGURE_HOST --enable-static --disable-shared\n\
[libunwind] make install\n\
[llvmorg] ${BUILD_WITH_LLVM:+echo} return\n\
[llvmorg] cmake $CMAKE_PROLOGUE -S llvm -B build \
-DLLVM_BUILD_SHARED_LIBS=OFF \
-DLLVM_TARGETS_TO_BUILD=\"X86;AMDGPU\" \
-DLLVM_BUILD_32_BITS=ON \
-DLLVM_BUILD_TOOLS=ON \
-DLLVM_ENABLE_RTTI=ON\n\
[llvmorg] cd build\n\
[llvmorg] make install\n\
[llvmorg] rm /usr/local/lib/libRemarks.so* /usr/local/lib/libLTO.so*\n\
[llvmorg] sed -i 's/#llvm-config =/llvm-config =/' ../../meson-cross-i386\n\
[mesa] patch -p1 < ../patches/`basename \$PWD`.patch\n\
[mesa] find -name 'meson.build' -exec sed -i 's/shared_library(/library(/' {} \\;\n\
[mesa] find -name 'meson.build' -exec sed -i 's/name_suffix : .so.,//' {} \\;\n\
[mesa] find src/intel/vulkan_hasvk \\( -name '*.c' -o -name '*.h' \\) -exec perl -pi.bak -e 's/(?<!\")(anv|doom64)_/\\1_hasvk_/g' {} \\;\n\
[mesa] echo '#!/usr/bin/env python3' > bin/install_megadrivers.py\n\
[mesa] echo >> /bin/install_megadrivers.py\n\
[mesa] meson setup build $MESON_PROLOGUE \
-Dplatforms=x11 \
-Ddri3=enabled \
-Dgallium-drivers=swrast,zink,i915,iris,crocus,nouveau,r300,r600${BUILD_WITH_LLVM:+,radeonsi} \
-Dgallium-vdpau=disabled \
-Dgallium-omx=disabled \
-Dgallium-va=disabled \
-Dgallium-xa=disabled \
-Dvulkan-drivers=intel,intel_hasvk,amd${BUILD_WITH_LLVM:+,swrast} \
-Dvulkan-icd-dir=/usr/local/share/vulkan/icd.d \
-Dshared-glapi=enabled \
-Dgles1=disabled \
-Dgles2=disabled \
-Dglx=dri \
-Dgbm=enabled \
-Degl=disabled \
-Dllvm=disabled \
${BUILD_WITH_LLVM:+-Dllvm=enabled} \
-Dshared-llvm=disabled \
-Dlibunwind=enabled \
-Dosmesa=true\n\
[mesa] cd build\n\
[mesa] meson compile OSMesa GL glapi gallium_dri vulkan_util vulkan_runtime \
vulkan_wsi radeon_icd vulkan_radeon intel_icd vulkan_intel intel_hasvk_icd \
vulkan_intel_hasvk ${BUILD_WITH_LLVM:+lvp_icd vulkan_lvp} gbm\n\
[mesa] meson install --no-rebuild\n\
[mesa] PC_FILE=/usr/local/lib/pkgconfig/gl.pc\n\
[mesa] [ -f \$PC_FILE ] && { grep -q 'Libs\\.private:' \$PC_FILE || \
echo 'Libs.private:' >> \$PC_FILE; }\n\
[mesa] [ -f \$PC_FILE ] && sed -i 's/Libs\\.private:\\(.*\\)/Libs.private:\
\\1 -lvulkan/' \$PC_FILE\n\
[mesa] pkg-config --libs --static gl\n\
[Vulkan-Headers] $CONFIGURE_FLAGS cmake $CMAKE_PROLOGUE -B build .\n\
[Vulkan-Headers] make -C build install\n\
[Vulkan-Loader] patch -p1 < ../patches/`basename \$PWD`.patch\n\
[Vulkan-Loader] $CONFIGURE_FLAGS cmake $CMAKE_PROLOGUE -DBUILD_STATIC_LOADER=ON -B build .\n\
[Vulkan-Loader] make -C build install\n\
[Vulkan-Loader] PC_FILE=/usr/local/lib/pkgconfig/vulkan.pc\n\
[Vulkan-Loader] [ -f \$PC_FILE ] && echo 'Requires.private: gl libudev' >> \$PC_FILE\n\
[Vulkan-Loader] [ -f \$PC_FILE ] && echo 'Libs.private: -Wl,--whole-archive \
-lvulkan_radeon -lvulkan_intel -lvulkan_intel_hasvk' ${BUILD_WITH_LLVM:+-lvulkan_lvp} \
'-lvulkan_runtime -lvulkan_util -lvulkan_wsi -Wl,--no-whole-archive \
-ldrm_amdgpu' >> \$PC_FILE\n\
[vkcube] meson setup build $MESON_PROLOGUE\n\
[vkcube] meson compile -C build\n\
[vkcube] cp build/vkcube /usr/local/bin/\n\
[mesa-demos] $CONFIGURE_FLAGS eval gcc \\\$CFLAGS -c -o src/xdemos/glxgears.o src/xdemos/glxgears.c\n\
[mesa-demos] $CONFIGURE_FLAGS eval gcc \\\$LDFLAGS -o /usr/local/bin/glxgears src/xdemos/glxgears.o \$(pkg-config --libs --static vulkan)\n\
[ogg] ./autogen.sh\n\
[ogg] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[ogg] make install\n\
[vorbis] ./autogen.sh\n\
[vorbis] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[vorbis] make install\n\
[flac] ./autogen.sh\n\
[flac] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[flac] make install\n\
[libsndfile] sed -i '/AC_SUBST(EXTERNAL_MPEG_REQUIRE)/ a AC_SUBST(EXTERNAL_MPEG_LIBS)' configure.ac\n\
[libsndfile] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[libsndfile] make install\n\
[cups] LIBS=`pkg-config --libs --static gnutls` $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --libdir=/usr/local/lib --disable-shared --enable-static \
--with-components=libcups\n\
[cups] make install\n\
[v4l-utils] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static --disable-v4l-utils\n\
[v4l-utils] make install\n\
[openh264] echo > codec/console/enc/meson.build\n\
[openh264] meson setup build $MESON_PROLOGUE -Dtests=disabled\n\
[openh264] ninja -C build install\n\
[gstreamer] sed -i 's/^\\(float step_size\\[8\\] = {\\)$/static \\1/' subprojects/gst-plugins-bad/gst/siren/common.c\n\
[gstreamer] sed -i 's/^\\(extern float step_size\\[8\\];\\)$/\/\/\\1/' subprojects/gst-plugins-bad/gst/siren/common.h\n\
[gstreamer] sed -i 's/= *both_libraries(/= static_library(/' meson.build\n\
[gstreamer] sed -i 's/link_with: gstfull.get_shared_lib()/link_whole: gstfull/' meson.build\n\
[gstreamer] meson setup build $MESON_PROLOGUE \
-Dgst-plugins-base:gl=disabled \
-Dgst-plugins-base:x11=disabled  \
-Dgst-plugins-bad:x11=disabled \
-Dgst-plugins-bad:codectimestamper=disabled \
-Dgst-plugins-good:ximagesrc=disabled \
-Dtools=disabled \
-Ddevtools=disabled \
-Dgst-examples=disabled \
-Dtests=disabled \
-Dexamples=disabled \
-Dintrospection=disabled \
-Ddoc=disabled \
-Dgtk_doc=disabled\n\
[gstreamer] ninja -C build install\n\
[gstreamer] rm /usr/local/lib/liborc*.so*\n\
[gstreamer] echo \"export PKG_CONFIG_PATH=/usr/local/lib/gstreamer-1.0/pkgconfig\" >> ~/.bashrc\n\
[libpcap] $CONFIGURE_FLAGS DBUS_LIBS=\"`pkg-config --libs --static dbus-1`\" ./configure --prefix=/usr/local --disable-shared\n\
[libpcap] make install\n\
[isdn4k-utils] pushd capi20\n\
[isdn4k-utils] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[isdn4k-utils] make install-libLTLIBRARIES install-pcDATA install-includeHEADERS\n\
[isdn4k-utils] popd\n\
[isdn4k-utils] PC_FILE=/usr/local/lib/pkgconfig/capi20.pc\n\
[isdn4k-utils] [ -f \$PC_FILE ] && echo 'Libs.private: -ldl -lrt -lpthread' >> \$PC_FILE\n\
[isdn4k-utils] pkg-config --libs --static capi20\n\
[tiff] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[tiff] sed -i 's/SUBDIRS = port libtiff tools build contrib test doc/SUBDIRS = port libtiff build test doc/' Makefile\n\
[tiff] make install\n\
[ieee1284] ./bootstrap\n\
[ieee1284] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static --without-python\n\
[ieee1284] make install-includeHEADERS install-libLTLIBRARIES\n\
[sane-backends] patch -p1 < ../patches/`basename \$PWD`.patch\n\
[sane-backends] autoreconf -i\n\
[sane-backends] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static --enable-dynamic --enable-preload\n\
[sane-backends] make install\n\
[sane-backends] pushd tools\n\
[sane-backends] make install-pkgconfigDATA install-binSCRIPTS\n\
[sane-backends] popd\n\
[openldap] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static --disable-debug --disable-slapd\n\
[openldap] make install\n\
[krb5] cd src\n\
[krb5] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[krb5] make && make install\n\
[krb5] PC_FILE=/usr/local/lib/pkgconfig/mit-krb5.pc\n\
[krb5] [ -f \$PC_FILE ] && sed -i 's/Libs\\.private:\\(.*\\)/Libs.private:\\1 -ldl -lresolv/' \$PC_FILE\n\
[krb5] pkg-config --libs --static krb5\n\
[krb5] PC_FILE=/usr/local/lib/pkgconfig/mit-krb5-gssapi.pc\n\
[krb5] [ -f \$PC_FILE ] && echo 'Libs.private: -ldl -lresolv' >> \$PC_FILE\n\
[krb5] pkg-config --libs --static krb5-gssapi"

ARG DEFAULT_BUILD_SCRIPT="\
#!/bin/sh\n\
set -e\n\
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
unset ENABLE_STATIC_ARG\n\
unset DISABLED_SHARED_ARG\n\
unset DISABLE_DOCS_ARG\n\
make install\n"

# pkg_file         = xcb-proto-1.14.1.tar.gz
# pkg_name         = xcb-proto
# pkg_dir          = xcb-proto-1.14.1
# pkg_build_script = xcb-proto-1.14.1.sh

RUN if [[ -z "$PLATFORM" ]]; then \
        echo "You must set the PLATFORM variable in Dockerfile before building the image." 1>&2; \
        echo "See https://gcc.gnu.org/onlinedocs/gcc/x86-Options.html for a list of the" 1>&2; \
        echo "allowed values and pick the one that matches your CPU's architecture." 1>&2; \
        false; \
    fi && \
    gcc -E -march=$PLATFORM -xc /dev/null >/dev/null && \
    sed -i "s/{PLATFORM}/$PLATFORM/g" /build/meson-cross-i386 && \
    export MAKEFLAGS=-j$BUILD_JOBS && \
    export NINJAFLAGS=-j$BUILD_JOBS && \
    mkdir -p build && \
    cd build && \
    # The packages.txt files contains 1 line for every dependency to build.
    # Each line is in one of the following formats:
    #
    # 1. <URL>
    # 2. <URL> <file name>
    # 3. <URL ending on .git> <branch name> <directory name>
    #
    # In the first case, the package name is derived from the URL, in cases
    # where it's not possible, the file name of the package is given directly.
    # For git repositories, the package name is derived from the directory
    # name by appending .tar.gz.
    #
    (for pkg_file in `sed 's/.*\///' packages.txt | awk '{print $3 ? ($3 ".tar.gz") : ($2 ? $2 : $1)}' | tr '\n' ' '`; \
     do \
       pkg_name=`echo "$pkg_file" | sed 's/\(.\{1,\}\)-[0-9]\{1,\}\(\.[0-9]\{1,\}\)*.*/\1/'`; \
       pkg_dir=`echo "$pkg_file" | sed -e 's/\.tar\.\(gz\|xz\|bz2\)$//' -e 's/\.tgz$//'`; \
       pkg_build_script="${pkg_dir}.sh"; \
       echo "pkg_name:         $pkg_name"; \
       echo "pkg_dir:          $pkg_dir"; \
       echo "pkg_build_script: $pkg_build_script"; \
       echo "Build script contents:"; \
       tar -xf "$pkg_file" || exit; \
       { echo -e "$DEP_BUILD_SCRIPTS" | grep "^\[$pkg_name\]" | sed "s/^\[$pkg_name\] //" > "$pkg_build_script"; } || exit; \
       if [ ! -s "$pkg_build_script" ]; \
       then \
         echo -e "$DEFAULT_BUILD_SCRIPT" > "$pkg_build_script" || exit; \
       else \
         echo -e "#!/bin/sh\nset -e\n`cat $pkg_build_script`" > "$pkg_build_script" || exit; \
       fi; \
       pushd "$pkg_dir" && cat "../$pkg_build_script" \
         && . "../$pkg_build_script" && set +e && popd \
         && rm -rf "$pkg_dir"  || exit; \
     done)

# wine recently modified configure.ac to use PKG_CONFIG_LIBDIR instead of
# PKG_CONFIG_PATH and something broke so this is now required before
# building wine, see:
#
# https://github.com/wine-mirror/wine/commit/c7a97b5d5d56ef00a0061b75412c6e0e489fdc99
#

ENV PKG_CONFIG_LIBDIR=/usr/lib/i386-linux-gnu/pkgconfig:/usr/lib32/pkgconfig:/usr/local/lib/pkgconfig:/usr/share/pkgconfig
