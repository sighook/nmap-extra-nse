# nmap-extra-nse

Personal NSE scripts and an archive of third-party scripts proposed to Nmap.

The two collections have different ownership and maintenance expectations:

- **`scripts/`, `nselib/`, `tests/`** — independently maintained code in this repository.
- **`contrib/`** — snapshots copied from upstream [Nmap pull requests](https://github.com/nmap/nmap/pulls); the numeric prefix is the PR number, **not a version**. Original authorship and licensing remain with the contributors.
- **`archive/`** — broken snapshots or files conflicting with an already-shipped Nmap script. Retained for provenance; **do not install**.

See [CONTRIB.md](CONTRIB.md) for the upstream status audit and exceptions.
These files are **not all part of official Nmap**. PR state is not an assessment of
security, correctness, or compatibility with current NSE libraries.

## Offline IP geolocation

Nmap ships a handful of geolocation scripts, but some still depend on dead
web APIs or the old MaxMind `.dat` format. These two scripts use local GeoLite2
MMDB databases instead. They make no HTTP requests during a scan.

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
`curl` and `mmdblookup` (Debian/Kali package: `mmdb-bin`). For the offline
tests, you need Python 3 and Lua 5.4.

From this repository:

```sh
make check          # offline tests; no download, no root
make fetch          # GeoLite2 City, Country and ASN -> ./data/
make show-config    # see where installation will go
sudo make install   # the maintained NSE files + downloaded databases
```

`make fetch` downloads from [P3TERX/GeoLite.mmdb](https://github.com/P3TERX/GeoLite.mmdb),
a third-party mirror. It checks that all three files can be opened by
`mmdblookup` before replacing your previous downloads. The downloaded files
are ignored by Git. **`make install` never downloads anything**; if the
local databases are missing or invalid, it stops and tells you.

If you only need part of the installation:

```sh
sudo make install-nse     # two NSE scripts + two Lua libraries
sudo make install-db      # the three databases from ./data/
```

Only `scripts/` and `nselib/` are installed. The old submissions in `contrib/`
and `archive/` are deliberately left alone.

The default destination is `/usr/share/nmap`, as used by our Kali lab. On
systems with a different Nmap data directory, override it explicitly:

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
paths. Neither the databases nor your lab's Docker image belongs in this
repository: the Kali lab selects and pins its own version of this project.

GeoLite2 data changes over time. For long-term use, prefer MaxMind's official
[`geoipupdate`](https://dev.maxmind.com/geoip/updating-databases/) with your
own account/license key and follow the
[GeoLite2 license](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data/).
A successful download does not certify the accuracy of an IP location.

### Run the scripts

On Kali, after installing to the default data directory:

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

Use absolute `--script` paths if you have not registered the scripts with
Nmap's script database. There is no need to run `nmap --script-updatedb`,
which can fail in restricted container builds due to executable capabilities.

### Testing and what we've actually checked

`make check` generates small deterministic MMDB fixtures (24/28/32-bit tree
records, IPv4/IPv6 paths, pointers and malformed files) and runs the Lua
reader, provider, host NSE and traceroute NSE tests. Nothing is downloaded:

```sh
make check
make clean           # removes only synthetic fixtures, never ./data/
```

In the Kali lab, we also exercised Nmap 7.991 against real GeoLite2 City,
Country and ASN databases: IPv4 and IPv6 host lookups, `mmdblookup` reference
comparisons, registration-only records, traceroute ASN enrichment, KML export,
and a 256-address local lookup batch. IPv6 lookup worked **without** an IPv6
route (`-Pn`); a real IPv6 traceroute was unavailable because the host network
had no global IPv6 address or default route. We make no claim that it was
tested over a working IPv6 path.

These integration results establish a useful baseline, not compatibility
with every database revision or every version of Nmap. If something goes
wrong, compare the same IP against `mmdblookup` using the same MMDB files
before blaming the network or the reader.

## Third-party PR snapshots

The `contrib/` directory is a source archive, not an install-all directory.
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
