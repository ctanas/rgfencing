-- Persistent settings (plain key=value text in the save directory) and a
-- tiny serializer for the career save.

local S = {
  data = {
    sound = true,
    crowd = true,
    assist = true,     -- priority marker, attack-line hints, distance colour
    swapab = false,
    fps = false,
    qlevel = 2,        -- quick bout: 1 novice .. 4 elite
    qstyle = 1,        -- 1 random, then the styles in ai.STYLE_ORDER
    qtouches = 1,      -- 1 = 5, 2 = 10, 3 = 15
    tlevel = 2,        -- tactical bout: the same three choices
    tstyle = 1,
    ttouches = 1,
    side = 1,          -- the end of the piste you fence from: 1 left, 2 right
    res = 2,           -- render resolution, see core.RES: 1 240x160, 2 360x240, 3 720x480
    lang = 1,          -- 1 English, 2 Română (src/i18n.lua)
  },
  drills = {},         -- training drills completed: drills[n] = true
}

local FILE = "settings.txt"

function S.load()
  if not love.filesystem.getInfo(FILE) then return end
  local ok, content = pcall(love.filesystem.read, FILE)
  if not ok or type(content) ~= "string" then return end
  for line in content:gmatch("[^\r\n]+") do
    local k, v = line:match("^([%w_]+)%s*=%s*(.-)%s*$")
    if k then
      local dn = k:match("^drill_(%d+)$")
      if dn then
        S.drills[tonumber(dn)] = (v == "true")
      elseif S.data[k] ~= nil then
        if type(S.data[k]) == "boolean" then
          S.data[k] = (v == "true")
        else
          S.data[k] = tonumber(v) or S.data[k]
        end
      end
    end
  end
end

function S.sanitize()
  local d = S.data
  local function int(v, lo, hi, def)
    v = math.floor(tonumber(v) or def)
    if v < lo or v > hi then v = def end
    return v
  end
  d.qlevel = int(d.qlevel, 1, 4, 2)
  d.qstyle = int(d.qstyle, 1, 6, 1)
  d.qtouches = int(d.qtouches, 1, 3, 1)
  d.tlevel = int(d.tlevel, 1, 4, 2)
  d.tstyle = int(d.tstyle, 1, 6, 1)
  d.ttouches = int(d.ttouches, 1, 3, 1)
  d.side = int(d.side, 1, 2, 1)
  d.res = int(d.res, 1, 3, 2)
  d.lang = int(d.lang, 1, 2, 1)
end

function S.save()
  if require("src.core").testMode then return end
  local out = {}
  for k, v in pairs(S.data) do out[#out + 1] = k .. "=" .. tostring(v) end
  for k, v in pairs(S.drills) do out[#out + 1] = "drill_" .. k .. "=" .. tostring(v) end
  table.sort(out)
  pcall(love.filesystem.write, FILE, table.concat(out, "\n") .. "\n")
end

-- Serialize plain data (tables of strings, numbers, booleans) as a Lua literal.
local function ser(v, out)
  local t = type(v)
  if t == "table" then
    out[#out + 1] = "{"
    local n = #v
    for i = 1, n do ser(v[i], out); out[#out + 1] = "," end
    local keys = {}
    for k in pairs(v) do
      if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      if type(k) == "string" and k:match("^[%a_][%w_]*$") then
        out[#out + 1] = k .. "="
      else
        out[#out + 1] = "["; ser(k, out); out[#out + 1] = "]="
      end
      ser(v[k], out); out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  elseif t == "string" then
    out[#out + 1] = string.format("%q", v)
  elseif t == "number" then
    out[#out + 1] = (v % 1 == 0) and string.format("%d", v) or string.format("%.6g", v)
  elseif t == "boolean" then
    out[#out + 1] = tostring(v)
  else
    out[#out + 1] = "nil"
  end
end

function S.writeTable(file, t)
  if require("src.core").testMode then return end
  local out = { "return " }
  ser(t, out)
  pcall(love.filesystem.write, file, table.concat(out) .. "\n")
end

function S.readTable(file)
  if not love.filesystem.getInfo(file) then return nil end
  local ok, content = pcall(love.filesystem.read, file)
  if not ok or type(content) ~= "string" then return nil end
  local fn = loadstring(content, "=" .. file)
  if not fn then return nil end
  setfenv(fn, {})            -- data only: no access to globals
  local ok2, t = pcall(fn)
  if ok2 and type(t) == "table" then return t end
  return nil
end

function S.remove(file)
  if require("src.core").testMode then return end
  pcall(love.filesystem.remove, file)
end

return S
