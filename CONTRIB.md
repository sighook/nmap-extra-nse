# Nmap pull-request archive

The files under `contrib/` are **snapshots from other authors' Nmap PRs**, not
original scripts authored or maintained by this repository. Numeric filename
prefixes identify [nmap/nmap PRs](https://github.com/nmap/nmap/pulls).

Audited **2026-11-09** against upstream PR state and the Nmap GitHub source
tree. "Open" means GitHub reports the PR as open, not that the submission is
healthy, reviewed, or likely to merge. No listed PR was reported as merged.

There were **42 distinct PRs and 47 `.nse`-named files** in the original
collection. One file contains HTML rather than Lua, and one is actually Lua
data, not a runnable NSE script. Those and the TFTP filename overlap are
retained in `archive/`. No third-party code was silently rewritten in this
reorganization.

| Nmap PR | Snapshot files | PR status |
| --- | --- | --- |
| [#297](https://github.com/nmap/nmap/pull/297) | [`297-bittorrent-report.blacklist`](contrib/297-bittorrent-report.blacklist), [`297-bittorrent-report.nse`](contrib/297-bittorrent-report.nse) | open |
| [#548](https://github.com/nmap/nmap/pull/548) | [`548-tftp-fingerprints.nse`](archive/548-tftp-fingerprints.lua), [`548-tftp-version.nse`](archive/548-tftp-version.nse) | closed, unmerged |
| [#718](https://github.com/nmap/nmap/pull/718) | [`718-oracle-vuln-tns-poison.nse`](contrib/718-oracle-vuln-tns-poison.nse) | open |
| [#778](https://github.com/nmap/nmap/pull/778) | [`778-http-vuln-cve2015-1579.nse`](contrib/778-http-vuln-cve2015-1579.nse) | open |
| [#779](https://github.com/nmap/nmap/pull/779) | [`779-http-asuswrt-session-hijacking.nse`](contrib/779-http-asuswrt-session-hijacking.nse), [`779-http-asuswrt-xss.nse`](contrib/779-http-asuswrt-xss.nse) | open |
| [#783](https://github.com/nmap/nmap/pull/783) | [`783-http-vuln-cve2017-6527.nse`](contrib/783-http-vuln-cve2017-6527.nse) | open |
| [#828](https://github.com/nmap/nmap/pull/828) | [`828-iis-buffer-overflow.nse`](contrib/828-iis-buffer-overflow.nse) | open |
| [#951](https://github.com/nmap/nmap/pull/951) | [`951-winrm-auth-methods.nse`](contrib/951-winrm-auth-methods.nse) | open |
| [#1085](https://github.com/nmap/nmap/pull/1085) | [`1085-ms-sql-sp-execute-external-script.nse`](contrib/1085-ms-sql-sp-execute-external-script.nse) | open |
| [#1124](https://github.com/nmap/nmap/pull/1124) | [`1124-osgi-info.nse`](contrib/1124-osgi-info.nse) | open |
| [#1125](https://github.com/nmap/nmap/pull/1125) | [`1125-http-cisco-webvpn-cookie.nse`](contrib/1125-http-cisco-webvpn-cookie.nse) | open |
| [#1202](https://github.com/nmap/nmap/pull/1202) | [`1202-http-vuln-cve2018-8735.nse`](contrib/1202-http-vuln-cve2018-8735.nse) | open |
| [#1260](https://github.com/nmap/nmap/pull/1260) | [`1260-http-weblogic-brute.nse`](contrib/1260-http-weblogic-brute.nse) | closed, unmerged |
| [#1377](https://github.com/nmap/nmap/pull/1377) | [`1377-http-vuln-cve2018-10823.nse`](contrib/1377-http-vuln-cve2018-10823.nse) | open |
| [#1383](https://github.com/nmap/nmap/pull/1383) | [`1383-http-vuln-cve2018-9206.nse`](contrib/1383-http-vuln-cve2018-9206.nse) | open |
| [#1395](https://github.com/nmap/nmap/pull/1395) | [`1395-http-vuln-cve2018-7600.nse`](contrib/1395-http-vuln-cve2018-7600.nse) | open |
| [#1402](https://github.com/nmap/nmap/pull/1402) | [`1402-http-calibre.nse`](contrib/1402-http-calibre.nse) | open |
| [#1445](https://github.com/nmap/nmap/pull/1445) | [`1445-pcom-discover.nse`](contrib/1445-pcom-discover.nse) | open |
| [#1452](https://github.com/nmap/nmap/pull/1452) | [`1452-http-vuln-cve2015-6396.nse`](contrib/1452-http-vuln-cve2015-6396.nse) | open |
| [#1459](https://github.com/nmap/nmap/pull/1459) | [`1459-http-vuln-cve2019-1652.nse`](contrib/1459-http-vuln-cve2019-1652.nse) | open |
| [#1462](https://github.com/nmap/nmap/pull/1462) | [`1462-http-vuln-cve2018-11776.nse`](contrib/1462-http-vuln-cve2018-11776.nse) | open |
| [#1463](https://github.com/nmap/nmap/pull/1463) | [`1463-http-vuln-cve2017-9805.nse`](contrib/1463-http-vuln-cve2017-9805.nse) | open |
| [#1510](https://github.com/nmap/nmap/pull/1510) | [`1510-broadcast-mndp-discover.nse`](contrib/1510-broadcast-mndp-discover.nse) | open |
| [#1539](https://github.com/nmap/nmap/pull/1539) | [`1539-cip-tags-enum.nse`](contrib/1539-cip-tags-enum.nse) | open |
| [#1564](https://github.com/nmap/nmap/pull/1564) | [`1564-kubernetes-version.nse`](contrib/1564-kubernetes-version.nse) | open |
| [#1697](https://github.com/nmap/nmap/pull/1697) | [`1697-dns-any-query.nse`](contrib/1697-dns-any-query.nse) | open |
| [#1708](https://github.com/nmap/nmap/pull/1708) | [`1708-http-vuln-cve2019-11510.nse`](contrib/1708-http-vuln-cve2019-11510.nse) | open |
| [#1709](https://github.com/nmap/nmap/pull/1709) | [`1709-http-vuln-cve2018-13379.nse`](contrib/1709-http-vuln-cve2018-13379.nse) | open |
| [#1715](https://github.com/nmap/nmap/pull/1715) | [`1715-http-vuln-cve2019-11510.nse`](contrib/1715-http-vuln-cve2019-11510.nse) | open |
| [#1763](https://github.com/nmap/nmap/pull/1763) | [`1763-cisco-siet.nse`](contrib/1763-cisco-siet.nse) | open |
| [#1846](https://github.com/nmap/nmap/pull/1846) | [`1846-broadcast-pndcp-discovery.nse`](contrib/1846-broadcast-pndcp-discovery.nse) | closed, unmerged |
| [#1893](https://github.com/nmap/nmap/pull/1893) | [`1893-http-vuln-cve2019-19781.nse`](contrib/1893-http-vuln-cve2019-19781.nse) | open |
| [#1994](https://github.com/nmap/nmap/pull/1994) | [`1994-http-draytek-rce.nse`](contrib/1994-http-draytek-rce.nse) | open |
| [#2040](https://github.com/nmap/nmap/pull/2040) | [`2040-http-creds-finder.nse`](contrib/2040-http-creds-finder.nse), [`2040-http-ruby-environment.nse`](contrib/2040-http-ruby-environment.nse) | open |
| [#2147](https://github.com/nmap/nmap/pull/2147) | [`2147-http-sap-igs-xmlchart-xxe.nse`](contrib/2147-http-sap-igs-xmlchart-xxe.nse) | open |
| [#2169](https://github.com/nmap/nmap/pull/2169) | [`2169-weblogic-cve-2020-14882.nse`](contrib/2169-weblogic-cve-2020-14882.nse) | open |
| [#2248](https://github.com/nmap/nmap/pull/2248) | [`2248-zookeeper-info.nse`](contrib/2248-zookeeper-info.nse) | open |
| [#2249](https://github.com/nmap/nmap/pull/2249) | [`2249-tcp-uptime.nse`](contrib/2249-tcp-uptime.nse) | open |
| [#2308](https://github.com/nmap/nmap/pull/2308) | [`2308-http-vuln-cve2019-14322.nse`](contrib/2308-http-vuln-cve2019-14322.nse) | open |
| [#2334](https://github.com/nmap/nmap/pull/2334) | [`2334-x3-adxsrv.nse`](contrib/2334-x3-adxsrv.nse) | open |
| [#2447](https://github.com/nmap/nmap/pull/2447) | [`2447-dos_iis_2022_21907.nse`](contrib/2447-dos_iis_2022_21907.nse) | open |
| [#2450](https://github.com/nmap/nmap/pull/2450) | [`2450-RCE_CVE2021_42013.nse`](contrib/2450-RCE_CVE2021_42013.nse) | open |
| [#2451](https://github.com/nmap/nmap/pull/2451) | [`2451-RCE_CVE2021_41773.nse`](archive/2451-RCE_CVE2021_41773.html) | open |
| [#2546](https://github.com/nmap/nmap/pull/2546) | [`2546-cve-2022-40684.nse`](contrib/2546-cve-2022-40684.nse) | closed, unmerged |

## Exception notes

- **PR #548 (closed, unmerged)**: Nmap already ships a distinct
  `scripts/tftp-version.nse`. This old PR snapshot would collide with the
  installed filename; its `tftp-fingerprints.nse` is actually Lua data which
  the submission expects as `nselib/data/tftp-fingerprints.lua`. Both files
  live in `archive/` rather than an installable script collection. Similar
  filename does not mean the PR was merged.
- **PR #2451 (open)**: The saved `.nse` file contains a GitHub HTML page, not
  Lua source. Renamed to `.html` in `archive/` to prevent accidental execution;
  re-fetch actual Lua from the original PR if it is still useful.
- **PRs #1260, #1846, #2546 (closed, unmerged)**: their script snapshots
  remain in `contrib/` with attribution. Closed is not the same as accepted.
- **PR #297**: the `.blacklist` companion file is retained alongside its script.
- **PR #2040 and #779**: multiple script snapshots share a single PR number.

Of the original filenames, only `tftp-version.nse` exactly matches a script
name in the upstream Nmap source tree at the time of this audit. Similar
functionality under other names or incorporation of individual ideas was not
assessed; GitHub PR state alone cannot establish that.

## Maintenance policy

This is an archival inventory, not an automated upstream mirror. Before
installing a third-party script, inspect its behavior, NSE dependencies and
original PR, and compare with the current version bundled by Nmap. Do not
assume a historical exploitation/check script is harmless merely because it
uses Nmap's scripting engine.
