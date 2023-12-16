#!/bin/bash
PKG_DIR=$(dirname $0)
for line in $(cat "$PKG_DIR/packages.txt" | sed 's/[ \t][ \t]*/\$/g'); do
  ver_found="false"
  pkg=$(echo "$line" | sed 's/\$.*//')
  if [[ "$pkg" =~ "https://github.com/"(.*)"/archive/refs/tags/"(.*)\.tar.* \
        || "$line" =~ "https://github.com/"(.*)\.git\$(.*)\$ ]]; then
#    continue
    path=${BASH_REMATCH[1]}
    tag=${BASH_REMATCH[2]}
    latest_tag=$(wget -q -O - "https://api.github.com/repos/$path/tags" | \
                 grep -o "https://api.github.com/repos/$path/.*/refs/tags/[^\"]\+" | \
                 grep -vi "[0-9]-\?\(rc\|pre\|b\)" | \
                 grep "[0-9][._0-9]*$" | \
                 sed 's/.*\///' | \
                 sed 's/.*/& &/' | \
                 sed 's/[0-9][._0-9]* .*/ &/' | \
                 sed 's/[^ ]* //' | \
                 awk '{ gsub(/_/, ".", $1); print }' | \
                 sort -rV | \
                 head -n1 | \
                 sed 's/[^ ]* //')
#    echo "Latest tag of $pkg is PROBABLY \"$latest_tag\"."
    if [[ -n "$latest_tag" ]]; then
      ver_found="true"
      if [[ "$latest_tag" != "$tag" ]]; then
        echo "$pkg with current tag \"$tag\" PROBABLY has a newer version under the tag \"$latest_tag\"."
      fi
    fi
  elif [[ "$pkg" =~ "https://github.com/"(.*)"/releases/".*"/"(.*)-([0-9]+[0-9.]+)(\..*) ]]; then
#    continue
    path=${BASH_REMATCH[1]}
    name=${BASH_REMATCH[2]}
    ver=${BASH_REMATCH[3]}
    ext=${BASH_REMATCH[4]}
    latest_ver=$(wget -q -O - "https://api.github.com/repos/$path/releases/latest" | \
                 grep -o -m 1 "$name-[0-9]\+\(\.[0-9]\+\)\+" | \
                 sed "s/.*-//")
    #echo "Latest version of $pkg is $latest_ver."
    if [[ -n "$latest_ver" ]]; then
      ver_found="true"
      if [[ "$latest_ver" != "$ver" ]]; then
        echo "$pkg could be updated to $latest_ver."
      fi
    fi
  elif [[ "$pkg" =~ (.*)/(.*)-([0-9]+[0-9.]+)(\..*) ]]; then
#    continue
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
    latest_ver=
    for item in $list; do
      if [[ "$item" == "$path" ]]; then
        latest_ver=$(wget -q -O - $path | \
                     grep -vi "$name-[0-9]\+\(\.[0-9]\+\)*-\?\(rc\|pre\|b\)" | \
                     grep -o "$name-[0-9]\+\(\.[0-9]\+\)*" | \
                     sed "s/.*-//" | \
                     sort -rV |\
                     head -n1)
        break
      fi
    done
    if [[ -n "$latest_ver" ]]; then
      ver_found="true"
      if [[ "$latest_ver" != "$ver" ]]; then
        echo "$pkg could be updated to $latest_ver."
      fi
    fi
  fi

  if [[ "$ver_found" == "false" ]]; then
    echo "Cannot determine latest version of $pkg; must be manually checked." 2>&1
  fi
done

