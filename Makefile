# Only the maintained geolocation code is installed. contrib/ and archive/ are
# historical snapshots, not a collection of scripts to copy into Nmap.

NMAP_DATADIR ?= /usr/share/nmap
DB_DIR ?= $(CURDIR)/data
DB_URL ?= https://github.com/P3TERX/GeoLite.mmdb/raw/download

CURL ?= curl
MMDBLOOKUP ?= mmdblookup
INSTALL ?= install
PYTHON ?= python3
LUA ?= lua5.4

DATABASES := GeoLite2-City GeoLite2-Country GeoLite2-ASN

.DEFAULT_GOAL := help
.PHONY: help show-config fetch check-db install install-nse install-db check test clean

help:
	@printf '%s\n' \
	  'make check           Run the offline Lua tests (synthetic MMDB fixtures)' \
	  'make fetch           Download and validate GeoLite2 databases into data/' \
	  'make install         Install maintained NSE code and downloaded databases' \
	  'make install-nse     Install the two scripts and their Lua libraries only' \
	  'make install-db      Install downloaded GeoLite2 databases only' \
	  'make show-config     Print source and destination paths' \
	  'make clean           Remove generated test fixtures (not downloaded data)'

show-config:
	@printf 'Nmap data directory: %s\nGeoLite2 downloads: %s\nDownload source: %s\nInstallation root: %s\n' \
	  '$(NMAP_DATADIR)' '$(DB_DIR)' '$(DB_URL)' '$(DESTDIR)'

# Download into a temporary directory and validate ALL files before replacing
# any existing downloads. A failed request must not destroy a working copy.
fetch:
	@command -v '$(CURL)' >/dev/null || { echo 'Missing curl' >&2; exit 1; }
	@command -v '$(MMDBLOOKUP)' >/dev/null || { echo 'Missing mmdblookup (install mmdb-bin)' >&2; exit 1; }
	@mkdir -p '$(DB_DIR)'
	@set -eu; \
	  tmp=$$(mktemp -d '$(DB_DIR)/.fetch.XXXXXX'); \
	  trap 'rm -rf "$$tmp"' 0 HUP INT TERM; \
	  for name in $(DATABASES); do \
	    echo "Fetching $$name.mmdb"; \
	    '$(CURL)' -fLsS --retry 3 -o "$$tmp/$$name.mmdb" '$(DB_URL)'/"$$name.mmdb"; \
	    if ! '$(MMDBLOOKUP)' --file "$$tmp/$$name.mmdb" --ip 8.8.8.8 >/dev/null 2>&1; then \
	      echo "Invalid MMDB download: $$name.mmdb" >&2; exit 1; \
	    fi; \
	  done; \
	  for name in $(DATABASES); do \
	    mv -f "$$tmp/$$name.mmdb" '$(DB_DIR)'/"$$name.mmdb"; \
	  done; \
	  echo 'GeoLite2 downloads are ready.'

check-db:
	@command -v '$(MMDBLOOKUP)' >/dev/null || { echo 'Missing mmdblookup (install mmdb-bin)' >&2; exit 1; }
	@set -eu; \
	  for name in $(DATABASES); do \
	    file='$(DB_DIR)'/"$$name.mmdb"; \
	    if [ ! -r "$$file" ]; then \
	      echo "Missing $$file (run make fetch first)" >&2; exit 1; \
	    fi; \
	    if ! '$(MMDBLOOKUP)' --file "$$file" --ip 8.8.8.8 >/dev/null 2>&1; then \
	      echo "Invalid MMDB file: $$file" >&2; exit 1; \
	    fi; \
	  done

# Install never downloads. Fail early if the local databases aren't ready.
install: check-db install-nse install-db

install-nse:
	@'$(INSTALL)' -d '$(DESTDIR)$(NMAP_DATADIR)/nselib' '$(DESTDIR)$(NMAP_DATADIR)/scripts'
	@'$(INSTALL)' -m 644 nselib/mmdb.lua nselib/geolocation.lua '$(DESTDIR)$(NMAP_DATADIR)/nselib/'
	@'$(INSTALL)' -m 644 scripts/ip-geolocation-mmdb.nse scripts/traceroute-geolocation-mmdb.nse '$(DESTDIR)$(NMAP_DATADIR)/scripts/'

install-db: check-db
	@'$(INSTALL)' -d '$(DESTDIR)$(NMAP_DATADIR)/nselib/data'
	@set -eu; \
	  for name in $(DATABASES); do \
	    '$(INSTALL)' -m 644 '$(DB_DIR)'/"$$name.mmdb" '$(DESTDIR)$(NMAP_DATADIR)/nselib/data/'; \
	  done

check: test

test:
	@mkdir -p tests/fixtures
	@'$(PYTHON)' tests/make_fixture.py tests/fixtures
	@set -e; for t in tests/test_*.lua; do '$(LUA)' "$$t" '$(CURDIR)'; done

clean:
	@rm -rf tests/fixtures
