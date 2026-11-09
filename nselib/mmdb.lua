--- Read MaxMind DB (MMDB) files without external programs or Lua C modules.
-- Binary format: https://maxmind.github.io/MaxMind-DB/
-- Deliberately bounded decoding: untrusted databases must not exhaust NSE.
local ipOps = require "ipOps"

local mmdb = {}
local marker = "\171\205\239MaxMind.com"
local MAX_VALUES, MAX_BYTES, MAX_DEPTH = 16384, 2 * 1024 * 1024, 64

local function fail(message)
  error("MMDB: " .. message, 0)
end

local function read_at(db, offset, size, stop)
  stop = stop or db.file_size
  if type(offset) ~= "number" or type(size) ~= "number" or
     offset < 0 or size < 0 or offset + size > stop then
    fail("offset outside database")
  end
  if not db.file:seek("set", offset) then fail("seek failed") end
  local data = db.file:read(size)
  if not data or #data ~= size then fail("short read") end
  return data
end

local function unsigned(bytes)
  local value = 0
  for i = 1, #bytes do
    value = value * 256 + bytes:byte(i)
  end
  return value
end

local function decoder(db, offset, base, stop, budget, depth)
  if depth > MAX_DEPTH then fail("maximum nesting depth exceeded") end
  budget.values = budget.values + 1
  if budget.values > MAX_VALUES then fail("maximum decoded value count exceeded") end

  local ctrl = read_at(db, offset, 1, stop):byte()
  offset = offset + 1
  local kind = ctrl >> 5
  local size = ctrl & 31

  if kind == 1 then
    -- Pointer payload size and the embedded high bits share the low 5 bits.
    local count = (size >> 3) + 1
    local high = size & 7
    local bytes = read_at(db, offset, count, stop)
    local pointer = unsigned(bytes)
    if count < 4 then
      pointer = high * 256 ^ count + pointer
      if count == 2 then pointer = pointer + 2048 end
      if count == 3 then pointer = pointer + 526336 end
    end
    local after = offset + count
    -- Pointers are relative to the data/metadata section, not the file.
    local value = decoder(db, base + pointer, base, stop, budget, depth + 1)
    return value, after
  end

  if kind == 0 then
    kind = read_at(db, offset, 1, stop):byte() + 7
    offset = offset + 1
  end
  if size == 29 then
    size = 29 + unsigned(read_at(db, offset, 1, stop))
    offset = offset + 1
  elseif size == 30 then
    size = 285 + unsigned(read_at(db, offset, 2, stop))
    offset = offset + 2
  elseif size == 31 then
    size = 65821 + unsigned(read_at(db, offset, 3, stop))
    offset = offset + 3
  end

  if kind == 7 or kind == 11 then
    -- Maps and arrays encode element counts, not payload byte lengths.
    local needed = (kind == 7) and (size * 2) or size
    if budget.values + needed > MAX_VALUES then fail("container too large") end
    local value = {}
    if kind == 7 then
      for _ = 1, size do
        local key
        key, offset = decoder(db, offset, base, stop, budget, depth + 1)
        if type(key) ~= "string" then fail("non-string map key") end
        value[key], offset = decoder(db, offset, base, stop, budget, depth + 1)
      end
    else
      for i = 1, size do
        value[i], offset = decoder(db, offset, base, stop, budget, depth + 1)
      end
    end
    return value, offset
  end

  if kind == 14 then
    if size > 1 then fail("invalid boolean") end
    return size == 1, offset
  end

  if size > MAX_BYTES or budget.bytes + size > MAX_BYTES then
    fail("decoded payload limit exceeded")
  end
  budget.bytes = budget.bytes + size
  local bytes = read_at(db, offset, size, stop)
  offset = offset + size

  if kind == 2 or kind == 4 then return bytes, offset end
  if kind == 3 then
    if size ~= 8 then fail("invalid double") end
    return string.unpack(">d", bytes), offset
  end
  if kind == 15 then
    if size ~= 4 then fail("invalid float") end
    return string.unpack(">f", bytes), offset
  end
  if kind == 5 or kind == 6 or kind == 9 or kind == 10 then
    -- Metadata timestamps fit in Lua integers; unknown huge 128-bit values
    -- cannot be represented precisely and must not be misreported.
    if size > 8 then fail("integer wider than 64 bits unsupported") end
    return unsigned(bytes), offset
  end
  if kind == 8 then
    if size > 4 then fail("invalid signed integer") end
    local n = unsigned(bytes)
    if size == 4 and n >= 0x80000000 then n = n - 0x100000000 end
    return n, offset
  end
  fail("unsupported data type " .. tostring(kind))
end

local function decode(db, offset, base, stop)
  return decoder(db, offset, base, stop, { values = 0, bytes = 0 }, 0)
end

local Reader = {}
Reader.__index = Reader

function Reader:close()
  if self.file then self.file:close(); self.file = nil end
end

local function node_record(db, node, bit)
  if node < 0 or node >= db.node_count then fail("invalid tree node") end
  local data = read_at(db, node * db.node_bytes, db.node_bytes, db.tree_bytes)
  if db.record_size == 24 then
    return unsigned(data:sub(bit * 3 + 1, bit * 3 + 3))
  elseif db.record_size == 28 then
    if bit == 0 then
      return (data:byte(4) >> 4) * 0x1000000 + unsigned(data:sub(1, 3))
    end
    return (data:byte(4) & 15) * 0x1000000 + unsigned(data:sub(5, 7))
  end
  return unsigned(data:sub(bit * 4 + 1, bit * 4 + 4))
end

function Reader:lookup(ip)
  if not self.file then return nil, "MMDB reader is closed" end
  local bytes, err = ipOps.ip_to_str(ip)
  if not bytes then return nil, err or "invalid IP address" end
  if #bytes ~= 4 and #bytes ~= 16 then return nil, "invalid IP length" end
  if self.ip_version == 4 and #bytes == 16 then return nil, "IPv6 not in IPv4 database" end

  -- IPv4 is represented as ::/96 inside MMDB IPv6 search trees.
  if self.ip_version == 6 and #bytes == 4 then
    bytes = string.rep("\0", 12) .. bytes
  end
  local node = 0
  for i = 1, #bytes do
    local byte = bytes:byte(i)
    for bit = 7, 0, -1 do
      if node >= self.node_count then break end
      node = node_record(self, node, (byte >> bit) & 1)
    end
    if node >= self.node_count then break end
  end
  if node == self.node_count then return nil end
  if node < self.node_count then fail("tree ended without a value") end
  if node < self.node_count + 16 then fail("invalid data pointer") end

  local offset = self.tree_bytes + node - self.node_count
  if offset < self.data_start or offset >= self.metadata_marker then
    fail("data pointer outside section")
  end
  -- decode also returns its internal cursor; lookup exposes only the record.
  local record = decode(self, offset, self.data_start, self.metadata_marker)
  return record
end

local function open_reader(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, "Cannot open MMDB " .. tostring(path) .. ": " .. tostring(err) end
  local db = setmetatable({file = f}, Reader)
  local ok, reason = pcall(function()
    db.file_size = assert(f:seek("end"))
    local tail_start = math.max(0, db.file_size - 131072)
    local tail = read_at(db, tail_start, db.file_size - tail_start)
    local search, last = 1, nil
    while true do
      local pos = tail:find(marker, search, true)
      if not pos then break end
      last, search = pos, pos + 1
    end
    if not last then fail("metadata marker not found") end
    db.metadata_marker = tail_start + last - 1
    local metadata_start = db.metadata_marker + #marker
    local meta = decode(db, metadata_start, metadata_start, db.file_size)
    if type(meta) ~= "table" then fail("invalid metadata") end
    db.node_count = meta.node_count
    db.record_size = meta.record_size
    db.ip_version = meta.ip_version
    if meta.binary_format_major_version ~= 2 or
       type(db.node_count) ~= "number" or db.node_count < 1 or
       db.node_count % 1 ~= 0 or
       (db.record_size ~= 24 and db.record_size ~= 28 and db.record_size ~= 32) or
       (db.ip_version ~= 4 and db.ip_version ~= 6) then
      fail("unsupported or invalid metadata")
    end
    db.node_bytes = db.record_size // 4
    db.tree_bytes = db.node_count * db.node_bytes
    db.data_start = db.tree_bytes + 16
    if db.data_start >= db.metadata_marker then fail("invalid tree size") end
    if read_at(db, db.tree_bytes, 16) ~= string.rep("\0", 16) then
      fail("invalid data section separator")
    end
    db.metadata = meta
  end)
  if not ok then db:close(); return nil, reason end
  return db
end

mmdb.open = open_reader
return mmdb
