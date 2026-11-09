local base = assert(arg[1])
package.path = base .. "/nselib/?.lua;" .. package.path
SCRIPT_NAME = "ip-geolocation-mmdb"

package.preload.ipOps = function()
  return {
    ip_to_str = function(ip)
      local octets = {}
      for p in ip:gmatch("[^.]+") do
        local n = tonumber(p)
        if not n or n > 255 or n < 0 then return nil, "bad IP" end
        octets[#octets+1] = string.char(n)
      end
      return #octets == 4 and table.concat(octets) or nil, "bad IP"
    end,
    isPrivate = function(ip) return ip:sub(1, 8) == "192.168." end,
    ip_in_range = function(ip, range)
      assert(range == "100.64.0.0/10")
      return ip:sub(1, 7) == "100.64."
    end,
  }
end
local registered = {}
local active_db = "city-24.mmdb"
package.preload.geoip = function()
  return { add = function(ip, lat, lon)
    registered[ip] = {lat, lon}
  end }
end
package.preload.nmap = function()
  return {fetchfile = function() return nil end}
end
package.preload.stdnse = function()
  return {
    get_script_args = function(key)
      if key == SCRIPT_NAME .. ".db" then
        return base .. "/tests/fixtures/" .. active_db
      end
      if key == SCRIPT_NAME .. ".asn" then
        return base .. "/tests/fixtures/asn.mmdb"
      end
    end,
    format_output = function(_, value) return value end,
  }
end

assert(loadfile(base .. "/scripts/ip-geolocation-mmdb.nse"))()
local host = { ip = "142.251.110.101" }
assert(hostrule(host))
local record, rendered = action(host)
assert(record.status == "located")
assert(record.asn == 13335)
assert(rendered:find("Testville", 1, true))
assert(rendered:find("AS13335", 1, true))
assert(registered[host.ip][1] == 47.12345)
local local_record, local_text = action({ip="192.168.100.1"})
assert(local_record.status == "non-public" and local_text == "non-public")
assert(registered["192.168.100.1"] == nil)

-- The same consumer must accept Country databases without fabricating points.
registered[host.ip] = nil
active_db = "country.mmdb"
assert(loadfile(base .. "/scripts/ip-geolocation-mmdb.nse"))()
local country, country_text = action(host)
assert(country.status == "country-only")
assert(country.country == "Testland" and country.latitude == nil)
assert(country_text:find("Testland", 1, true))
assert(registered[host.ip] == nil)
-- Registration-only records may identify the owner country, not an IP location.
active_db = "registered.mmdb"
assert(loadfile(base .. "/scripts/ip-geolocation-mmdb.nse"))()
local registered_record, registered_text = action(host)
assert(registered_record.status == "registered-only")
assert(registered_record.country == nil and registered_record.registered_country == "Registrationland")
assert(registered_text:find("registered country: Registrationland", 1, true))
assert(not registered_text:find("location:", 1, true))
assert(registered[host.ip] == nil)
print("Host NSE: PASS (located, country-only, registered-only, ASN, private, geoip publication)")
