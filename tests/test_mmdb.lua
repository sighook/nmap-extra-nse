local base = assert(arg[1])
package.path = base .. "/nselib/?.lua;" .. package.path

package.preload.ipOps = function()
  return {
    ip_to_str = function(ip)
      if ip == "2001:db8::1" then
        return string.char(0x20, 0x01, 0x0d, 0xb8) .. string.rep("\0", 11) .. "\1"
      end
      local bytes = {}
      for piece in ip:gmatch("[^.]+") do
        local x = tonumber(piece)
        if not x or x < 0 or x > 255 then return nil, "invalid IP" end
        bytes[#bytes + 1] = string.char(x)
      end
      if #bytes ~= 4 then return nil, "invalid IP" end
      return table.concat(bytes)
    end
  }
end

local mmdb = require "mmdb"
for _, size in ipairs({24, 28, 32}) do
  local db, err = mmdb.open(base .. "/tests/fixtures/city-" .. size .. ".mmdb")
  assert(db, err)
  assert(db.metadata.record_size == size)
  local record, extra = db:lookup("142.251.110.101")
  assert(record and extra == nil, "lookup must return only record or nil,error")
  assert(record.country.names.en == "Testland", "country " .. size)
  assert(record.city.names.en == "Testville", "city " .. size)
  assert(math.abs(record.location.latitude - 47.12345) < 1e-7)
  assert(math.abs(record.location.longitude - 28.98765) < 1e-7)
  assert(db:lookup("1.1.1.1") == nil)
  db:close()
end
local v6 = assert(mmdb.open(base .. "/tests/fixtures/city-v6.mmdb"))
assert(v6:lookup("2001:db8::1") == nil)
assert(v6:lookup("142.251.110.101").country.names.en == "Testland")
v6:close()
local pointer = assert(mmdb.open(base .. "/tests/fixtures/pointer.mmdb"))
local record = assert(pointer:lookup("142.251.110.101"))
assert(record.first == "referenced" and record.other == "inline")
pointer:close()
local broken, err = mmdb.open(base .. "/tests/fixtures/invalid.mmdb")
assert(broken == nil and err:find("marker"))
print("MMDB reader: PASS (24/28/32, IPv4 in IPv6, pointers, missing data, malformed DB)")
