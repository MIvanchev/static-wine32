#!/bin/bash
set -e

if [[ -z "$PLATFORM" ]]; then
    echo "You must set the PLATFORM variable in Dockerfile (or through --build-arg) " 1>&2
    echo "before building the image. See " 1>&2
    echo "https://gcc.gnu.org/onlinedocs/gcc/x86-Options.html for a list of the " 1>&2
    echo "allowed values and pick the one that matches your CPU's architecture." 1>&2
    false
fi

if [[ -z "$PREFIX" ]]; then
    echo "You must set the PREFIX variable in Dockerfile (or through --build-arg) " 1>&2
    echo "before building the image. The value should be the path to the Wine " 1>&2
    echo "installation directory on your machine, e.g. \$HOME/.local" 1>&2
    false
fi

PREFIX=${PREFIX%/}

gcc -E -march=$PLATFORM -xc /dev/null >/dev/null

jinja2 build/meson-cross-i386.template \
    -D c_args="$COMPILE_FLAGS" \
    -D c_link_args="$LINK_FLAGS" \
    -D cpp_args="$COMPILE_FLAGS" \
    -D cpp_link_args="$LINK_FLAGS" > build/meson-cross-i386

cat build/meson-cross-i386
mkdir -p build
cd build
source ./build-tools.sh

while IFS="" read -r line
do
    name=$(echo "$line" | sed 's/^\[\([^]]*\)\].*/\1/').sh
    line=$(echo "$line" | sed 's/^\[[^]]*\] *//')

    if [[ ! -e "$name" ]]; then
        echo "#!/bin/sh" > "$name"
        echo "set -e" >> "$name"
        echo >> "$name"
        chmod +x "$name"
    fi

    echo "$line" >> "$name"
done <<< $(echo -e "$DEP_BUILD_SCRIPTS")

DEFAULT_BUILD_SCRIPT="\
#!/bin/sh\n\
set -e\n\
build_autoconf\n"

while IFS=, read -r type url arg1 arg2 arg3 arg4
do
    unset pkg_file
    unset pkg_name
    unset pkg_key
    unset pkg_dir
    unset pkg_script
    unset pkg_cache
    unset pkg_cache_file

    if [[ "$type" == "file" ]]; then
        if [[ -z "$arg1" ]]; then
            pkg_file=${url##*/}
        else
            pkg_file=$arg1
        fi
        pkg_name=$(echo $pkg_file | sed 's/\(.*\)-[0-9][0-9]*\(\.[0-9][0-9]*\)*.*/\1/')
        pkg_key=$arg2
        pkg_cache=$arg3
    elif [[ "$type" == "git" ]]; then
        pkg_name=$(echo ${arg2} | sed 's/\(.*\)-[0-9][0-9]*\(\.[0-9][0-9]*\)*/\1/')
        pkg_file=${arg2}.tgz
        pkg_key=$arg3
        pkg_cache=$arg4
    fi

    pkg_dir=$(echo "$pkg_file" | sed -e 's/\.tar\.\(gz\|xz\|bz2\)$//' -e 's/\.tgz$//')
    pkg_script="${pkg_name}${pkg_key:+-}${pkg_key}"

    if [[ -n "$pkg_cache" ]]; then
        pkg_cache="${pkg_cache,,}"
        case "$pkg_cache" in
            y) pkg_cache=yes ;;
            yes) pkg_cache=yes ;;
            true) pkg_cache=yes ;;
            n) pkg_cache=no ;;
            no) pkg_cache=no ;;
            false) pkg_cache=no ;;
            *)
                echo "Invalid cache flag; must be one of 'y', 'yes', 'true', 'n', 'no', 'false' or empty." 2>&1
                echo 2>&1
                exit 1
                ;;
        esac
    else
        pkg_cache=yes
    fi

    if [[ "$pkg_cache" == "yes" ]]; then
        pkg_cache_file="/cache/$pkg_dir"
        if [[ -n "$pkg_key" ]]; then
            pkg_cache_file="${pkg_cache_file}-${pkg_key}.tgz"
        else
            pkg_cache_file="${pkg_cache_file}.tgz"
        fi
    elif [[ -n "$pkg_key" ]]; then
        echo "Cache key is set, but caching is disabled." 2>&1
        echo 2>&1
        exit 1
    fi

    echo
    echo "pkg_file: $pkg_file"
    echo "pkg_name: $pkg_name"
    echo "pkg_key: $pkg_key"
    echo "pkg_dir: $pkg_dir"
    echo "pkg_script: $pkg_script"
    echo "pkg_cache: $pkg_cache"
    echo "pkg_cache_file: $pkg_cache_file"
    echo

    if [[ -n "$pkg_cache_file" && -e "$pkg_cache_file" ]]; then
      echo "Using cached entry $pkg_cache_file, package will not be rebuilt."
      tar -xzvf "$pkg_cache_file" --keep-old-files --strip-components=1 -C /
      [ -e "${pkg_script}-post.sh" ] && . "${pkg_script}-post.sh"
      continue
    fi

    if [[ ! -e "$pkg_script.sh" ]]; then
        echo -e "$DEFAULT_BUILD_SCRIPT" > "$pkg_script.sh"
    fi

    tar -xf "$pkg_file"
    pushd "$pkg_dir"

    if [ -f "../patches/$pkg_dir.patch" ]; then
        patch -p1 < "../patches/$pkg_dir.patch"
    fi

    cat "../$pkg_script.sh"
    . "../$pkg_script.sh"
    popd
    rm -rf "$pkg_dir"

    [ -e "${pkg_script}-post.sh" ] && . "${pkg_script}-post.sh"
done < /build/packages.csv

true
