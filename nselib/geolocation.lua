--- Shared geographic lookup interface for NSE consumers.
-- The MMDB backend is local and never contacts a network service. Other
-- backends can be added without changing scripts that consume lookup().
local ipOps = require "ipOps"
local mmdb = require "mmdb"

local geolocation = {}
local Provider = {}
Provider.__index = Provider

local function english(record)
  if type(record) ~= "table" then return nil end
  local names = record.names
  if type(names) == "table" and type(names.en) == "string" then
    return names.en
  end
  return type(record.iso_code) == "string" and record.iso_code or nil
end

local function coordinate(value, limit)
  return type(value) == "number" and value == value and
    value >= -limit and value <= limit
end

function Provider:close()
  if self.city then self.city:close(); self.city = nil end
  if self.asn then self.asn:close(); self.asn = nil end
  self.cache = nil
end

local function query(db, ip)
  if not db then return nil end
  local ok, record, err = pcall(db.lookup, db, ip)
  if not ok then return nil, tostring(record) end
  return record, err
end

--- Look up any hop or target IP, not only a scanned Nmap host.
-- Returns a normalized record or nil,error. Valid no-match results are not
-- errors, and ASN-only or country-only records do not invent coordinates.
function Provider:lookup(ip)
  if not self.cache then return nil, "provider is closed" end
  if type(ip) ~= "string" then return nil, "invalid IP address" end
  if self.cache[ip] then return self.cache[ip] end

  local private, err = ipOps.isPrivate(ip)
  if private == nil then return nil, err or "invalid IP address" end
  if not private and not ip:find(":", 1, true) then
    -- RFC 6598 shared space is omitted by Nmap's ipOps.isPrivate().
    local shared, shared_err = ipOps.ip_in_range(ip, "100.64.0.0/10")
    if shared == nil then return nil, shared_err or "invalid IP address" end
    private = shared
  end
  if private then
    local record = { status = "non-public" }
    self.cache[ip] = record
    return record
  end

  local city, city_err = query(self.city, ip)
  if city_err then return nil, "geographic lookup: " .. tostring(city_err) end
  local asn, asn_err = query(self.asn, ip)
  if asn_err then return nil, "ASN lookup: " .. tostring(asn_err) end

  local result = {}
  if type(city) == "table" then
    -- Network registration is not evidence of the IP's physical location.
    result.country = english(city.country)
    result.registered_country = english(city.registered_country)
    result.city = english(city.city)
    result.continent = english(city.continent)
    local location = city.location
    if type(location) == "table" and
       coordinate(location.latitude, 90) and
       coordinate(location.longitude, 180) then
      result.latitude, result.longitude = location.latitude, location.longitude
      -- GeoLite2 expresses its estimated uncertainty in kilometres. A radius
      -- only has meaning when the database supplied valid coordinates.
      local radius = location.accuracy_radius
      if type(radius) == "number" and radius == radius and
         radius >= 0 and radius < math.huge and radius % 1 == 0 then
        result.accuracy_radius_km = radius
      end
    end
  end
  if type(asn) == "table" then
    if type(asn.autonomous_system_number) == "number" then
      result.asn = asn.autonomous_system_number
    end
    if type(asn.autonomous_system_organization) == "string" then
      result.organization = asn.autonomous_system_organization
    end
  end

  if result.latitude then
    result.status = "located"
  elseif result.country or result.city or result.continent then
    result.status = "country-only"
  elseif result.registered_country then
    result.status = "registered-only"
  elseif result.asn or result.organization then
    result.status = "asn-only"
  else
    result.status = "no MMDB record"
  end
  self.cache[ip] = result
  return result
end

--- Open the requested provider. Currently 'mmdb' is the only implementation.
-- Missing or unreadable files are errors, not empty geographic results.
function geolocation.open(options)
  options = options or {}
  local name = options.provider or "mmdb"
  if name ~= "mmdb" then
    return nil, "unsupported geolocation provider: " .. tostring(name)
  end
  if type(options.db) ~= "string" or options.db == "" then
    return nil, "MMDB database path is required"
  end
  local city, err = mmdb.open(options.db)
  if not city then return nil, err end
  local asn
  if options.asn then
    asn, err = mmdb.open(options.asn)
    if not asn then city:close(); return nil, err end
  end
  return setmetatable({city = city, asn = asn, cache = {}}, Provider)
end

return geolocation
