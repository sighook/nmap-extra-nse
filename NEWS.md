# NEWS

## Unreleased

- Discover `GeoLite2-ASN.mmdb` automatically in Nmap's data directory when
  neither geolocation script is given an explicit `.asn` path. Geographic
  lookups continue without ASN data if the file is absent.

## v0.1

First release of the maintained offline geolocation scripts. They read local
GeoLite2 databases; no geolocation web service is contacted during a scan.

- Added `ip-geolocation-mmdb.nse` for IPv4 and IPv6 host lookups, with optional
  ASN information. Coordinates can be consumed by Nmap's existing map scripts.
- Added `traceroute-geolocation-mmdb.nse` for per-hop lookup and KML export.
  KML contains individual points, not a guessed physical route.
- Added a pure-Lua MMDB reader and a small shared lookup interface. City,
  Country and ASN databases are supported; the reader handles 24-, 28- and
  32-bit search-tree records and IPv4 addresses stored in IPv6 trees.
- Kept registered country separate from estimated location. Where available,
  GeoLite2 accuracy radius is retained in output and traceroute KML. Private,
  shared-address-space and other non-public IPs are not plotted.
- Added synthetic Lua tests for lookup behavior, NSE output, malformed data,
  resource bounds and file cleanup. Manual integration tests covered Nmap
  7.991 with real GeoLite2 databases; see README for scope and limitations.
- Added `make check`, `make fetch`, and separate NSE/database installation
  targets, including staged installs with `DESTDIR`. Database downloads are
  validated before installation; installation never fetches them.
- Separated the historical Nmap pull-request snapshots into `contrib/` and
  `archive/`. They are not installed by the Makefile and are not maintained
  as part of the geolocation scripts.

GeoLite2 data is obtained separately and changes over time. IP geolocation is
an estimate, not evidence of a device's or router's physical position.
