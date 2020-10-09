#!/bin/sh
#
# The script.db updater, to bypass the following error:
#
# $ sudo nmap --script-updatedb
# Starting Nmap 7.90 ( https://nmap.org ) at 2020-10-09 18:17 EEST
# NSE: Updating rule database.
# NSE: failed to initialize the script engine:
# /usr/bin/../share/nmap/nse_main.lua:631: portrule must be a function!
# stack traceback:
#   [C]: in function 'assert'
#   /usr/bin/../share/nmap/nse_main.lua:631: in field 'new'
#   /usr/bin/../share/nmap/nse_main.lua:1296: in main chunk
#   [C]: in ?
#
# QUITTING!
#
# (c) chinarulezzz, drop at chinarulezzz dot fun

scriptdb=$1
for nse in *.nse; do
  categories="$(grep -Eo 'categories[[:space:]]+=[[:space:]]{.*}' $nse)"
  if [ -n "$categories" ]; then
    cat >> $scriptdb <<EOF
Entry { filename = "${nse#*-}", ${categories} }
EOF
  else
    echo "$nse missing the categories! Check it."
  fi
done

# vim:ft=sh:sw=2:ts=2:sts=2:et:cc=72
# End of file
