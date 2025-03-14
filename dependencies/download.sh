#!/bin/bash

PKG_DIR=$(dirname $0)

while IFS=, read -r type url arg1 arg2 arg3 arg4
do
    if [[ "$type" == "file" ]]; then
        if [[ -n "$arg1" ]]; then
            pkg_file="$arg1"
        else
            pkg_file=${url##*/}
        fi

        if [[ -e "$PKG_DIR/$pkg_file" ]]; then
            echo "File \"$pkg_file\" is already present; not downloading." 1>&2
            echo 1>&2
        else
            wget -q --no-clobber --output-document "$PKG_DIR/$pkg_file" "$url"
            if [[ $? -ne 0 ]]; then
                exit 1
            fi
        fi
    elif [[ "$type" == "git" ]]; then
        if [[ -z "$arg1" ]]; then
            echo "You must specify a branch/tag for the Git repository $url." 1>&2
            exit 1
        elif [[ -z "$arg2" ]]; then
            echo "You must specify a directory for the Git repository $1." 1>&2
            exit 1
        fi

        pkg_path="$PKG_DIR/$arg2"
        pkg_file="${pkg_path}.tgz"

        if [[ -e "$pkg_file" ]]; then
            echo "Git repository archive '" $pkg_file "' is already present; repository will not be cloned." 1>&2
            echo 1>&2
        else
            git clone --quiet --branch "$arg1" --depth 1 "$url" "$pkg_path" && tar --xform="s:^${PKG_DIR}/::"  -czf "$pkg_file" "$pkg_path" && rm -rf "$pkg_path"
            if [[ $? -ne 0 ]]; then
                exit 1
            fi
            echo 1>&2
        fi
    fi
done < "$PKG_DIR/packages.csv"
