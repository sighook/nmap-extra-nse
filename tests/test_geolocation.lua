local base = assert(arg[1])
package.path = base .. "/nselib/?.lua;" .. package.path

package.preload.ipOps = function()
  return {
    ip_to_str = function(ip)
      if ip == "2001:db8::1" then
        return string.char(0x20, 0x01, 0x0d, 0xb8) .. string.rep("\0", 11) .. "\1"
      end
      local values = {}
      for octet in ip:gmatch("[^.]+") do
        local n = tonumber(octet)
        if not n or n < 0 or n > 255 then return nil, "invalid IPv4" end
        values[#values + 1] = string.char(n)
      end
      if #values ~= 4 then return nil, "invalid IPv4" end
      return table.concat(values)
    end,
    isPrivate = function(ip)
      if ip == "bad-ip" then return nil, "invalid IP" end
      return ip:sub(1, 8) == "192.168."
    end,
    ip_in_range = function(ip, range)
      assert(range == "100.64.0.0/10")
      local first, second = ip:match("^(%d+)%.(%d+)%.")
      if not first then return nil, "invalid IPv4" end
      return tonumber(first) == 100 and tonumber(second) >= 64 and
        tonumber(second) <= 127
    end,
  }
end

local geolocation = require "geolocation"
local root = base .. "/tests/fixtures/"
local provider, err = geolocation.open({db=root .. "city-24.mmdb", asn=root .. "asn.mmdb"})
assert(provider, err)
local found = assert(provider:lookup("142.251.110.101"))
assert(found.status == "located")
assert(found.country == "Testland" and found.city == "Testville")
assert(found.latitude == 47.12345 and found.longitude == 28.98765)
assert(found.accuracy_radius_km == 1000)
assert(found.asn == 13335 and found.organization == "Test ISP")
assert(provider:lookup("142.251.110.101") == found, "lookup cache")
assert(assert(provider:lookup("100.64.87.254")).status == "non-public")
assert(assert(provider:lookup("192.168.100.1")).status == "non-public")
assert(assert(provider:lookup("1.1.1.1")).status == "no MMDB record")
assert(assert(provider:lookup("100.1.1.1")).status == "no MMDB record")
assert(provider:lookup("bad-ip") == nil)
local no_v6, v6_error = provider:lookup("2001:db8::1")
assert(no_v6 == nil and v6_error:find("IPv6"))
provider:close()
assert(provider:lookup("142.251.110.101") == nil)

provider = assert(geolocation.open({db=root .. "country.mmdb"}))
local country = assert(provider:lookup("142.251.110.101"))
assert(country.status == "country-only")
assert(country.country == "Testland" and country.continent == "Testcontinent")
assert(country.latitude == nil and country.longitude == nil)
assert(country.accuracy_radius_km == nil)
provider:close()

provider = assert(geolocation.open({db=root .. "registered.mmdb", asn=root .. "asn.mmdb"}))
local registered = assert(provider:lookup("142.251.110.101"))
assert(registered.status == "registered-only")
assert(registered.registered_country == "Registrationland")
assert(registered.country == nil and registered.latitude == nil)
assert(registered.asn == 13335)
provider:close()

provider = assert(geolocation.open({db=root .. "invalid-location.mmdb"}))
local invalid = assert(provider:lookup("142.251.110.101"))
assert(invalid.status == "country-only")
assert(invalid.latitude == nil, "must reject out-of-range coordinates")
assert(invalid.accuracy_radius_km == nil, "no radius without valid coordinates")
provider:close()

local absent, reason = geolocation.open({provider="geoplugin", db=root .. "city-24.mmdb"})
assert(absent == nil and reason:find("unsupported"))
absent, reason = geolocation.open({db=root .. "invalid.mmdb"})
assert(absent == nil and reason:find("marker"))
print("Geolocation provider: PASS (coordinates, country-only, ASN, CGNAT, errors)")
