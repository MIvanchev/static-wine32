#!/bin/bash

export CFLAGS="$COMPILE_FLAGS"
export CXXFLAGS="$COMPILE_FLAGS"
export OBJCFLAGS="$COMPILE_FLAGS"
export OBCXXFLAGS="$COMPILE_FLAGS"
export LDFLAGS="$LINK_FLAGS"
export AR=/usr/bin/gcc-ar
export RANLIB=/usr/bin/gcc-ranlib
export NM=/usr/bin/gcc-nm

CONFIGURE_OPTS="--prefix=/usr/local \
                --sysconfdir=/etc \
                --datarootdir=/usr/share \
                --mandir=/usr/local/man \
                --host=i386-linux-gnu"

CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=/usr/local \
            -DCMAKE_AR=/usr/bin/gcc-ar \
            -DCMAKE_RANLIB=/usr/bin/gcc-ranlib \
            -DCMAKE_NM=gcc-nm \
            -DSYSCONFDIR=/etc \
            -DDATAROOTDIR=/usr/share \
            -DMANDIR=/usr/local/man \
            -DCMAKE_BUILD_TYPE=Release"

MESON_OPTS="--prefix=/usr/local \
            --sysconfdir=/etc \
            --datadir=/usr/share \
            --mandir=/usr/local/man \
            --buildtype=release \
            --cross-file=../meson-cross-i386 \
            --default-library=static \
            --prefer-static"

patch_file()
{
  local file="$1"
  local checksum_before=$(md5sum "$file")
  sed -i "$2" "$file"
  local checksum_after=$(md5sum "$file")
  if [[ $checksum_before != $checksum_after ]]; then
    echo "File was unchanged after applying patch" 1>&2
    false
  fi
}

build_autoconf()
{
  local reconf=false
  local auto_feature=true
  local prepend_build_vars=true
  local make=true

  while [ $# -ne 0 ]
  do
    arg="$1"
    case "$arg" in
    --reconf)
      reconf=true ;;
    --no-auto-feature)
      auto_feature=false ;;
    --append-build-vars)
      prepend_build_vars=false ;;
    --no-make)
      make=false ;;
    *)
      # TODO: Invalid arg.
      ;;
    esac
    shift
  done
  if [[ $reconf == true ]]; then
    autoreconf -fi
  fi
  local features
  if [[ $auto_feature == true ]]; then
    for feature in e_static d_shared d_docs d_doc d_tests wo_python wo_python3; do
      prefix=${feature%%_*}
      feature=${feature#*_}
      local test
      case $prefix in
      e)
        test="\-\-\(enable\|disable\)-$feature"
        feature=" --enable-$feature" ;;
      d)
        test="\-\-\(enable\|disable\)-$feature"
        feature=" --disable-$feature" ;;
      w)
        test="\-\-\(with\|without\)-$feature"
        feature=" --with-$feature" ;;
      wo)
        test="\-\-\(with\|without\)-$feature"
        feature=" --without-$feature" ;;
      esac
      ./configure --help | grep -q "$test" && features+=" $feature"
    done
  fi

  if [ $prepend_build_vars = true ]; then
    ./configure $CONFIGURE_OPTS $features
  else
    ./configure $CONFIGURE_OPTS $features $CONFIGURE_BUILD_VARS
  fi

  if [ $make == true ]; then
    make -j$BUILD_JOBS ${MAKE_TARGETS-install}
  fi
}

build_cmake()
{
  cmake $CMAKE_OPTS -B build -S "${CMAKE_SOURCE_PATH-.}"
  make -j$BUILD_JOBS -C build install
}

build_meson()
{
  local install=true
  while [ $# -ne 0 ]
  do
    arg="$1"
    case "$arg" in
    --no-install)
      install=false ;;
    *)
      # TODO: Invalid arg.
      ;;
    esac
    shift
  done
  meson setup build $MESON_OPTS
  meson compile -C build -j $BUILD_JOBS $MESON_COMPILE_TARGETS
  if [[ $install == true ]]; then
    meson install -C build --no-rebuild $MESON_INSTALL_OPTS
  fi
}
