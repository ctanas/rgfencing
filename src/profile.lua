-- Player profiles: a name and a nationality, plus everything that belongs
-- to that player: training progress, bout statistics and the career save
-- (career_<id>.lua). Settings (sound, assists...) stay shared.
--
-- profiles.lua = { active = id, nextId = n, list = { profile, ... } }
-- profile      = { id, name, nation, drills = { [n] = true },
--                  stats = { bouts, wins, ts, tr } }

local settings = require("src.settings")

local P = {}
local FILE = "profiles.lua"
local data = { active = nil, nextId = 1, list = {} }

P.MAXNAME = 12

function P.load()
  local t = settings.readTable(FILE)
  if t and type(t.list) == "table" then
    data = t
    data.nextId = data.nextId or (#data.list + 1)
  end
  return data
end

function P.save()
  settings.writeTable(FILE, data)
end

function P.list() return data.list end

function P.get(id)
  for _, p in ipairs(data.list) do
    if p.id == id then return p end
  end
end

function P.current()
  return P.get(data.active) or data.list[1]
end

function P.setActive(id)
  data.active = id
  P.save()
  require("src.career").reset()
end

function P.careerFile(p)
  p = p or P.current()
  return p and ("career_" .. p.id .. ".lua") or "career.lua"
end

function P.create(name, nation)
  local p = {
    id = data.nextId, name = name, nation = nation,
    drills = {}, stats = { bouts = 0, wins = 0, ts = 0, tr = 0 },
  }
  data.nextId = data.nextId + 1
  -- the first profile inherits a career and drills from before profiles
  if #data.list == 0 then
    for n, done in pairs(settings.drills) do if done then p.drills[n] = true end end
    settings.drills = {}
    settings.save()
    local old = settings.readTable("career.lua")
    if old then
      settings.writeTable(P.careerFile(p), old)
      settings.remove("career.lua")
    end
  end
  data.list[#data.list + 1] = p
  P.save()
  P.setActive(p.id)
  return p
end

function P.update(p, name, nation)
  if name then p.name = name end
  if nation then p.nation = nation end
  P.save()
end

function P.delete(id)
  for k, p in ipairs(data.list) do
    if p.id == id then
      table.remove(data.list, k)
      settings.remove(P.careerFile(p))
      break
    end
  end
  if data.active == id then data.active = data.list[1] and data.list[1].id or nil end
  P.save()
  require("src.career").reset()
end

function P.drillDone(n)
  local p = P.current()
  return p and p.drills[n] or false
end

function P.markDrill(n)
  local p = P.current()
  if not p then return end
  p.drills[n] = true
  P.save()
end

-- A finished bout (quick or career) for the active profile.
function P.recordBout(won, ts, tr)
  local p = P.current()
  if not p then return end
  local s = p.stats
  s.bouts = s.bouts + 1
  if won then s.wins = s.wins + 1 end
  s.ts, s.tr = s.ts + ts, s.tr + tr
  P.save()
end

-- The player's name and nation for a bout.
function P.fencer()
  local p = P.current()
  if not p then return "YOU", nil end
  return p.name, p.nation
end

-- For screenshots and tests: profiles in memory only.
function P.useSample(name, nation)
  data = { active = 1, nextId = 2, list = { {
    id = 1, name = name, nation = nation, drills = {}, stats = { bouts = 14, wins = 9, ts = 61, tr = 44 },
  } } }
end

return P
