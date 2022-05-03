#!/bin/bash
cat packages.txt | awk '                                 \
{                                                        \
  if ($2 && (getline _ < $2) >= 0)                       \
  {                                                      \
    next                                                 \
  }                                                      \
                                                         \
  if (system("wget --no-clobber "                        \
             $1 ($2 ? (" --output-document " $2) : ""))) \
  {                                                      \
    exit 1                                               \
  }                                                      \
}'
