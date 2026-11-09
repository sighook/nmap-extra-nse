local geolocation = require "geolocation"
local geoip = require "geoip"
local nmap = require "nmap"
local stdnse = require "stdnse"

description = [[
Geolocates a scanned host using an offline MaxMind DB (MMDB) database.
Provides City or Country details and optionally ASN information. When valid
coordinates exist, registers them for Nmap's existing geolocation map scripts.
]]

---
-- @usage
-- nmap -sn --script ip-geolocation-mmdb \
--   --script-args ip-geolocation-mmdb.db=/usr/share/GeoIP/GeoLite2-City.mmdb example.com
--
-- @args geolocation.provider Lookup provider (currently mmdb; offline only).
-- @args ip-geolocation-mmdb.db Path to GeoLite2 City or Country MMDB.
-- @args ip-geolocation-mmdb.asn Optional path to GeoLite2 ASN MMDB.
--
-- @output
-- | ip-geolocation-mmdb:
-- |   location: Testville, Testland
-- |   coordinates: 47.12345, 28.98765
-- |_  ASN: AS13335 (Test ISP)

author = "sighook and contributors"
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = {"safe", "discovery"}

local provider_name = stdnse.get_script_args("geolocation.provider") or "mmdb"
local db_path = stdnse.get_script_args(SCRIPT_NAME .. ".db") or
  nmap.fetchfile("nselib/data/GeoLite2-City.mmdb") or
  "/usr/share/GeoIP/GeoLite2-City.mmdb"
local asn_path = stdnse.get_script_args(SCRIPT_NAME .. ".asn")

hostrule = function(host)
  return host.ip ~= nil
end

action = function(host)
  local provider, err = geolocation.open({
    provider = provider_name, db = db_path, asn = asn_path,
  })
  if not provider then return "ERROR: " .. tostring(err) end
  local result, lookup_err = provider:lookup(host.ip)
  provider:close()
  if not result then return "ERROR: " .. tostring(lookup_err) end

  if result.status == "located" then
    geoip.add(host.ip, result.latitude, result.longitude)
  end

  local lines = {}
  if result.status == "non-public" or result.status == "no MMDB record" then
    lines[#lines + 1] = result.status
  else
    local location = {}
    -- Do not use ipairs on a sparse table: Country records have no city.
    if result.city then location[#location + 1] = result.city end
    if result.country then location[#location + 1] = result.country end
    if result.continent then location[#location + 1] = result.continent end
    if #location > 0 then
      lines[#lines + 1] = "location: " .. table.concat(location, ", ")
    end
    if result.registered_country and result.registered_country ~= result.country then
      lines[#lines + 1] = "registered country: " .. result.registered_country
    end
    if result.latitude then
      lines[#lines + 1] = string.format("coordinates: %.5f, %.5f",
        result.latitude, result.longitude)
      if result.accuracy_radius_km then
        lines[#lines + 1] = "accuracy radius: " ..
          tostring(result.accuracy_radius_km) .. " km"
      end
    end
    if result.asn then
      lines[#lines + 1] = "ASN: AS" .. tostring(result.asn) ..
        (result.organization and (" (" .. result.organization .. ")") or "")
    end
    if #lines == 0 then lines[#lines + 1] = result.status end
  end
  return result, stdnse.format_output(true, table.concat(lines, "\n"))
end
