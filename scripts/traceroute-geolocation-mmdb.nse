local ipOps = require "ipOps"
local io = require "io"
local mmdb = require "mmdb"
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
-- @args traceroute-geolocation-mmdb.db Path to GeoLite2 City database.
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

local basename = SCRIPT_NAME
local db_path = stdnse.get_script_args(basename .. ".db") or
  nmap.fetchfile("nselib/data/GeoLite2-City.mmdb") or
  "/usr/share/GeoIP/GeoLite2-City.mmdb"
local asn_path = stdnse.get_script_args(basename .. ".asn")
local kml_path = stdnse.get_script_args(basename .. ".kmlfile")

hostrule = function(host)
  return host.traceroute ~= nil and #host.traceroute > 0
end

local function nonpublic(ip)
  local private = ipOps.isPrivate(ip)
  if private then return true end
  -- ipOps.isPrivate() does not currently include shared address space.
  if not ip:find(":", 1, true) then
    return ipOps.ip_in_range(ip, "100.64.0.0/10") == true
  end
  return false
end

local function description_of(record)
  if type(record) ~= "table" then return nil end
  local location = record.location
  if type(location) ~= "table" or
     type(location.latitude) ~= "number" or
     type(location.longitude) ~= "number" then
    return nil
  end
  local country = record.country or record.registered_country or {}
  local city = record.city or {}
  local function english(value)
    return type(value) == "table" and type(value.names) == "table" and
      value.names.en or nil
  end
  return {
    lat = location.latitude,
    lon = location.longitude,
    country = english(country),
    city = english(city),
  }
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
      '</name><Point><coordinates>', string.format("%.7f,%.7f,0", p.lon, p.lat),
      '</coordinates></Point></Placemark>\n')
  end
  f:write('</Document></kml>\n')
  f:close()
  return true
end

local function run(host)
  local db, err = mmdb.open(db_path)
  if not db then return "ERROR: " .. err end
  local asn, aerr
  if asn_path then
    asn, aerr = mmdb.open(asn_path)
    if not asn then db:close(); return "ERROR: " .. aerr end
  end

  local output = tab.new(5)
  tab.addrow(output, "HOP", "RTT", "ADDRESS", "GEOLOCATION", "ASN")
  local structured, points, cache = {}, {}, {}
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
      if nonpublic(ip) then
        geographic = "non-public"
        row.status = "non-public"
      else
        if not cache[ip] then
          local ok, record = pcall(db.lookup, db, ip)
          if not ok then
            problems[#problems + 1] = ip .. ": " .. tostring(record)
            record = nil
          end
          local geo = description_of(record)
          local number, organization
          if asn then
            local aok, arecord = pcall(asn.lookup, asn, ip)
            if not aok then
              problems[#problems + 1] = ip .. " ASN: " .. tostring(arecord)
            elseif type(arecord) == "table" then
              number = arecord.autonomous_system_number
              organization = arecord.autonomous_system_organization
            end
          end
          cache[ip] = { geo = geo, number = number, organization = organization }
        end
        local lookup = cache[ip]
        if lookup.number then
          asn_label = "AS" .. tostring(lookup.number)
          row.asn = lookup.number
          row.organization = lookup.organization
        end
        if lookup.geo then
          local geo = lookup.geo
          geographic = string.format("%.4f,%.4f %s%s", geo.lat, geo.lon,
            geo.country or "Unknown", geo.city and (" (" .. geo.city .. ")") or "")
          row.latitude, row.longitude = geo.lat, geo.lon
          row.country, row.city = geo.country, geo.city
          points[#points + 1] = { hop = hop_number, ip = ip,
            lat = geo.lat, lon = geo.lon }
          row.status = "located"
        else
          row.status = "no MMDB record"
        end
      end
      tab.addrow(output, hop_number, rtt and string.format("%.2f ms", rtt) or "-",
        label, geographic, asn_label)
      structured[#structured + 1] = row
    end
  end
  db:close()
  if asn then asn:close() end
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
