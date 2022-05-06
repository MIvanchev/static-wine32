#!/bin/bash
PKG_DIR=$(dirname $0)
cat "$PKG_DIR/packages.txt" | awk -v pkg_dir="$PKG_DIR" '                   \
{                                                                           \
  if ($2 && (getline _ < $2) >= 0)                                          \
  {                                                                         \
    next                                                                    \
  }                                                                         \
                                                                            \
  if (system("wget --no-clobber -P \"" pkg_dir "\" "                        \
             $1 ($2 ? (" --output-document \"" pkg_dir "/" $2 "\"") : ""))) \
  {                                                                         \
    exit 1                                                                  \
  }                                                                         \
}'
