local base = assert(arg[1])
package.path = base .. "/nselib/?.lua;" .. package.path
SCRIPT_NAME = "traceroute-geolocation-mmdb"

package.preload.ipOps = function()
  return {
    ip_to_str = function(ip)
      local octets = {}
      for part in ip:gmatch("[^.]+") do
        local v = tonumber(part)
        if not v or v < 0 or v > 255 then return nil, "bad IP" end
        octets[#octets+1] = string.char(v)
      end
      return #octets == 4 and table.concat(octets) or nil, "bad IP"
    end,
    isPrivate = function(ip) return ip:sub(1,4) == "192." end,
    ip_in_range = function(ip, range)
      assert(range == "100.64.0.0/10")
      local first, second = ip:match("^(%d+)%.(%d+)%.")
      return tonumber(first) == 100 and tonumber(second) >= 64 and
        tonumber(second) <= 127
    end,
  }
end
local registered = {}
local active_db = "city-24.mmdb"
local available_asn = true
local asn_override
package.preload.geoip = function()
  return { add = function(ip, latitude, longitude)
    registered[ip] = {latitude, longitude}
  end }
end
package.preload.nmap = function()
  return { fetchfile = function(name)
    if name == "nselib/data/GeoLite2-ASN.mmdb" and available_asn then
      return base .. "/tests/fixtures/asn.mmdb"
    end
  end }
end
package.preload.stdnse = function()
  return {
    get_script_args = function(key)
      if key == SCRIPT_NAME .. ".db" then return base .. "/tests/fixtures/" .. active_db end
      if key == SCRIPT_NAME .. ".asn" then return asn_override end
      if key == SCRIPT_NAME .. ".kmlfile" then return base .. "/tests/fixtures/output.kml" end
    end,
    format_output = function(_, output) return output end,
  }
end
package.preload.tab = function()
  return {
    new = function() return {} end,
    addrow = function(t, ...) t[#t+1] = {...} end,
    dump = function(t)
      local rows = {}
      for _, row in ipairs(t) do
        for i, v in ipairs(row) do row[i] = tostring(v) end
        rows[#rows+1] = table.concat(row, " | ")
      end
      return table.concat(rows, "\n")
    end,
  }
end

assert(loadfile(base .. "/scripts/traceroute-geolocation-mmdb.nse"))()
local host = {traceroute = {
  {ip="192.168.100.1", srtt=0.00166},
  {ip="100.64.87.254", srtt=0.00293},
  {ip="37.233.0.23", srtt=0.0068},
  {ip="142.251.110.101", srtt=0.045, name="google.example"},
  {},
}}
assert(hostrule(host))
local rows, display = action(host)
assert(#rows == 5)
assert(rows[1].status == "non-public")
assert(rows[2].status == "non-public")
assert(rows[3].status == "no MMDB record")
assert(rows[4].status == "located")
assert(rows[4].country == "Testland" and rows[4].city == "Testville")
assert(rows[4].latitude == 47.12345)
assert(rows[4].accuracy_radius_km == 1000)
assert(rows[4].asn == 13335 and rows[4].organization == "Test ISP")
assert(registered["142.251.110.101"][1] == 47.12345)
assert(registered["192.168.100.1"] == nil)
assert(registered["100.64.87.254"] == nil)
assert(rows[5].status == "timeout")
assert(display:find("Testland") and display:find("non%-public"))
local f = assert(io.open(base .. "/tests/fixtures/output.kml", "r"))
local kml = f:read("*a"); f:close()
assert(kml:find("142.251.110.101", 1, true))
assert(kml:find("28.9876500,47.1234500,0", 1, true))
assert(kml:find('<Data name="accuracy_radius_km"><value>1000</value></Data>', 1, true))
assert(not kml:find("100.64.87.254", 1, true))
-- An ASN/registration record must not be presented as physical geography.
active_db = "registered.mmdb"
registered["142.251.110.101"] = nil
assert(loadfile(base .. "/scripts/traceroute-geolocation-mmdb.nse"))()
local registered_rows, registered_display = action(host)
assert(registered_rows[4].status == "registered-only")
assert(registered_rows[4].country == nil)
assert(registered_rows[4].registered_country == "Registrationland")
assert(registered_display:find("registered: Registrationland", 1, true))
assert(registered["142.251.110.101"] == nil)
local rf = assert(io.open(base .. "/tests/fixtures/output.kml", "r"))
local rxml = rf:read("*a"); rf:close()
assert(not rxml:find("142.251.110.101", 1, true))

-- The initial lookup found ASN through nmap.fetchfile(), not script args.
-- Without a bundled ASN database, geographic lookup is still available.
active_db = "city-24.mmdb"
available_asn = false
assert(loadfile(base .. "/scripts/traceroute-geolocation-mmdb.nse"))()
local without_asn_rows, without_asn_text = action(host)
assert(without_asn_rows[4].status == "located" and without_asn_rows[4].asn == nil)
assert(not without_asn_text:find("AS13335", 1, true))

-- An explicit ASN path works without automatic discovery.
asn_override = base .. "/tests/fixtures/asn.mmdb"
assert(loadfile(base .. "/scripts/traceroute-geolocation-mmdb.nse"))()
local explicit_rows = action(host)
assert(explicit_rows[4].asn == 13335)

-- An invalid explicit path is an error, not an invitation to fall back.
available_asn = true
asn_override = base .. "/tests/fixtures/invalid.mmdb"
assert(loadfile(base .. "/scripts/traceroute-geolocation-mmdb.nse"))()
local err_text = action(host)
assert(type(err_text) == "string" and err_text:find("ERROR:", 1, true))

print("NSE integration: PASS (private/CGNAT, missing, found, timeout, ASN discovery/override, KML, registration)")
