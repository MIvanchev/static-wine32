FROM ubuntu:22.04

SHELL ["/bin/bash", "-c"]

# (required) Set to "native" if building on the machine you're going to run
# Wine on  or the value that matches your CPU's architecture from the from
# the possible values of the -march option of GCC. For example "broadwell"
# for the i7-5600u CPU. The values are available on
#
# https://gcc.gnu.org/onlinedocs/gcc/x86-Options.html
#
# or you can find them out by executing:
#
# gcc -E -march=foo -xc /dev/null 2>&1 | sed -n 's/.* valid arguments to .* are: //p' | tr ' ' '\n'
#
ARG PLATFORM=

# (required) Set to Wine's installation directory on your machine,
# e.g. $HOME/.local.
ARG PREFIX=

# (optional) Set to "y" to enable or something else to disable link time
# optimizations.
ARG BUILD_WITH_LTO=y

# (optional) Set to the desired number of parallel build jobs; this should
# losely correspond to the number of CPU cores.
ARG BUILD_JOBS=8

# Do NOT set these as this would make your life rather difficult.

ARG PATH="$PATH:/usr/local/bin"

ARG DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 && \
    apt update && \
    apt upgrade -y && \
    apt-get install -y build-essential \
        gcc-multilib g++-multilib gcc-mingw-w64 libcrypt1-dev:i386 flex bison \
        rustc bindgen python3 python3-pip python3-dev python3-mako python3-jinja2 \
        python3-packaging python3-yaml wget git ninja-build gperf autopoint gettext nasm \
        glslang-tools xmlto fop xsltproc doxygen asciidoc gtk-doc-tools docbook2x rsync && \
    pip3 install jinja2-cli

RUN pushd "$HOME" && \
    apt-get -y remove autoconf autoconf-archive automake pkg-config cmake meson && \
    apt-get -y autoremove && \
    wget -q http://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.xz && \
    tar xf autoconf-*.tar.* && \
    pushd autoconf-*/ && ./configure --prefix=/usr && make install && popd && rm -rf autoconf-* && \
    wget -q http://ftp-stud.hs-esslingen.de/pub/Mirrors/ftp.gnu.org/autoconf-archive/autoconf-archive-2024.10.16.tar.xz && \
    tar xf autoconf-archive-*.tar.* && \
    pushd autoconf-archive-*/ && ./configure --prefix=/usr && make install && popd && rm -rf autoconf-archive-* && \
    wget -q https://ftp.gnu.org/gnu/automake/automake-1.17.tar.xz && \
    tar xf automake-*.tar.* && \
    pushd automake-*/ && ./configure --prefix=/usr && make install && popd && rm -rf automake-* && \
    wget -q https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz && \
    tar xf pkg-config-*.tar.* && \
    pushd pkg-config-*/ && ./configure -prefix=/usr --with-internal-glib && make install && popd && rm -rf pkg-config-* && \
    wget -q https://mirror.checkdomain.de/gnu/libtool/libtool-2.5.4.tar.xz && \
    tar xf libtool-*.tar.* && \
    pushd libtool-*/ && ./configure --prefix=/usr && make install && popd && rm -rf libtool-* && \
    wget -q https://github.com/Kitware/CMake/releases/download/v3.31.5/cmake-3.31.5-linux-x86_64.tar.gz && \
    tar xf cmake-*-linux-x86_64.tar.gz -C /usr --strip-components=1 && \
    rm -rf cmake-* && apt-get -y remove cmake && \
    git clone --depth 1 --branch 1.7.0 https://github.com/mesonbuild/meson.git && \
    sed -i 's/^.*remove_dups()/# &/' meson/mesonbuild/modules/pkgconfig.py && \
    echo "#!/bin/sh" > /usr/bin/meson && \
    echo "python3 \"$HOME/meson/meson.py\" \$@" > /usr/bin/meson && \
    chmod +x /usr/bin/meson && \
    apt-get -y remove meson && \
    popd

RUN apt-get install -y nano xvfb x11-apps imagemagick && \
    echo "#!/bin/sh" > /usr/bin/startx && \
    echo "Xvfb \"\$DISPLAY\" -screen 0 1200x800x24 &" >> /usr/bin/startx && \
    echo >> /usr/bin/startx && \
    chmod +x /usr/bin/startx

ENV DISPLAY=:1

COPY cache /cache
COPY dependencies /build

#RUN build/checkvers.sh && build/download.sh
RUN build/download.sh

ARG COMPILE_FLAGS="-m32 -march=$PLATFORM -mfpmath=sse -O2 -flto -ffat-lto-objects -pipe"
ARG LINK_FLAGS="-m32 -march=$PLATFORM -fno-lto"

# wine recently modified configure.ac to use PKG_CONFIG_LIBDIR instead of
# PKG_CONFIG_PATH and something broke so this is now required before
# building wine, see:
#
# https://github.com/wine-mirror/wine/commit/c7a97b5d5d56ef00a0061b75412c6e0e489fdc99
#

ENV PKG_CONFIG_LIBDIR=/usr/lib/i386-linux-gnu/pkgconfig:/usr/lib32/pkgconfig:/usr/local/lib/pkgconfig:/usr/share/pkgconfig:/usr/local/share/pkgconfig

ARG DEP_BUILD_SCRIPTS="\
[libiconv] build_autoconf\n\
[libiconv] cat /usr/local/lib/pkgconfig/iconv.pc\n\
[libiconv-post] cp /usr/local/lib/pkgconfig/iconv.pc /usr/local/lib/pkgconfig/iconv-meson.pc\n\
[macros-util-macros] build_autoconf --reconf\n\
[zlib] CONFIGURE_OPTS=\"--prefix=/usr/local --static\" build_autoconf --no-auto-feature\n\
[zstd] cd build/cmake\n\
[zstd] CMAKE_OPTS+=\" -DZSTD_BUILD_STATIC=ON -DZSTD_BUILD_SHARED=OFF -DZSTD_BUILD_PROGRAMS=OFF -DZSTD_BUILD_TESTS=OFF\" build_cmake\n\
[xz] CONFIGURE_OPTS+=\" --disable-xz --disable-xzdec \
--disable-lzmadec --disable-lzmainfo --disable-lzma-links \
--disable-scripts\" build_autoconf --reconf\n\
[bzip2] sed -i 's/\(CFLAGS.*=.*\)/\\1 -m32/' Makefile\n\
[bzip2] make libbz2.a\n\
[bzip2] cp libbz2.a /usr/local/lib/\n\
[bzip2] cp bzlib.h /usr/local/include/\n\
[elfutils] CONFIGURE_OPTS+=\" --disable-libdebuginfod --disable-debuginfod\" build_autoconf --reconf\n\
[elfutils-post] rm /usr/local/lib/libasm*.so* /usr/local/lib/libdw*.so* /usr/local/lib/libelf*.so*\n\
[libjpeg-turbo] CMAKE_OPTS+=\" -DENABLE_STATIC=TRUE -DENABLE_SHARED=FALSE -DWITH_TURBOJPEG=FALSE\" build_cmake\n\
[libexif] build_autoconf --reconf\n\
[gmp] CONFIGURE_OPTS+=\" --libdir=/usr/local/lib\" build_autoconf\n\
[nettle] CONFIGURE_OPTS+=\" --disable-assembler\" build_autoconf\n\
[gnutls] CONFIGURE_OPTS+=\" --with-included-unistring \
--with-included-libtasn1 \
--without-p11-kit \
--disable-libdane \
--enable-ssl3-support \
--enable-openssl-compatibility \
--disable-tools\" build_autoconf\n\
[libxml2] build_autoconf --reconf\n\
[wayland-protocols] MESON_OPTS+=\" --datadir=/usr/local/share -Dtests=false\" build_meson\n\
[wayland] MESON_OPTS+=\" -Dtests=false -Ddocumentation=false -Ddtd_validation=false\" build_meson\n\
[libxkbcommon] MESON_OPTS+=\" -Denable-docs=false -Denable-tools=false\" \
MESON_COMPILE_TARGETS=\"xkbcommon xkbcommon-x11 xkbregistry\" build_meson\n\
[dbus] MESON_OPTS+=\" -Dmodular_tests=disabled -Dtools=false -Ddoxygen_docs=disabled  -Dducktype_docs=disabled  -Dxml_docs=disabled\" build_meson\n\
[SDL] CMAKE_OPTS+=\" -DSDL_VIDEO_DRIVER_X11_SUPPORTS_GENERIC_EVENTS=1 -DLIBTYPE=STATIC -DBUILD_SHARED_LIBS=OFF\" build_cmake\n\
[Linux-PAM] echo CONFIGURE_OPTS+=\" --includedir=/usr/local/include/security\" build_autoconf\n\
[Linux-PAM] build_meson\n\
[Linux-PAM-post] patch_pc_file pam.pc 's/^\\(Libs:.*\\)/\\1 -ldl/'\n\
[libcap] patch_file Makefile 's/.*\$(MAKE) -C \(tests\|progs\|doc\) \$@.*//'\n\
[libcap] COPTS=\"-m32 -O2\" lib=lib prefix=/usr/local SHARED=no make install\n\
[libcap-ng] ./autogen.sh && build_autoconf\n\
[util-linux] ./autogen.sh && CONFIGURE_OPTS+=\" --disable-year2038 \
--disable-fdisks --disable-mount --disable-losetup --disable-zramctl \
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
--disable-schedutils --disable-wall --disable-bash-completion --disable-liblastlog2\" \
build_autoconf\n\
[systemd] patch_file src/libsystemd/meson.build 's/install : pkgconfiglibdir != .no.,/install : false,/'\n\
[systemd] patch_file meson.build 's/install : true,/install : false,/'\n\
[systemd] MESON_OPTS+=\" -Drootlibdir=/usr/local/lib -Dstatic-libudev=true\" \
MESON_COMPILE_TARGETS=\"basic:static_library udev:static_library systemd:static_library libudev.pc udev.pc systemd.pc\" \
MESON_INSTALL_OPTS=\"--tags devel,libudev\" build_meson\n\
[systemd-post] add_pc_file_section libudev.pc 'Requires.private' 'libcap'\n\
[libpciaccess] build_meson\n\
[libdrm] MESON_OPTS+=\" -Dintel=enabled -Dradeon=enabled -Damdgpu=enabled -Dnouveau=enabled\" build_meson\n\
[tdb] CONFIGURE_OPTS+=\" --disable-python\" build_autoconf\n\
[tdb-post] rm /usr/local/lib/libtdb*.so*\n\
[glib] patch_file meson.build \"s/dependency('iconv'/dependency('iconv-meson'/\"\n\
[glib] MESON_OPTS+=\" -Dtests=false\" build_meson\n\
[libusb] patch_file configure.ac 's/\\[udev_new\\], \\[\\], \\[\\(.*\\)\\]/[udev_new], [], [\\1], [\\$(pkg-config --libs --static libudev)]/'\n\
[libusb] build_autoconf --reconf\n\
[libusb-post] patch_pc_file libusb-1.0.pc 's/-ludev//'\n\
[libusb-post] add_pc_file_section libusb-1.0.pc 'Requires.private' 'libudev'\n\
[polkit] MESON_OPTS+=\" -Dlibs-only=true -Dintrospection=false\" build_meson\n\
[pcsc-lite] MESON_OPTS+=\" -Dlibsystemd=false\" build_meson\n\
[pulseaudio] patch_file meson.build 's/\\(input : .PulseAudioConfigVersion.cmake.in.,\\)/\\1 install_tag : '\"'\"'devel'\"'\"',/'\n\
[pulseaudio] find . -name meson.build -exec sed -i 's/=[[:space:]]*shared_library(/= library(/g' {} \\;\n\
[pulseaudio] MESON_OPTS+=\" -Ddaemon=false -Ddoxygen=false -Dgcov=false -Dman=false -Dtests=false\" \
MESON_COMPILE_TARGETS=\"pulse-simple pulsecommon-\${PWD##*-} pulse-mainloop-glib pulse pulsedsp\" \
MESON_INSTALL_OPTS=\"--tags devel\" build_meson\n\
[pulseaudio-post] patch_pc_file libpulse.pc 's/Libs\\.private:\\(.*\\)/Libs.private:\\1 -ldl -lm -lrt/'\n\
[pulseaudio-post] add_pc_file_section libpulse.pc 'Requires.private' 'dbus-1 iconv'\n\
[libgphoto2] LIBLTDL=\"-lltdl -ldl\" build_autoconf --reconf\n\
[alsa-lib] build_autoconf --reconf\n\
[alsa-plugins] build_autoconf --reconf\n\
[alsa-plugins-post] add_pc_file_section alsa.pc 'Requires.private' 'libpulse'\n\
[alsa-plugins-post] patch_pc_file alsa.pc 's/Libs\\.private: \\(.*\\)/Libs.private: \
-L\${libdir}\\/alsa-lib -lasound_module_conf_pulse -lasound_module_pcm_pulse \
-lasound_module_ctl_arcam_av -lasound_module_pcm_upmix -lasound_module_ctl_oss \
-lasound_module_pcm_usb_stream -lasound_module_ctl_pulse -lasound_module_pcm_vdownmix \
-lasound_module_rate_speexrate -lasound_module_pcm_oss \\1/'\n\
[llvmorg]  CMAKE_SOURCE_PATH=llvm CMAKE_OPTS+=' \
  -DLLVM_ENABLE_PROJECTS=clang;clang-tools-extra \
  -DLLVM_BUILD_SHARED_LIBS=OFF \
  -DLLVM_TARGETS_TO_BUILD=X86;AMDGPU \
  -DLLVM_BUILD_32_BITS=ON \
  -DLLVM_BUILD_TOOLS=ON \
  -DLLVM_ENABLE_RTTI=ON' \
  build_cmake\n\
[llvmorg] echo exit\n\
[llvmorg-post] sed -i 's/#llvm-config =/llvm-config =/' /build/meson-cross-i386\n\
[llvmorg-libclc] CMAKE_SOURCE_PATH=libclc build_cmake\n\
[llvmorg-libclc] make -C build install\n\
[spirv-headers] build_cmake\n\
[spirv-tools] CMAKE_OPTS+=\" -DSPIRV-Headers_SOURCE_DIR=/usr/local\" build_cmake\n\
[spirv-tools-post] add_pc_file_section SPIRV-Tools.pc 'Libs.private' '-lstdc++'\n\
[llvm-spirv] CMAKE_OPTS+=\" -DSPIRV-Headers_SOURCE_DIR=/usr/local\" build_cmake\n\
[mesa] find -name 'meson.build' -exec sed -i 's/\\(shared\\|static\\)_library(/library(/' {} \\;\n\
[mesa] find -name 'meson.build' -exec sed -i 's/name_suffix : .so.,//' {} \\;\n\
[mesa] find src/intel/vulkan_hasvk \\( -name '*.c' -o -name '*.h' \\) -exec perl -pi.bak -e 's/(?<!\")(anv|doom64)_/\\1_hasvk_/g' {} \\;\n\
[mesa] MESON_OPTS+=\" -Dplatforms=x11 \
-Dunversion-libgallium=true \
-Dgallium-drivers=swrast,zink,i915,iris,crocus,nouveau,r300,r600,radeonsi \
-Dgallium-vdpau=disabled \
-Dgallium-va=disabled \
-Dgallium-xa=disabled \
-Dgallium-nine=true \
-Dvulkan-drivers=intel,intel_hasvk,amd,swrast \
-Dvulkan-icd-dir=/usr/local/share/vulkan/icd.d \
-Dshared-glapi=enabled \
-Dgles1=disabled \
-Dgles2=disabled \
-Dglx=dri \
-Dgbm=enabled \
-Degl=enabled \
-Dshared-llvm=disabled \
-Dlibunwind=enabled \
-Dstatic-libclc=all \
-Dosmesa=true\" \
MESON_COMPILE_TARGETS=\"OSMesa GL EGL glapi gallium_dri dri_gbm \
mesa_util mesa_util_c11 xmlconfig \
compiler nir blake3 glsl vtn \
blorp blorp_elk intel_decoder intel_decoder_brw intel_decoder_elk \
vulkan_util vulkan_lite_runtime vulkan_instance vulkan_runtime vulkan_wsi \
radeon_icd vulkan_radeon \
intel_icd vulkan_intel \
intel_hasvk_icd vulkan_intel_hasvk \
lvp_icd vulkan_lvp \
d3dadapter9 gbm\" build_meson\n\
[mesa-post] patch_pc_file gl.pc 's/Libs\\.private:\\(.*\\)/Libs.private:\\1 -lvulkan/'\n\
[mesa-post] patch_pc_file egl.pc 's/Libs\\.private:\\(.*\\)/Libs.private:\\1 -lvulkan/'\n\
[glu] MESON_OPTS+=\" -Dgl_provider=gl\" build_meson\n\
[Vulkan-Headers] build_cmake\n\
[Vulkan-Loader] CMAKE_OPTS+=\" -DAPPLE_STATIC_LOADER=ON\" build_cmake\n\
[Vulkan-Loader-post] add_pc_file_section vulkan.pc 'Requires.private' 'gl libudev'\n\
[Vulkan-Loader-post] add_pc_file_section vulkan.pc 'Libs.private' '-Wl,--whole-archive \
-lvulkan_radeon -lvulkan_intel -lvulkan_intel_hasvk -lvulkan_lvp \
-lvulkan_runtime -lvulkan_lite_runtime -lvulkan_instance \
-lvulkan_util -lvulkan_wsi -Wl,--no-whole-archive \
-ldrm_amdgpu'\n\
[vkcube] build_meson --no-install\n\
[vkcube] cp build/vkcube /usr/local/bin/\n\
[mesa-demos] gcc \$CFLAGS -c -o src/xdemos/glxgears.o src/xdemos/glxgears.c\n\
[mesa-demos] gcc \$CFLAGS -Isrc/util -c -o src/egl/opengl/xeglgears.o src/egl/opengl/xeglgears.c\n\
[mesa-demos] gcc \$LDFLAGS -o /usr/local/bin/glxgears src/xdemos/glxgears.o \$(pkg-config --libs --static vulkan)\n\
[mesa-demos] gcc \$LDFLAGS -o /usr/local/bin/xeglgears src/egl/opengl/xeglgears.o \$(pkg-config --libs --static vulkan)\n\
[ogg] ./autogen.sh && build_autoconf\n\
[vorbis] ./autogen.sh && build_autoconf\n\
[flac] ./autogen.sh && build_autoconf\n\
[libsndfile] echo patch_file configure.ac '/AC_SUBST(EXTERNAL_MPEG_REQUIRE)/ a AC_SUBST(EXTERNAL_MPEG_LIBS)'\n\
[libsndfile] build_autoconf\n\
[cups] LIBS=`pkg-config --libs --static gnutls` CONFIGURE_OPTS+=\" --libdir=/usr/local/lib --with-components=libcups\" build_autoconf\n\
[v4l-utils] patch_file meson.build \"s/dependency('iconv'/dependency('iconv-meson'/\"\n\
[v4l-utils] MESON_OPTS+=\" -Dv4l-utils=false\" build_meson\n\
[openh264] echo > codec/console/enc/meson.build\n\
[openh264] MESON_OPTS+=\" -Dtests=disabled\" build_meson\n\
[gstreamer] patch_file subprojects/gst-plugins-bad/gst/siren/common.c 's/^\\(float step_size\\[8\\] = {\\)$/static \\1/'\n\
[gstreamer] patch_file subprojects/gst-plugins-bad/gst/siren/common.h 's/^\\(extern float step_size\\[8\\];\\)$/\/\/\\1/'\n\
[gstreamer] MESON_OPTS+=\" --prefer-static \
--wrap-mode=nofallback \
--force-fallback=libavfilter,dv,x264,fdk-aac,avtp,dssim,dav1d \
-Dgst-full-target-type=static_library \
-Dgst-full-libraries=gstreamer-app-1.0,gstreamer-video-1.0,gstreamer-audio-1.0,gstreamer-codecparsers-1.0,gstreamer-tag-1.0 \
-Ddevtools=disabled \
-Dgst-examples=disabled \
-Dtests=disabled \
-Dexamples=disabled \
-Dintrospection=disabled \
-Ddoc=disabled \
-Dgtk_doc=disabled \
-Dtools=disabled \
-Dges=disabled \
-Drtsp_server=disabled \
-Dgst-plugins-base:gl=disabled \
-Dgst-plugins-base:x11=disabled  \
-Dgst-plugins-good:ximagesrc=disabled \
-Dgst-plugins-good:v4l2=disabled \
-Dgst-plugins-bad:x11=disabled \
-Dgst-plugins-bad:wayland=disabled\" build_meson\n\
[libpcap] ./autogen.sh && DBUS_LIBS=\"`pkg-config --libs --static dbus-1`\" build_autoconf\n\
[isdn4k-utils] pushd capi20\n\
[isdn4k-utils] MAKE_TARGETS=\"install-libLTLIBRARIES install-pcDATA install-includeHEADERS\" build_autoconf\n\
[isdn4k-utils] popd\n\
[isdn4k-utils] add_pc_file_section capi20.pc 'Libs.private' '-ldl -lrt -lpthread'\n\
[tiff] build_autoconf --no-make\n\
[tiff] patch_file Makefile 's/SUBDIRS = port libtiff tools build contrib test doc/SUBDIRS = port libtiff build test doc/'\n\
[tiff] make install\n\
[tiff] echo exit\n\
[ieee1284] ./bootstrap\n\
[ieee1284] MAKE_TARGETS=\"install-includeHEADERS install-libLTLIBRARIES\" build_autoconf\n\
[sane-backends] CONFIGURE_OPTS+=\" --enable-dynamic --enable-preload\" build_autoconf --reconf\n\
[sane-backends] pushd tools\n\
[sane-backends] make install-pkgconfigDATA install-binSCRIPTS\n\
[sane-backends] popd\n\
[openldap] CONFIGURE_OPTS+=\" --disable-debug --disable-slapd\" build_autoconf\n\
[krb5] cd src\n\
[krb5] CONFIGURE_OPTS+=\" --disable-shared --enable-static\" build_autoconf --no-make\n\
[krb5] make -j$BUILD_JOBS && make install\n\
[krb5] patch_pc_file mit-krb5.pc 's/Libs\\.private:\\(.*\\)/Libs.private:\\1 -ldl -lresolv/'\n\
[krb5] add_pc_file_section mit-krb5-gssapi.pc 'Libs.private' '-ldl -lresolv'\n\
[krb5] echo exit\n\
[wine] autoreconf -f\n\
[wine] CFLAGS=\"\${CFLAGS/-flto -ffat-lto-objects}\" \
CPPFLAGS=\"\${CPPFLAGS/-flto -ffat-lto-objects}\" \
CXXFLAGS=\"\${CXXFLAGS/-flto -ffat-lto-objects}\" \
OBJCFLAGS=\"\${OBJCFLAGS/-flto -ffat-lto-objects}\" \
PKG_CONFIG_PATH=/usr/local/lib/gstreamer-1.0/pkgconfig \
CONFIGURE_OPTS=\"--disable-tests --prefix=\"$PREFIX\" --disable-year2038\" build_autoconf --reconf --no-make\n\
[wine] [ \"${BUILD_WITH_LTO:-}\" == \"y\" ] && sed -i 's/\(^[ \\t]*LDFLAGS[ \\t]*=.*\)-fno-lto\(.*$\)/\\1-flto -flto-partition=one\\2/' Makefile\n\
[wine] make -j$BUILD_JOBS install\n\
[wine] find \"$PREFIX/lib/wine\" -type f -name \"*\" -exec strip -s {} \\;\n\
[wine] tar czvf \"\$HOME/wine-build.tar.gz\" -C \"$PREFIX\" .\n\
[wine] make uninstall\n\
[wine-nine-standalone] echo \"Work in progress!\"\
"

RUN . /build/build.sh
