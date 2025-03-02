#!/bin/bash

PKG_DIR=$(dirname $0)

while IFS=, read -r type url arg1 arg2; do
    if [[ "$url" =~ "https://github.com/"(.*)"/archive/refs/tags/"(v[0-9]+|v[0-9]+\.[0-9]+|v[0-9]+\.[0-9]+\.[0-9]+) ]]; then
        latest=$(curl -s "https://api.github.com/repos/${BASH_REMATCH[1]}/tags" 2>&1 |
            jq --raw-output '.[] | .name' |
            grep -o 'v[0-9]\+\(\.[0-9]\+\)*' |
            head -1)
        if [[ "$latest" != "${BASH_REMATCH[2]}" ]]; then
            echo "$url could PROBABLY be updated to $latest."
        fi
    elif [[ "$url" =~ "https://github.com/"(.*)"/"(.*)".git" ]]; then
        owner=${BASH_REMATCH[1]}
        proj=${BASH_REMATCH[2]}
        api=tags
        case "$proj" in
            "libxkbcommon") matcher="xkbcommon-[0-9]+(\.[0-9]+)+" ;;
            "vulkan-sdk")
                api=branches
                matcher="vulkan-sdk-[0-9]+(\.[0-9]+)+"
                ;;
            "SPIRV-Tools")
                api=branches
                matcher="vulkan-sdk-[0-9]+(\.[0-9]+)+"
                ;;
            "SPIRV-Headers")
                api=branches
                matcher="vulkan-sdk-[0-9]+(\.[0-9]+)+"
                ;;
            "llvm-project") matcher="llvmorg-[0-9]+(\.[0-9]+)+" ;;
            "SPIRV-LLVM-Translator") matcher="v[0-9]+(\.[0-9]+)+" ;;
            "SDL") matcher="release-[0-9]+(\.[0-9]+)+" ;;
            "libpcap")
                api=branches
                matcher="libpcap-[0-9]+(\.[0-9]+)+"
                ;;
            "libieee1284") matcher="V[0-9]+(_[0-9]+)+" ;;
            *)
                echo "Cannot determine latest version of $url; must be manually checked." 2>&1
                continue
                ;;
        esac
        latest=$(curl -s "https://api.github.com/repos/$owner/$proj/$api" 2>&1 |
            jq --raw-output '.[] | .name' |
            grep -xE "${matcher}" |
            head -1)
        if [[ -z "$latest" ]]; then
            echo "Internal error: failed to find latest version of $url." 2>&1
            exit 1
        elif [[ "$latest" != "$arg1" ]]; then
            echo "$url could PROBABLY be updated to $latest."
        fi
    elif [[ "$url" =~ (.*)/(.*)-([0-9]+[0-9.]+)(\..*) ]]; then
        path=${BASH_REMATCH[1]}
        name=${BASH_REMATCH[2]}
        ver=${BASH_REMATCH[3]}
        ext=${BASH_REMATCH[4]}

        list="https://ftp.gnu.org/pub/gnu/libiconv \
      https://www.x.org/releases/individual/proto \
      https://www.x.org/releases/individual/lib \
      https://sourceware.org/pub/bzip2 \
      https://gmplib.org/download/gmp \
      https://ftp.gnu.org/gnu/nettle \
      https://xkbcommon.org/download \
      https://archive.mesa3d.org \
      https://downloads.xiph.org/releases/ogg \
      https://downloads.xiph.org/releases/vorbis \
      https://downloads.xiph.org/releases/flac \
      https://downloads.xiph.org/releases/opus \
      https://de.freedif.org/gnu/libtool \
      https://www.samba.org/ftp/tdb \
      https://freedesktop.org/software/pulseaudio/releases \
      https://www.alsa-project.org/files/pub/lib \
      https://www.alsa-project.org/files/pub/plugins \
      https://openal-soft.org/openal-releases \
      https://linuxtv.org/downloads/v4l-utils \
      http://download.osgeo.org/libtiff \
      https://www.openldap.org/software/download/OpenLDAP/openldap-release \
      https://dri.freedesktop.org/libdrm \
      https://dbus.freedesktop.org/releases/dbus"

        unset latest_ver

        for item in $list; do
            if [[ "$item" == "$path" ]]; then
                latest_ver=$(wget -q -O - $path |
                    grep -vi "$name-[0-9]\+\(\.[0-9]\+\)*-\?\(rc\|pre\|b\)" |
                    grep -o "$name-[0-9]\+\(\.[0-9]\+\)*" |
                    sed "s/.*-//" |
                    sort -rV |
                    head -n1)
            fi
        done

        if [[ -n "$latest_ver" ]]; then
            if [[ "$latest_ver" != "$ver" ]]; then
                echo "$url could be updated to $latest_ver."
            fi
        else
            echo "Cannot determine latest version of $url; must be manually checked." 2>&1
        fi
    else
        echo "Cannot determine latest version of $url; must be manually checked." 2>&1
    fi
done <"$PKG_DIR/packages.csv"

