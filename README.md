About
-----
Nmap scripts that aren't merged to upstream.
The scripts have prefix (a.e. `0001-`), it's a "Pull Request" number.

Usage
-----
1. Copy nse scripts to nmap directory:
```sh
for nse in *.nse; do
    cp -n $nse /usr/share/nmap/scripts/${nse#*-}
done
```

2. Update the database:
```sh
sudo nmap --script-updatedb
```
Use `update-scriptdb.sh` in case you get the following error:
```
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
```
Example:
```
sh update-scriptdb.sh /usr/share/nmap/scripts/script.db
```
