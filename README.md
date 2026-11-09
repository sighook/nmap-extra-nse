# nmap-extra-nse

Personal NSE scripts and an archive of third-party scripts proposed to Nmap.

The two collections have different ownership and maintenance expectations:

- **`scripts/`, `nselib/`, `tests/`** — independently maintained code in this repository.
- **`contrib/`** — snapshots copied from upstream [Nmap pull requests](https://github.com/nmap/nmap/pulls); the numeric prefix is the PR number, **not a version**. Original authorship and licensing remain with the contributors.
- **`archive/`** — broken snapshots or files conflicting with an already-shipped Nmap script. Retained for provenance; **do not install**.

See [CONTRIB.md](CONTRIB.md) for the upstream status audit and exceptions.
These files are **not all part of official Nmap**. PR state is not an assessment of
security, correctness, or compatibility with current NSE libraries.

## Offline traceroute geolocation (maintained)

`traceroute-geolocation-mmdb.nse` annotates Nmap traceroute hops using a local
GeoLite2 City MMDB. An optional GeoLite2 ASN MMDB supplies ASN details. It does
not call GeoPlugin or any other remote API. `nselib/mmdb.lua` is a bounded Lua
MMDB reader. The databases themselves are **not** redistributed here.

The City database is required; ASN is optional. The Country database is not
used by this script, but may be useful to other tools. The examples below use
[P3TERX/GeoLite.mmdb](https://github.com/P3TERX/GeoLite.mmdb), a third-party
mirror of MaxMind's GeoLite2 data. For regular updates, prefer MaxMind's
[official `geoipupdate` instructions](https://dev.maxmind.com/geoip/updating-databases/)
(requires a MaxMind account and license key). Keep the databases up to date
and follow the applicable [GeoLite2 license](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data/).

### Docker

After installing Nmap, `curl`, and CA certificates in your image, add these
lines to its Dockerfile:

```dockerfile
ARG DB_URL="https://github.com/P3TERX/GeoLite.mmdb/raw/download"
RUN mkdir -p /usr/share/nmap/nselib/data && \
    curl -fLsS --retry 3 -o /usr/share/nmap/nselib/data/GeoLite2-ASN.mmdb "${DB_URL}/GeoLite2-ASN.mmdb" && \
    curl -fLsS --retry 3 -o /usr/share/nmap/nselib/data/GeoLite2-City.mmdb "${DB_URL}/GeoLite2-City.mmdb" && \
    curl -fLsS --retry 3 -o /usr/share/nmap/nselib/data/GeoLite2-Country.mmdb "${DB_URL}/GeoLite2-Country.mmdb"

COPY nselib/mmdb.lua /usr/share/nmap/nselib/mmdb.lua
COPY scripts/traceroute-geolocation-mmdb.nse /usr/share/nmap/scripts/traceroute-geolocation-mmdb.nse
```

The `COPY` source paths are relative to the Docker build context; prefix them
with the repository directory if necessary. The `-f` option prevents `curl`
from silently saving an HTTP error response as a database. Use an absolute
`--script` path: there is no need to run `nmap --script-updatedb`, which may
fail in restricted container builds due to executable file capabilities.

### Manual installation

From the repository root, install the script and its library:

```sh
sudo install -m 644 nselib/mmdb.lua /usr/share/nmap/nselib/mmdb.lua
sudo install -m 644 scripts/traceroute-geolocation-mmdb.nse \
  /usr/share/nmap/scripts/traceroute-geolocation-mmdb.nse
```

Download the MMDB files into your current directory, then install them:

```sh
DB_URL="https://github.com/P3TERX/GeoLite.mmdb/raw/download"
curl -fLsS --retry 3 -o GeoLite2-ASN.mmdb "${DB_URL}/GeoLite2-ASN.mmdb" &&
curl -fLsS --retry 3 -o GeoLite2-City.mmdb "${DB_URL}/GeoLite2-City.mmdb" &&
curl -fLsS --retry 3 -o GeoLite2-Country.mmdb "${DB_URL}/GeoLite2-Country.mmdb" &&
sudo install -d -m 755 /usr/share/nmap/nselib/data &&
sudo install -m 644 GeoLite2-ASN.mmdb GeoLite2-City.mmdb GeoLite2-Country.mmdb \
  /usr/share/nmap/nselib/data/
```

### Run

The same invocation works on the host or inside a container:

```sh
nmap -sn --traceroute \
  --script /usr/share/nmap/scripts/traceroute-geolocation-mmdb.nse \
  --script-args 'traceroute-geolocation-mmdb.db=/usr/share/nmap/nselib/data/GeoLite2-City.mmdb,traceroute-geolocation-mmdb.asn=/usr/share/nmap/nselib/data/GeoLite2-ASN.mmdb' \
  example.com
```

A `traceroute-geolocation-mmdb.kmlfile=/path/route.kml` argument writes KML
**point markers**, not invented physical links between routers. Use a distinct
file per host to avoid overwriting. Private and RFC 6598 shared-space hops are
classified as non-public; public IPs absent from MMDB are reported separately.
IP geolocation estimates do not establish the physical path of a packet.

### Tests

The test fixtures are synthetic: no GeoLite database or network access is
required. The Python script generates data; the actual reader is tested by Lua.

```sh
mkdir -p tests/fixtures
python3 tests/make_fixture.py tests/fixtures
lua5.4 tests/test_mmdb.lua "$PWD"
lua5.4 tests/test_nse.lua "$PWD"
```

The script has also been exercised with a real GeoLite2 database in a Kali
7.991 container, but treat that as a manual integration smoke test, **not** a
claim that all datasets or Nmap versions have been validated.

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
