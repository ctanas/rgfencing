-- Wheel bout: each exchange is a five-way rock-paper-scissors, played by
-- the rules of foil.
--
-- Footwork is live. When either fencer moves first, the bout stops and
-- both choose one of five actions without seeing the other's. The CPU's
-- choice is made the moment the exchange starts, before the player is
-- asked. Each action beats two and loses to two:
--
--   DIRECT ATTACK  beats the FEINT (one tempo lands before two) and the
--                  BEAT (an attack into its preparation)
--   FEINT ATTACK   beats the PARRY (deceives it) and the BEAT (the blade
--                  slips round it)
--   PARRY-RIPOSTE  beats the DIRECT ATTACK (parry, then riposte) and the
--                  POINT IN LINE (the parry finds the blade in line)
--   POINT IN LINE  beats the DIRECT ATTACK and the FEINT: the line has
--                  priority, and they run onto the point
--   BEAT ATTACK    beats the POINT IN LINE (the attacker must beat the
--                  line) and the PARRY (knocks the waiting blade aside)
--
-- The same choice on both sides is no touch: simultaneous attacks, or
-- nobody attacks. Distance and ratings don't change the outcome.
--
-- The exchange is then fenced out by the real engine and judged by its
-- referee, as in the tactical bout, whose match (src/tactics.lua) this
-- builds on. The menus are drawn by src/tactical.lua.

local Tac = require("src.tactics")
local Fencer = require("src.fencer")

local max, min, ceil = math.max, math.min, math.ceil

local Wh = {}

Wh.KEYS = { "wdirect", "wfeint", "wparry", "wline", "wbeat" }

-- Names in the menu, and short ones for the lists of what beats what.
local ACT = {
  wdirect = { name = "DIRECT ATTACK", short = "DIRECT" },
  wfeint = { name = "FEINT ATTACK", short = "FEINT" },
  wparry = { name = "PARRY-RIPOSTE", short = "PARRY" },
  wline = { name = "POINT IN LINE", short = "LINE" },
  wbeat = { name = "BEAT ATTACK", short = "BEAT" },
}

-- BEATS[a][b]: why a beats b.
Wh.BEATS = {
  wdirect = { wfeint = "ONE TEMPO BEATS TWO", wbeat = "ATTACK INTO THE PREPARATION" },
  wfeint = { wparry = "THE FEINT DECEIVES THE PARRY", wbeat = "THE BLADE EVADES THE BEAT" },
  wparry = { wdirect = "PARRY, THEN RIPOSTE", wline = "THE PARRY FINDS THE BLADE IN LINE" },
  wline = { wdirect = "THE POINT IN LINE HAS PRIORITY", wfeint = "THE FEINT RUNS ONTO THE POINT" },
  wbeat = { wline = "THE BEAT REMOVES THE LINE", wparry = "THE BEAT OPENS THE LINE" },
}

-- Both chose the same.
Wh.TIE = {
  wdirect = "SIMULTANEOUS ATTACKS",
  wfeint = "SIMULTANEOUS ATTACKS",
  wparry = "BOTH WAIT: NOBODY ATTACKS",
  wline = "BOTH IN LINE: NOBODY ATTACKS",
  wbeat = "THE BLADES CLASH",
}

-- 1 if a beats b, -1 if b beats a, 0 for the same choice.
function Wh.result(a, b)
  if Wh.BEATS[a][b] then return 1 end
  if Wh.BEATS[b][a] then return -1 end
  return 0
end

-- The actions k beats (sign 1) or loses to (sign -1), in menu order.
function Wh.against(k, sign)
  local t = {}
  for _, o in ipairs(Wh.KEYS) do
    if Wh.result(k, o) == sign then t[#t + 1] = o end
  end
  return t
end

-- The tactical bout's menus, model and UI serve the wheel too.
for _, k in ipairs(Wh.KEYS) do Tac.ACT[k] = ACT[k] end
Tac.MENU.wheel = Wh.KEYS
Tac.FACING.wheel = "wheel"

-- What each style likes to pick. Stronger CPUs also read your habits.
local PREF = {
  balanced = {},
  attacker = { wdirect = 1.3, wbeat = 1.4, wparry = 0.8, wline = 0.7 },
  counter = { wline = 1.7, wparry = 1.1, wfeint = 0.8 },
  defender = { wparry = 1.7, wline = 1.2, wdirect = 0.8, wbeat = 0.8 },
  flecheur = { wdirect = 1.5, wfeint = 1.2, wparry = 0.8, wline = 0.8 },
}

function Wh.brain(level, style)
  return Tac.brain(level, style, PREF[style] or {})
end

-- You can move first from this close (m between the pelvises), as the CPU.
Wh.RANGE = 3.1

---------------------------------------------------------------------------
-- The match
---------------------------------------------------------------------------

local Match = Tac.Match
local WM = setmetatable({}, { __index = Match })
WM.__index = WM

-- Same arguments as Tac.match; each side's brain should be a Wh.brain.
function Wh.match(b, sides, ask)
  return Tac.match(b, sides, ask, WM)
end

function WM:canAttack(i)
  return Match.canAttack(self, i) and self:gap() <= Wh.RANGE
end

-- Side ai moves first. The CPU chooses at once; then the human is asked.
function WM:startAttack(ai)
  local ctx = { gap = self:gap(), first = ai }
  self.waiting = true
  local pick = {}
  for i = 1, 2 do
    local s = self.sides[i]
    if not s.human then pick[i] = s.brain:choose("wheel", Wh.result) end
  end
  local function askNext()
    for i = 1, 2 do
      if not pick[i] then
        local info = { ctx = ctx, menu = "wheel", side = i, cancel = (i == ai) }
        self.ask(i, "wheel", info, function(k)
          if not k then
            -- changed their mind: back to the footwork
            self.waiting = false
            self.cool = 0.3
            return
          end
          pick[i] = k
          askNext()
        end)
        return
      end
    end
    self.waiting = false
    for i = 1, 2 do self:record(i, "wheel", pick[i]) end
    self:resolve(ai, pick[1], pick[2])
  end
  askNext()
end

-- Both have chosen: the wheel decides, the engine shows it.
function WM:resolve(ai, k1, k2)
  local r = Wh.result(k1, k2)
  local w = (r > 0 and 1) or (r < 0 and 2) or nil
  local act = { k1, k2 }
  self.last = {
    stage = "wheel", by = ai, act = act, winner = w,
    why = w and Wh.BEATS[act[w]][act[3 - w]] or Wh.TIE[k1],
  }
  self:stage(k1, k2, w)
end

-- Run fn once the bout's clock reaches t (during this exchange).
function WM:after(t, fn)
  local at = self.ex.at
  at[#at + 1] = { t, fn }
end

---------------------------------------------------------------------------
-- Staging: each pairing fenced out on the real engine
---------------------------------------------------------------------------

local WANT = 2.1     -- gap a lunge surely lands from
local ONTO = 2.0     -- gap from which a lunge runs onto a point in line
local EXT            -- gap the arm alone lands from

local function reachGaps()
  if not EXT then EXT = Fencer.measure().ext + 0.13 - 0.05 end
end

-- Steps forward until within want. Returns when the action can start and
-- the gap it starts from. lunge: the lunge goes from the last step, as a
-- step-lunge; otherwise the steps are finished first.
local function stepIn(s, f, gap, want, t, lunge)
  if gap <= want then return t, gap end
  local T = Fencer.T
  local n = min(5, ceil((gap - want) / T.stepDist))
  local st = T.step / f.spd
  s:move(t, 1, (n - 1) * st + 0.1)
  if lunge then
    return t + ((n - 1) + 0.62) * st, gap - n * T.stepDist * 0.8
  end
  return t + n * st + 0.03, gap - n * T.stepDist
end

-- Both fencers step in together until within want.
local function bothIn(m, gap, want, t)
  if gap <= want then return t, gap end
  local T = Fencer.T
  local n = min(4, ceil((gap - want) / (2 * T.stepDist)))
  local last = t
  for i = 1, 2 do
    local st = T.step / m.b.f[i].spd
    m.scripts[i]:move(t, 1, (n - 1) * st + 0.1)
    last = max(last, t + n * st + 0.03)
  end
  return last, gap - 2 * n * T.stepDist
end

-- The final action: the arm alone when close, else a lunge. Returns when
-- the point arrives.
local function hit(s, f, t, gap, line)
  if gap <= EXT then
    s:press(t, "x", line, 0.6)
    return t + Tac.arrive("extend", gap - 0.13, f.spd)
  end
  s:press(t, "a", line, 0.55)
  return t + Tac.arrive("lunge", gap - 0.13, f.spd)
end

-- A feint in the high line, then the real attack in the low one: a lunge,
-- or when close, the arm already out changes line. Returns when the real
-- attack starts (the feint itself must not score) and when it arrives.
local function feint(s, f, t, gap)
  local tl = t + 0.17
  s:press(t, "x", "high", 0.8)
  if gap <= EXT then
    s:press(tl, "down")
    return tl, tl + (Fencer.T.switch + 0.02) / f.spd
  end
  s:press(tl, "a", "low", 0.55)
  return tl, tl + Tac.arrive("lunge", gap - 0.13, f.spd)
end

-- A blade action against a blade that is not moving is a beat: a parry
-- waits until the attack is really coming, and not in the last moment of
-- an arm going out (it would meet the arm held still: a beat).
local function coming(F)
  return function()
    if F.legs == "lunge" or F.legs == "fleche" then return F:attacking() and F.arm == "extend" end
    return F.arm == "extend" and F.aphase == "out" and F.at < 0.5 * F.ad
  end
end
local function parryAt(D, t0, tLand)
  local T = Fencer.T
  return max(t0 + 0.02, tLand - (T.parrySnap + T.parryActive * 0.5) / D.spd)
end

-- Winner w, loser l: each stager sets up both scripts and what the scoring
-- box accepts (self.allow, "ignore" by default), and returns when the
-- exchange is over if nobody has been touched by then.
local WIN = {}

-- The attack lands while the feint is still a feint.
WIN["wdirect>wfeint"] = function(m, w, l, gap, t0)
  local sw, sl, FW = m.scripts[w], m.scripts[l], m.b.f[w]
  local t, g = stepIn(sw, FW, gap, WANT, t0, true)
  local tLand = hit(sw, FW, t, g, "high")
  sl:press(t + 0.12, "x", "high", 0.8)          -- the feint
  sl:press(t + 0.55, "a", "low", 0.55)          -- its second tempo: too late
  m.allow[w] = "valid"
  m.stopOther = true
  return tLand + 0.6
end

-- The attack goes into the step that prepares the beat.
WIN["wdirect>wbeat"] = function(m, w, l, gap, t0)
  local sw, sl, FW = m.scripts[w], m.scripts[l], m.b.f[w]
  local g = gap
  if gap > 1.9 then
    sl:move(t0, 1, 0.1)
    g = gap - Fencer.T.stepDist * 0.6
  end
  local t, g2 = stepIn(sw, FW, g, WANT, t0 + 0.08, true)
  local tLand = hit(sw, FW, t, g2, "high")
  sl:when(tLand - 0.02, coming(FW), "b", "high")  -- the beat, too late
  m.allow[w] = "valid"
  m.stopOther = true
  return tLand + 0.6
end

-- The feint draws the parry into the line shown; the lunge finishes in the other.
WIN["wfeint>wparry"] = function(m, w, l, gap, t0)
  local sw, sl, FW, FL = m.scripts[w], m.scripts[l], m.b.f[w], m.b.f[l]
  local t, g = stepIn(sw, FW, gap, WANT, t0, false)
  local tl, tLand = feint(sw, FW, t, g)
  sl:when(parryAt(FL, t0, tLand) - 0.04, coming(FW), "b", "high")
  m:after(tl, function() m.allow[w] = "valid" end)   -- the feint itself does not hit
  return tLand + 0.6
end

-- The beat goes for the blade as it slips round, and finds nothing.
WIN["wfeint>wbeat"] = function(m, w, l, gap, t0)
  local sw, sl, FW = m.scripts[w], m.scripts[l], m.b.f[w]
  local t, g = stepIn(sw, FW, gap, WANT, t0, false)
  local tl, tLand = feint(sw, FW, t, g)
  sl:when(tl, function() return FW:attacking() end, "b", "high")
  m:after(tl, function() m.allow[w] = "valid" end)
  return tLand + 0.6
end

-- Parry the attack; the riposte is scripted when the parry happens (watch).
WIN["wparry>wdirect"] = function(m, w, l, gap, t0)
  local sw, sl, FW, FL = m.scripts[w], m.scripts[l], m.b.f[w], m.b.f[l]
  local t, g = stepIn(sl, FL, gap, WANT, t0, true)
  local tLand = hit(sl, FL, t, g, "high")
  sw:when(parryAt(FW, t0, tLand), coming(FL), "b", "high")
  m.allow[l] = "parry"
  m.allow[w] = "valid"
  m.ex.riposte = w
  return tLand + 0.5
end

-- The point in line comes forward; the parry finds the blade (a beat on a
-- still blade) and hits.
WIN["wparry>wline"] = function(m, w, l, gap, t0)
  local sw, sl, FW, FL = m.scripts[w], m.scripts[l], m.b.f[w], m.b.f[l]
  sl:press(t0, "x", "high", 2.0)
  local t, g = stepIn(sl, FL, gap, WANT, t0 + 0.12, false)
  t = max(t, t0 + 0.3)
  sw:press(t, "b", "high")
  local tLand = hit(sw, FW, t + 0.12, g, "high")
  m.allow[w] = "valid"
  return tLand + 0.6
end

-- The attack runs onto the point in line, which was there first.
WIN["wline>wdirect"] = function(m, w, l, gap, t0)
  local sw, sl, FL = m.scripts[w], m.scripts[l], m.b.f[l]
  sw:press(t0, "x", "high", 2.0)
  local t, g = stepIn(sl, FL, gap, ONTO, t0 + 0.3, true)
  t = max(t, t0 + 0.3)
  local tLand = hit(sl, FL, t, g, "high")
  m:after(t, function() m.allow[w] = "valid" end)
  return tLand + 0.8
end

-- The feint runs onto the point in line.
WIN["wline>wfeint"] = function(m, w, l, gap, t0)
  local sw, sl, FL = m.scripts[w], m.scripts[l], m.b.f[l]
  sw:press(t0, "x", "high", 2.0)
  local t, g = stepIn(sl, FL, gap, ONTO, t0 + 0.3, false)
  t = max(t, t0 + 0.3)
  local _, tLand = feint(sl, FL, t, g)
  m:after(t, function() m.allow[w] = "valid" end)
  return tLand + 0.8
end

-- Beat the blade in line, then attack.
WIN["wbeat>wline"] = function(m, w, l, gap, t0)
  local sw, sl, FW = m.scripts[w], m.scripts[l], m.b.f[w]
  sl:press(t0, "x", "high", 2.0)
  local t, g = stepIn(sw, FW, gap, WANT, t0 + 0.12, false)
  t = max(t, t0 + 0.3)
  sw:press(t, "b", "high")
  local tLand = hit(sw, FW, t + 0.12, g, "high")
  m.allow[w] = "valid"
  return tLand + 0.6
end

-- Beat the waiting blade aside, then attack: the parry comes too late.
WIN["wbeat>wparry"] = function(m, w, l, gap, t0)
  local sw, sl, FW = m.scripts[w], m.scripts[l], m.b.f[w]
  local t, g = stepIn(sw, FW, gap, WANT, t0, false)
  sw:press(t, "b", "high")
  local tLand = hit(sw, FW, t + 0.12, g, "high")
  sl:when(tLand - 0.01, coming(FW), "b", "high")
  m.allow[w] = "valid"
  return tLand + 0.6
end

local TIE = {}

-- Both attack at once: simultaneous attacks, no touch.
TIE.wdirect = function(m, gap, t0)
  local t, g = bothIn(m, gap, WANT, t0)
  local tLand = t
  for i = 1, 2 do tLand = max(tLand, hit(m.scripts[i], m.b.f[i], t, g, "high")) end
  m.allow[1], m.allow[2] = "valid", "valid"
  return tLand + 0.8
end

-- Both feint, and both finish together.
TIE.wfeint = function(m, gap, t0)
  local t, g = bothIn(m, gap, WANT, t0)
  local tl, tLand = t, t
  for i = 1, 2 do
    local a, b = feint(m.scripts[i], m.b.f[i], t, g)
    tl, tLand = a, max(tLand, b)
  end
  m:after(tl, function() m.allow[1], m.allow[2] = "valid", "valid" end)
  return tLand + 0.8
end

-- Both wait for an attack that never comes.
TIE.wparry = function(m, gap, t0)
  return t0 + 1.0
end

-- Both hold a point in line; nobody walks onto the other's.
TIE.wline = function(m, gap, t0)
  for i = 1, 2 do m.scripts[i]:press(t0, "x", "high", 1.0) end
  return t0 + 1.3
end

-- Both go for the blade at once: the blades clash, nobody has the beat.
TIE.wbeat = function(m, gap, t0)
  local t = bothIn(m, gap, 2.4, t0)
  for i = 1, 2 do m.scripts[i]:press(t, "b", "high") end
  return t + 0.9
end

function WM:stage(k1, k2, w)
  reachGaps()
  self:begin("wheel", self.last.by)
  self.ex.at = {}
  self.ex.pend = { k1, k2, w }
  self.ex.untilT = math.huge
  self:settle()
end

-- The exchange starts from a still guard: a step (or jump) that was under
-- way when the bout stopped is finished first, so the distance it starts
-- from is the one the timings are worked out for.
function WM:settle()
  local b, ex = self.b, self.ex
  local p = ex.pend
  for i = 1, 2 do
    if b.f[i].legs ~= "guard" and b.time - ex.t0 < 1 then return end
  end
  ex.pend = nil
  local k1, k2, w = p[1], p[2], p[3]
  local t0 = b.time + 0.04
  local gap = self:gap()
  if w then
    local act = { k1, k2 }
    ex.untilT = WIN[act[w] .. ">" .. act[3 - w]](self, w, 3 - w, gap, t0)
  else
    ex.untilT = TIE[k1](self, gap, t0)
  end
end

-- After the parry: the riposte, straight back. The fencer parried stays
-- where they are (in the lunge) until it lands.
function WM:riposte(ri)
  local b = self.b
  local pi = 3 - ri
  local Rf, P = b.f[ri], b.f[pi]
  self.scripts[ri]:clear()       -- a parry still waiting to go would withdraw the riposte
  self.scripts[pi]:hold(P.legs == "lunge" and "a" or "x", b.time, 0.8)
  local gap = (P.x - Rf.x) * Rf.face
  local tLand = hit(self.scripts[ri], Rf, b.time + 0.02, gap, "high")
  self.ex.untilT = max(self.ex.untilT, tLand + 0.6)
end

function WM:watch()
  local b, ex = self.b, self.ex
  if ex.pend then self:settle() end
  local at = ex.at
  for k = #at, 1, -1 do
    if b.time >= at[k][1] then
      local fn = at[k][2]
      table.remove(at, k)
      fn()
    end
  end
  local ph = b.phase
  if ph ~= "fence" and ph ~= "lockout" then
    self:toLive()
    return
  end
  if ph == "lockout" then return end
  local lp = b.lastParry
  if lp and lp.t > ex.parry0 then
    ex.parry0 = lp.t
    if ex.riposte == lp.by then self:riposte(lp.by) end
  end
  if b.time > ex.untilT then self:toLive() end
end

return Wh
