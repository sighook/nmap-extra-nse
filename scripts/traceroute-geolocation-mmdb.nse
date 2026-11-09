local geoip = require "geoip"
local geolocation = require "geolocation"
local io = require "io"
local nmap = require "nmap"
local stdnse = require "stdnse"
local tab = require "tab"

description = [[
Geolocates traceroute hops using a local MaxMind DB (GeoLite2-City.mmdb).
Works offline, without GeoPlugin or other web services. Locations describe IP
geolocation database estimates, not verified physical router positions.
]]

---
-- @usage
-- nmap -sn --traceroute --script traceroute-geolocation-mmdb \
--   --script-args traceroute-geolocation-mmdb.db=/usr/share/GeoIP/GeoLite2-City.mmdb example.com
--
-- @args geolocation.provider Lookup provider (currently mmdb; offline only).
-- @args traceroute-geolocation-mmdb.db Path to GeoLite2 City or Country MMDB.
-- @args traceroute-geolocation-mmdb.asn Optional path to GeoLite2 ASN database.
-- @args traceroute-geolocation-mmdb.kmlfile Optional KML file for point markers;
--       use with a single target to avoid overwriting between hosts.
--
-- @output
-- | traceroute-geolocation-mmdb:
-- |   HOP  RTT      ADDRESS              GEOLOCATION                   ASN
-- |   1    1.23 ms  192.168.1.1          non-public                    -
-- |   2    5.67 ms  203.0.113.20         no MMDB record                -
-- |_  3    8.90 ms  1.1.1.1              37.75,-97.82 United States   AS13335
--
-- @xmloutput
-- <table><elem key="hop">1</elem><elem key="ip">192.168.1.1</elem>
-- <elem key="status">non-public</elem></table>

author = "sighook and contributors"
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = { "safe", "discovery" }

-- Backend is selected via geolocation.provider; existing script arguments remain valid.
local basename = SCRIPT_NAME
local provider_name = stdnse.get_script_args("geolocation.provider") or "mmdb"
local db_path = stdnse.get_script_args(basename .. ".db") or
  nmap.fetchfile("nselib/data/GeoLite2-City.mmdb") or
  "/usr/share/GeoIP/GeoLite2-City.mmdb"
local asn_path = stdnse.get_script_args(basename .. ".asn")
local kml_path = stdnse.get_script_args(basename .. ".kmlfile")

hostrule = function(host)
  return host.traceroute ~= nil and #host.traceroute > 0
end

local function escape_xml(s)
  return tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):
    gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
end

local function write_kml(path, points)
  local f, err = io.open(path, "w")
  if not f then return nil, err end
  f:write('<?xml version="1.0" encoding="UTF-8"?>\n',
    '<kml xmlns="http://www.opengis.net/kml/2.2"><Document>\n')
  -- Individual markers: drawing straight line segments would imply a physical
  -- router route that an IP geolocation database cannot establish.
  for _, p in ipairs(points) do
    f:write('<Placemark><name>', escape_xml("Hop " .. p.hop .. ": " .. p.ip),
      '</name>')
    if p.accuracy_radius_km then
      f:write('<ExtendedData><Data name="accuracy_radius_km"><value>',
        tostring(p.accuracy_radius_km), '</value></Data></ExtendedData>')
    end
    f:write('<Point><coordinates>', string.format("%.7f,%.7f,0", p.lon, p.lat),
      '</coordinates></Point></Placemark>\n')
  end
  f:write('</Document></kml>\n')
  f:close()
  return true
end

local function run(host)
  local provider, err = geolocation.open({
    provider = provider_name, db = db_path, asn = asn_path,
  })
  if not provider then return "ERROR: " .. err end

  local output = tab.new(5)
  tab.addrow(output, "HOP", "RTT", "ADDRESS", "GEOLOCATION", "ASN")
  local structured, points = {}, {}
  local problems = {}
  for hop_number, hop in ipairs(host.traceroute) do
    if not hop.ip then
      tab.addrow(output, hop_number, "...", "...", "-", "-")
      structured[#structured + 1] = { hop = hop_number, status = "timeout" }
    else
      local ip = hop.ip
      local rtt = tonumber(hop.srtt) and (tonumber(hop.srtt) * 1000) or nil
      local name = hop.name and hop.name ~= ip and hop.name or nil
      local row = { hop = hop_number, ip = ip, hostname = name, rtt = rtt }
      local label = name and (name .. " (" .. ip .. ")") or ip
      local geographic, asn_label = "no MMDB record", "-"
      local result, lookup_err = provider:lookup(ip)
      if not result then
        problems[#problems + 1] = ip .. ": " .. tostring(lookup_err)
        geographic = "lookup error"
        row.status = "lookup error"
      else
        row.status = result.status
        if result.asn then
          asn_label = "AS" .. tostring(result.asn)
          row.asn = result.asn
          row.organization = result.organization
        end
        if result.status == "located" then
          geographic = string.format("%.4f,%.4f %s%s", result.latitude,
            result.longitude, result.country or "Unknown",
            result.city and (" (" .. result.city .. ")") or "")
          row.latitude, row.longitude = result.latitude, result.longitude
          row.accuracy_radius_km = result.accuracy_radius_km
          points[#points + 1] = { hop = hop_number, ip = ip,
            lat = result.latitude, lon = result.longitude,
            accuracy_radius_km = result.accuracy_radius_km }
          geoip.add(ip, result.latitude, result.longitude)
        elseif result.status == "country-only" then
          geographic = result.country or result.continent or result.city
        elseif result.status == "registered-only" then
          geographic = "registered: " .. result.registered_country
        elseif result.status == "asn-only" then
          geographic = "no geographic record"
        elseif result.status == "non-public" then
          geographic = "non-public"
        end
        row.country, row.city, row.continent = result.country,
          result.city, result.continent
        row.registered_country = result.registered_country
      end
      tab.addrow(output, hop_number, rtt and string.format("%.2f ms", rtt) or "-",
        label, geographic, asn_label)
      structured[#structured + 1] = row
    end
  end
  provider:close()
  local display = tab.dump(output)
  if kml_path then
    local ok, why = write_kml(kml_path, points)
    display = display .. "\n" .. (ok and ("KML written: " .. kml_path) or
      ("ERROR writing KML: " .. tostring(why)))
  end
  if #problems > 0 then
    display = display .. "\nERROR: " .. table.concat(problems, "; ")
  end
  return structured, stdnse.format_output(true, display)
end

action = run
