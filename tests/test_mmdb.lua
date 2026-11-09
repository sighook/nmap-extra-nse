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
  assert(record.location.accuracy_radius == 1000)
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
-- Opening a malformed database must fail cleanly and close the file it opened.
local real_open, last_file = io.open, nil
io.open = function(path, mode)
  local handle, why = real_open(path, mode)
  if handle then last_file = handle end
  return handle, why
end
local invalid, separator_err = mmdb.open(base .. "/tests/fixtures/bad-separator.mmdb")
io.open = real_open
assert(invalid == nil and separator_err:find("invalid data section separator", 1, true))
assert(last_file and io.type(last_file) == "closed file", "failed open must close file")

for filename, expected in pairs({
  ["bad-tree-size.mmdb"] = "invalid tree size",
  ["bad-version.mmdb"] = "unsupported or invalid metadata",
}) do
  local value, reason = mmdb.open(base .. "/tests/fixtures/" .. filename)
  assert(value == nil and reason:find(expected, 1, true), filename .. ": " .. tostring(reason))
end

-- Corrupted records should fail within the decoder's budgets, not loop,
-- allocate the advertised payload, or read through the metadata section.
for filename, expected in pairs({
  ["pointer-outside.mmdb"] = "data pointer outside section",
  ["truncated-value.mmdb"] = "offset outside database",
  ["cyclic-pointer.mmdb"] = "maximum nesting depth exceeded",
  ["oversized-value.mmdb"] = "decoded payload limit exceeded",
  ["oversized-container.mmdb"] = "container too large",
  ["unsupported-type.mmdb"] = "unsupported data type",
}) do
  local reader, why = mmdb.open(base .. "/tests/fixtures/" .. filename)
  assert(reader, filename .. ": " .. tostring(why))
  local ok, problem = pcall(reader.lookup, reader, "142.251.110.101")
  assert(not ok and tostring(problem):find(expected, 1, true),
    filename .. ": " .. tostring(problem))
  reader:close()
end

local closed = assert(mmdb.open(base .. "/tests/fixtures/city-24.mmdb"))
local handle = closed.file
closed:close()
closed:close()  -- Idempotent cleanup.
assert(io.type(handle) == "closed file", "close must release the descriptor")
local after_close, close_reason = closed:lookup("142.251.110.101")
assert(after_close == nil and close_reason == "MMDB reader is closed")
print("MMDB reader: PASS (records, corrupt files, limits, file lifecycle)")
