# nmap-extra-nse

Two maintained scripts for offline IP geolocation, alongside a historical
archive of scripts proposed to Nmap by various authors.

These parts have different ownership and maintenance expectations:

- **`scripts/`, `nselib/`, `tests/`** — independently maintained code in this repository.
- **`contrib/`** — snapshots from [Nmap pull requests](https://github.com/nmap/nmap/pulls), including the maintainer's own submissions and other authors' work. The numeric prefix is a PR number, **not a version**. Authorship and licensing remain with each original contributor.
- **`archive/`** — broken snapshots or files conflicting with an already-shipped Nmap script. Retained for provenance; **do not install**.

See [CONTRIB.md](CONTRIB.md) for the upstream status audit and exceptions.
These files are **not all part of official Nmap**. PR state is not an assessment of
security, correctness, or compatibility with current NSE libraries.

## Offline IP geolocation

The maintained scripts read local GeoLite2 MMDB databases, rather than
querying a geolocation web service or using the legacy MaxMind `.dat` format.
They make no HTTP requests during a scan.

- `ip-geolocation-mmdb.nse`: look up scanned addresses. Coordinates, when
  present, are also published to Nmap's `geoip` registry for its map exporters.
- `traceroute-geolocation-mmdb.nse`: annotate traceroute hops with location
  estimates and ASN information; optionally write KML **point markers**.
- `nselib/geolocation.lua`: the shared lookup boundary. Currently the only
  backend is the offline `mmdb` reader in `nselib/mmdb.lua`.

This is IP geolocation, **not GPS**. A registered country is not a located
country; we display the two separately. When a City record has coordinates,
we retain MaxMind's accuracy radius (in kilometres). It describes the
uncertainty of the estimate, not a precise router position. Country-only and
registration-only results do not become map pins, and traceroute KML does not
draw a physical route between guessed points.

### Get it running

You need Nmap and GNU Make. For downloading and checking databases, install
`curl` and `mmdblookup` (package `mmdb-bin` on Debian-derived systems).
For the offline tests, you need Python 3 and Lua 5.4.

From this repository:

```sh
make check          # offline tests; no download, no root
make fetch          # GeoLite2 City, Country and ASN -> ./data/
make show-config    # see where installation will go
sudo make install   # the maintained NSE files + downloaded databases
```

`make fetch` downloads from [P3TERX/GeoLite.mmdb](https://github.com/P3TERX/GeoLite.mmdb),
a third-party mirror. Before installing the downloads, `mmdblookup` checks
that each file can be read as an MMDB. This is a format check, not proof of
provenance or of the database edition. Downloads are ignored by Git.
**`make install` never downloads anything**; missing or unreadable local
databases cause an error.

If you only need part of the installation:

```sh
sudo make install-nse     # two NSE scripts + two Lua libraries
sudo make install-db      # the three databases from ./data/
```

Only the two maintained scripts, their Lua libraries and the GeoLite2 MMDB
files are installed. Historical files in `contrib/` and `archive/` are left alone.

The default destination is `/usr/share/nmap`, a common Linux package layout.
The Makefile does not discover Nmap's data directory. If yours differs,
set `NMAP_DATADIR` explicitly:

```sh
make show-config NMAP_DATADIR=/opt/nmap/share/nmap
sudo make install NMAP_DATADIR=/opt/nmap/share/nmap
```

For packaging or checking the install without root, `DESTDIR` stages the same
files under an alternate root:

```sh
make install DESTDIR=/tmp/nmap-stage
```

The databases are installed in `nselib/data/` under the selected Nmap data
directory. You can also supply pre-downloaded MMDB files via `DB_DIR`, or
change the mirror with `DB_URL`. See `make show-config` before overriding
paths. The Makefile installs maintained NSE components, not the archived
third-party scripts; no database files are committed to this repository.

GeoLite2 data changes over time. For long-term use, prefer MaxMind's official
[`geoipupdate`](https://dev.maxmind.com/geoip/updating-databases/) with your
own account/license key and follow the
[GeoLite2 license](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data/).
A successful download does not certify the accuracy of an IP location.

### Run the scripts

After installing to the default `/usr/share/nmap` directory:

```sh
DB=/usr/share/nmap/nselib/data

# Offline address lookups; -Pn avoids active host discovery.
nmap -sn -Pn -n \
  --script /usr/share/nmap/scripts/ip-geolocation-mmdb.nse \
  --script-args "ip-geolocation-mmdb.db=$DB/GeoLite2-City.mmdb,ip-geolocation-mmdb.asn=$DB/GeoLite2-ASN.mmdb" \
  1.1.1.1 8.8.8.8

# A real IPv4 traceroute does send packets; use an authorized target.
nmap -sn -n --traceroute \
  --script /usr/share/nmap/scripts/traceroute-geolocation-mmdb.nse \
  --script-args "traceroute-geolocation-mmdb.db=$DB/GeoLite2-City.mmdb,traceroute-geolocation-mmdb.asn=$DB/GeoLite2-ASN.mmdb,traceroute-geolocation-mmdb.kmlfile=route.kml" \
  example.com
```

Switch to `GeoLite2-Country.mmdb` with the `.db` argument when you only need
country-level data. ASN lookups are optional; omit the `.asn` argument to skip
them. An absent database or unsupported provider is an explicit error, not a
fallback to a network geolocation service. The currently supported backend is
`geolocation.provider=mmdb`.

The upstream `ip-geolocation-map-kml.nse` can use our host script's registered
coordinates in the same scan. It only receives latitude/longitude, though:
it cannot preserve our accuracy-radius metadata. Our traceroute KML includes
available accuracy radii as `ExtendedData`. KML output is **point-only** and
uses longitude,latitude order. Use a separate KML file per target so you do
not overwrite earlier results.

The examples use absolute `--script` paths, so they do not require changing
Nmap's installed script database. Output depends on the MMDB edition and date;
not every public address has coordinates.

### Tests and verification

`make check` generates small deterministic MMDB fixtures (24/28/32-bit tree
records, IPv4/IPv6 paths, pointers and malformed files) and runs the Lua
reader, provider, host NSE and traceroute NSE tests. Nothing is downloaded:

```sh
make check
make clean           # removes only synthetic fixtures, never ./data/
```

Manual integration checks have also been performed with Nmap 7.991 and
GeoLite2 City, Country and ASN databases: selected IPv4/IPv6 host lookups,
comparison with `mmdblookup`, traceroute ASN enrichment, KML export and a
256-address offline lookup batch. These are **not** part of `make check`, and
they do not establish compatibility with every Nmap or MMDB release. A live
IPv6 traceroute has not been verified.

When a lookup disagrees with expectations, use `mmdblookup` on the *same IP*
and the *same database file* before investigating the NSE decoder.

## Nmap PR snapshots

The `contrib/` directory is a source archive, not an install-all directory.
It includes scripts from different authors; it is not a set of supported releases.
Some submissions make state-changing or exploit requests; run only against
systems where you have authorization. Review each script and its external
resources before use. PR-number prefixes are part of this archive's provenance,
not script names Nmap can install directly.

To run one candidate without altering Nmap's installed script database, for
example:

```sh
nmap --script "$PWD/contrib/2248-zookeeper-info.nse" -p 2181 <authorized-host>
```

Some old submissions need data files, outdated NSE APIs or additional setup.
Never bulk-copy all `*.nse` into `/usr/share/nmap/scripts/` or append ad-hoc
entries to `script.db`. The former repository's `update-scriptdb.sh` helper was
removed because it blindly appended entries and did not validate scripts.

## License and provenance

See [LICENSE](LICENSE). The repository contains code written by different
authors. Keep original author and license declarations, and consult the linked
PR before redistributing or modifying an individual contribution. Inclusion
here does not imply endorsement by Nmap or ongoing maintenance of a snapshot.
