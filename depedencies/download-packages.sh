!/bin/bash
#wget --input-file packages.txt --no-clobber
cat packages.txt | awk '{system("wget --no-clobber " $1 ($2 ? (" --output-document " $2) : ""))}'
