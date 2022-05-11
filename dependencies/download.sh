#!/bin/bash
PKG_DIR=$(dirname $0)
cat "$PKG_DIR/packages.txt" | awk -v download_dir="$PKG_DIR" -f "$PKG_DIR/download.awk"
