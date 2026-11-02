-- Tactical bout: fencing in real time between exchanges, with the choices
-- inside each exchange made from a menu.
--
-- Footwork is live. When someone attacks, the bout stops: the attacker
-- picks an attack and the defender a defence, each without seeing the
-- other's choice. The outcome is drawn from how each action fares against
-- each other one, the fencing "tactical wheel":
--
--   the simple attack is stopped by the parry; the parry is deceived by
--   the disengage and the feint; the feint (two tempi) loses to the
--   counterattack; the counterattack has no priority against a simple
--   attack and is spoiled by the beat; the retreat makes a lunge fall
--   short but not a step-lunge or a flèche, which give the stop-hit a
--   tempo...
--
-- shifted by distance and by the two fencers' ratings. The exchange is
-- then fenced out by the real engine (src/bout.lua) and judged by its
-- referee: a parry stops the bout again for the riposte and the answer to
-- it, and so on until a touch or the end of the phrase.
--
-- The model, the CPU's choices and the staging of each outcome live here;
-- the menus are drawn by src/tactical.lua.

local core = require("src.core")
local Fencer = require("src.fencer")
local Ctl = require("src.controller")

local max, min, floor, ceil, exp, log = math.max, math.min, math.floor, math.ceil, math.exp, math.log
local clamp = core.clamp
local function rnd() return love.math.random() end

local Tac = {}

Tac.SLOW = 0.55      -- exchanges are played in slow motion

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

Tac.ACT = {
  -- attacks
  direct = { name = "DIRECT LUNGE",
    desc = "One fast tempo. A counterattack has no priority on it; a parry or a retreat stops it." },
  disengage = { name = "DISENGAGE",
    desc = "Lunge round their blade: deceives a simple parry. A circular parry catches it." },
  step = { name = "STEP-LUNGE",
    desc = "Advance, then lunge: catches a retreat. The step is a preparation they can hit into." },
  beat = { name = "BEAT-LUNGE",
    desc = "Knock their blade aside, then lunge: spoils a stop-hit and a simple parry." },
  feint = { name = "FEINT-DISENGAGE",
    desc = "Feint, draw the parry, deceive it. Two tempi: a counterattack lands first." },
  fleche = { name = "FLÈCHE",
    desc = "A running attack from further out. Parried, there is no way back from it." },
  -- defences
  parry = { name = "SIMPLE PARRY",
    desc = "Block the blade and take the priority to riposte. A disengage or a feint deceives it." },
  circle = { name = "CIRCULAR PARRY",
    desc = "Sweep a full circle: catches a disengage. A little slower against a direct attack." },
  retreat = { name = "RETREAT",
    desc = "Break the distance: a lunge falls short. A step-lunge or a flèche can still reach you." },
  counter = { name = "COUNTERATTACK",
    desc = "Hit into the attack. Only scores a tempo ahead: against a feint or a preparation." },
  -- ripostes
  rdirect = { name = "DIRECT RIPOSTE",
    desc = "Straight back at once: it beats a remise. A counter-parry can stop it." },
  rindirect = { name = "INDIRECT RIPOSTE",
    desc = "Goes round the counter-parry, but gives them time to recover." },
  rdelayed = { name = "DELAYED RIPOSTE",
    desc = "Let their counter-parry go by, then hit. A remise or a quick recovery beats it." },
  -- answers to a parry
  cparry = { name = "COUNTER-PARRY",
    desc = "Parry the riposte and hit back. An indirect or delayed riposte evades it." },
  remise = { name = "REMISE",
    desc = "Stay in the lunge and put the point back. It only scores against a slow riposte." },
  recover = { name = "RECOVER BACK",
    desc = "Spring back out of distance. Escapes a slow riposte, rarely a direct one." },
  -- after their attack fell short
  onrec = { name = "ATTACK ON RECOVERY",
    desc = "Attack while they recover from the lunge: they are late to defend." },
  guard = { name = "BACK ON GUARD",
    desc = "Let them recover, and start the phrase again." },
}

Tac.MENU = {
  attack = { "direct", "disengage", "step", "beat", "feint", "fleche" },
  defend = { "parry", "circle", "retreat", "counter" },
  riposte = { "rdirect", "rindirect", "rdelayed" },
  parried = { "cparry", "remise", "recover" },
  recovery = { "onrec", "guard" },
}
-- the menu the other fencer is choosing from at the same time
Tac.FACING = { attack = "defend", defend = "attack", riposte = "parried", parried = "riposte" }

---------------------------------------------------------------------------
-- Distance
---------------------------------------------------------------------------

-- Bands of the gap between the two fencers' pelvises (m). A lunge lands
-- up to about 2.2 m, a step-lunge 2.5 m, a flèche 2.9 m.
Tac.BANDS = {
  { key = "close", name = "CLOSE", max = 1.7 },
  { key = "lunge", name = "LUNGE", max = 2.25 },
  { key = "step", name = "STEP-LUNGE", max = 2.75 },
  { key = "long", name = "TOO FAR", max = math.huge },
}

function Tac.band(gap)
  for _, b in ipairs(Tac.BANDS) do
    if gap <= b.max then return b.key, b.name end
  end
end

local LUNGE_LIKE = { direct = true, disengage = true, beat = true, feint = true }

-- How much of the attack's chance survives the distance, where the rest
-- goes, and how often it ends in a body contact instead.
local function distance(a, band, gap)
  local far = clamp((3.4 - gap) / 0.65, 0.02, 1)
  if LUNGE_LIKE[a] then
    if band == "close" then return 1, nil, 0.06 end
    if band == "lunge" then return 1 end
    if band == "step" then return 0.45, "short" end
    return 0.12 * far, "short"
  elseif a == "step" then
    if band == "close" then return 0.55, "corps" end
    if band == "lunge" then return 0.85, "corps" end
    if band == "step" then return 1 end
    return 0.6 * far, "short"
  else
    if band == "close" then return 0.5, "corps" end
    if band == "lunge" then return 0.95, "corps" end
    if band == "step" then return 1 end
    return 0.75 * far, "short"
  end
end

---------------------------------------------------------------------------
-- Outcomes
---------------------------------------------------------------------------

-- Attack against defence, between two fencers of equal ratings at the
-- right distance: chance the attack lands, is parried, falls short, or is
-- beaten by a counterattack in time.
local VS = {
  direct    = { parry = { .30, .70, 0, 0 }, circle = { .45, .55, 0, 0 }, retreat = { .25, 0, .75, 0 }, counter = { .85, 0, .03, .12 } },
  disengage = { parry = { .70, .30, 0, 0 }, circle = { .25, .75, 0, 0 }, retreat = { .25, 0, .75, 0 }, counter = { .62, 0, .03, .35 } },
  step      = { parry = { .38, .62, 0, 0 }, circle = { .45, .55, 0, 0 }, retreat = { .65, 0, .35, 0 }, counter = { .45, 0, .03, .52 } },
  beat      = { parry = { .55, .45, 0, 0 }, circle = { .40, .60, 0, 0 }, retreat = { .30, 0, .70, 0 }, counter = { .72, 0, .03, .25 } },
  feint     = { parry = { .75, .25, 0, 0 }, circle = { .55, .45, 0, 0 }, retreat = { .20, 0, .80, 0 }, counter = { .25, 0, .03, .72 } },
  fleche    = { parry = { .42, .58, 0, 0 }, circle = { .48, .52, 0, 0 }, retreat = { .70, 0, .30, 0 }, counter = { .55, 0, .03, .42 } },
}
Tac.VS = VS

-- Riposte against the answer of the fencer who was parried: chance the
-- riposte lands, is counter-parried, falls short, or loses to the remise.
local RVS = {
  rdirect   = { cparry = { .40, .60, 0, 0 }, remise = { .85, 0, 0, .15 }, recover = { .65, 0, .35, 0 } },
  rindirect = { cparry = { .72, .28, 0, 0 }, remise = { .65, 0, 0, .35 }, recover = { .40, 0, .60, 0 } },
  rdelayed  = { cparry = { .70, .30, 0, 0 }, remise = { .20, 0, 0, .80 }, recover = { .25, 0, .75, 0 } },
}
Tac.RVS = RVS

-- extra chance of landing off target
local OFF_EXTRA = { direct = 0, disengage = 0.03, step = 0.01, beat = 0, feint = 0.03, fleche = 0.04 }

local K = 0.25       -- logit shift per rating point

local function logit(p)
  p = clamp(p, 1e-4, 1 - 1e-4)
  return log(p / (1 - p))
end
local function logistic(x) return 1 / (1 + exp(-x)) end

-- Move chance between o[k1] and o[k2] by a logit shift (towards k1 if > 0).
local function shift(o, k1, k2, s)
  local t = o[k1] + o[k2]
  if t <= 0 or s == 0 then return end
  local h = logistic(logit(o[k1] / t) + s)
  o[k1], o[k2] = t * h, t * (1 - h)
end

-- ctx: A, D = ratings; band, gap; adv = the defender was stepping in;
-- recov = the defender is recovering from a lunge; room = metres behind
-- the defender before their end line.
function Tac.attackOdds(a, d, ctx)
  local v = VS[a][d]
  local o = { hit = v[1], parried = v[2], short = v[3], counter = v[4],
    double = 0, off = 0, out = 0, corps = 0 }
  local mul, to, corps = distance(a, ctx.band, ctx.gap or 2)
  if mul < 1 then
    local lost = o.hit * (1 - mul)
    o.hit = o.hit - lost
    o[to] = o[to] + lost
  end
  if corps then
    local c = o.hit * corps
    o.hit, o.corps = o.hit - c, o.corps + c
  end
  local A, D = ctx.A, ctx.D
  local late = (ctx.adv and 0.5 or 0) + (ctx.recov and 0.7 or 0)
  if d == "parry" or d == "circle" then
    shift(o, "hit", "parried", K * (A.atk - D.def) + late)
  elseif d == "retreat" then
    shift(o, "hit", "short", K * (A.ftw - D.ftw) + late * 1.5)
  else
    shift(o, "hit", "counter", K * (A.atk - D.tim) + late)
  end
  -- a retreat needs room: without it, the back line
  if d == "retreat" and ctx.room then
    local keep = clamp((ctx.room - 0.5) / 1.0, 0, 1)
    local lost = o.short * (1 - keep)
    o.short, o.out = o.short - lost, o.out + lost
  end
  local offP = clamp(0.11 - 0.015 * (A.atk - 5), 0.04, 0.2) + OFF_EXTRA[a]
  o.off = o.hit * offP
  o.hit = o.hit - o.off
  -- a counterattack that is not in time usually lands too: two lamps, and
  -- the priority stays with the attack
  if d == "counter" then
    o.double = o.hit * 0.7
    o.hit = o.hit - o.double
  end
  return o
end

-- ctx: R, P = ratings of the riposter and of the fencer parried; chain =
-- 1 for a riposte, 2 for a counter-riposte...; fleche = the parried attack
-- was a flèche.
function Tac.riposteOdds(r, c, ctx)
  local v = RVS[r][c]
  local o = { hit = v[1], parried = v[2], short = v[3], remise = v[4], off = 0 }
  local R, P = ctx.R, ctx.P
  local s = 0.15 * ((ctx.chain or 1) - 1)
  if c == "cparry" then
    shift(o, "hit", "parried", K * ((R.atk + R.def) / 2 - P.def) + s)
  elseif c == "remise" then
    shift(o, "hit", "remise", K * (R.tim - P.tim) + s)
  else
    shift(o, "hit", "short", K * (R.atk - P.ftw) + s)
  end
  if ctx.fleche then
    -- a parried flèche runs on: no remise, and little recovery
    o.hit = o.hit + o.remise + o.short * 0.6
    o.short = o.short * 0.4
    o.remise = 0
    shift(o, "hit", "parried", 0.8)
  end
  o.off = o.hit * (r == "rindirect" and 0.08 or 0.05)
  o.hit = o.hit - o.off
  return o
end

local ORDER = { "hit", "double", "off", "parried", "short", "counter", "out", "corps", "remise" }

function Tac.roll(o, r)
  r = r or rnd()
  local acc = 0
  for _, k in ipairs(ORDER) do
    acc = acc + (o[k] or 0)
    if r < acc then return k end
  end
  local best, bk = -1, "hit"
  for _, k in ipairs(ORDER) do
    if (o[k] or 0) > best then best, bk = o[k], k end
  end
  return bk
end

-- Chance that the attack (or riposte) wins the touch outright.
function Tac.landChance(o)
  return (o.hit or 0) + (o.double or 0) + (o.out or 0)
end

-- Worth of the odds to the attacker (or riposter): a touch is 1, a parry
-- hands the riposte to the other side...
local VALUE = { hit = 1, double = 1, out = 1, off = 0, corps = 0, parried = -0.3, short = -0.08, counter = -1, remise = -1 }
function Tac.value(o)
  local v = 0
  for k, p in pairs(o) do v = v + p * (VALUE[k] or 0) end
  return v
end

---------------------------------------------------------------------------
-- Ratings (1..10, shown x10)
---------------------------------------------------------------------------

Tac.RATINGS = { "atk", "def", "tim", "ftw" }
Tac.RATING_SHORT = { atk = "ATK", def = "DEF", tim = "TIM", ftw = "FTW" }

-- By CPU level, NOVICE to LEGEND. Career opponents fall between levels.
local LEVEL_BASE = { 3.5, 5, 6.5, 8, 9 }
local STYLE_MOD = {
  balanced = {},
  attacker = { atk = 1, def = -0.5, tim = -0.5, ftw = 0.5 },
  counter = { atk = -0.5, tim = 1.5 },
  defender = { atk = -0.5, def = 1.5, tim = -0.25, ftw = 0.5 },
  flecheur = { atk = 0.5, def = -0.5, ftw = 1 },
}

-- A value from a by-level table, between whole levels; nil level: dflt.
local function byLevel(t, level, dflt)
  if not level then return dflt end
  local l = clamp(level, 1, #t)
  local i = min(floor(l), #t - 1)
  return t[i] + (t[i + 1] - t[i]) * (l - i)
end

function Tac.cpuRatings(level, style)
  local base = byLevel(LEVEL_BASE, level, 5)
  local m = STYLE_MOD[style] or {}
  local r = {}
  for _, k in ipairs(Tac.RATINGS) do r[k] = clamp(base + (m[k] or 0), 1, 9.5) end
  return r
end

-- What each training drill teaches (src/training.lua, in order).
local DRILL_GAIN = {
  { ftw = 1 },                     -- footwork
  { atk = 0.75, ftw = 0.25 },      -- the lunge
  { atk = 0.5, def = 0.5 },        -- high and low
  { def = 1.25 },                  -- parry-riposte
  { atk = 0.5, tim = 0.75 },       -- attack first
  { tim = 1 },                     -- point in line
  { atk = 0.75, def = 0.25 },      -- disengage
  { ftw = 0.75, atk = 0.25 },      -- flèche
}

-- The player starts as a club fencer (5); drills and wins add to it.
function Tac.playerRatings(p)
  local r = { atk = 5, def = 5, tim = 5, ftw = 5 }
  if p then
    for n, g in ipairs(DRILL_GAIN) do
      if p.drills and p.drills[n] then
        for k, v in pairs(g) do r[k] = r[k] + v end
      end
    end
    local xp = min(1, (p.stats and p.stats.wins or 0) * 0.05)
    for k in pairs(r) do r[k] = r[k] + xp end
  end
  return r
end

function Tac.ratingText(r, sep)
  local t = {}
  for _, k in ipairs(Tac.RATINGS) do
    t[#t + 1] = require("src.i18n").tr(Tac.RATING_SHORT[k]) .. " " .. floor(r[k] * 10 + 0.5)
  end
  return table.concat(t, sep or "  ")
end

---------------------------------------------------------------------------
-- The CPU's choices
---------------------------------------------------------------------------

-- Style: what each kind of fencer likes to do.
local PREF = {
  balanced = {},
  attacker = { direct = 1.2, step = 1.3, beat = 1.4, retreat = 0.7, counter = 0.8, rdirect = 1.2, remise = 1.4, onrec = 1.3 },
  counter = { counter = 1.9, retreat = 1.3, parry = 0.8, feint = 0.8, onrec = 1.5 },
  defender = { parry = 1.6, circle = 1.5, counter = 0.5, rdirect = 1.2, rdelayed = 1.2, cparry = 1.3 },
  flecheur = { fleche = 2.4, step = 1.3, retreat = 1.2 },
}
-- How well each level reads the opponent's habits, and how sharply it
-- picks the best answer it sees (lower = sharper).
local READ = { 0.05, 0.25, 0.5, 0.8, 0.9 }
local TEMP = { 0.45, 0.30, 0.20, 0.13, 0.10 }
-- How keen each style is to attack
Tac.AGGR = { attacker = 1.4, flecheur = 1.1, balanced = 1.0, counter = 0.6, defender = 0.5 }

local Brain = {}
Brain.__index = Brain

-- pref: what this style likes, by action (default: the tactical menus').
function Tac.brain(level, style, pref)
  return setmetatable({
    level = level, style = style, read = byLevel(READ, level, 0.25), temp = byLevel(TEMP, level, 0.3),
    pref = pref or PREF[style] or {}, seen = {},
  }, Brain)
end

-- The opponent chose key from menu.
function Brain:observe(menu, key)
  local s = self.seen[menu] or {}
  self.seen[menu] = s
  s[key] = (s[key] or 0) + 1
end

-- What the opponent will pick from menu, as this fencer reads it.
function Brain:predict(menu)
  local s = self.seen[menu] or {}
  local q, tot = {}, 0
  for _, k in ipairs(Tac.MENU[menu]) do
    q[k] = 1 + 3 * self.read * (s[k] or 0)
    tot = tot + q[k]
  end
  for k, v in pairs(q) do q[k] = v / tot end
  return q
end

-- Pick from my menu; payoff(mine, theirs) is my value of that pairing.
function Brain:choose(menu, payoff)
  local mine = Tac.MENU[menu]
  if rnd() < 0.08 then return mine[love.math.random(1, #mine)] end
  local q = self:predict(Tac.FACING[menu])
  local w, tot = {}, 0
  for _, k in ipairs(mine) do
    local ev = 0
    for o, p in pairs(q) do ev = ev + p * payoff(k, o) end
    w[k] = exp(ev / self.temp) * (self.pref[k] or 1)
    tot = tot + w[k]
  end
  local r = rnd() * tot
  for _, k in ipairs(mine) do
    r = r - w[k]
    if r <= 0 then return k end
  end
  return mine[#mine]
end

---------------------------------------------------------------------------
-- Scripted pad: button presses on a timeline (bout time)
---------------------------------------------------------------------------

local Script = {}
Script.__index = Script

function Tac.script()
  return setmetatable({ pad = Ctl.newPad(), ev = {}, holds = {}, moves = {}, prev = {} }, Script)
end

function Script:clear()
  self.ev, self.holds, self.moves = {}, {}, {}
end

function Script:press(t, btn, line, hold)
  self.ev[#self.ev + 1] = { t = t, btn = btn, line = line, hold = hold }
end

-- Press as soon as cond(b) holds (after time t).
function Script:when(t, cond, btn, line, hold)
  self.ev[#self.ev + 1] = { t = t, cond = cond, btn = btn, line = line, hold = hold }
end

function Script:hold(btn, t, dur)
  self.holds[#self.holds + 1] = { btn = btn, t0 = t, t1 = t + dur }
end

function Script:move(t, dir, dur)
  self.moves[#self.moves + 1] = { t0 = t, t1 = t + dur, dir = dir }
end

function Script:idle() end

local want = {}
function Script:get(b, i)
  local now = b.time
  local me = b.f[i]
  for k in pairs(want) do want[k] = false end
  for _, h in ipairs(self.holds) do
    if now >= h.t0 and now < h.t1 then want[h.btn] = true end
  end
  for _, m in ipairs(self.moves) do
    if now >= m.t0 and now < m.t1 then want[(m.dir * me.face > 0) and "right" or "left"] = true end
  end
  local ev = self.ev
  for k = #ev, 1, -1 do
    local e = ev[k]
    if now >= e.t and (not e.cond or e.cond(b)) then
      table.remove(ev, k)
      if self.prev[e.btn] and not want[e.btn] then
        -- still down from before: let go for a step so it is a new press
        e.t = now + 1 / 120
        ev[#ev + 1] = e
      else
        want[e.btn] = true
        if e.line then want[e.line == "high" and "up" or "down"] = true end
        if e.hold then self:hold(e.btn, now, e.hold) end
      end
    end
  end
  local pad = self.pad
  for _, k in ipairs(Ctl.BUTTONS) do
    local d = want[k] or false
    pad.pressed[k] = d and not self.prev[k]
    pad.down[k] = d
    self.prev[k] = d
  end
  return pad
end

-- Only footwork gets through: in a tactical bout the blade actions come
-- from the menus.
function Tac.footworkOnly(src)
  local c = { pad = Ctl.newPad(), src = src }
  local OK = { left = true, right = true, l1 = true, r1 = true }
  function c:get(b, i, h, first)
    local p = src:get(b, i, h, first)
    for _, k in ipairs(Ctl.BUTTONS) do
      self.pad.down[k] = OK[k] and p.down[k] or false
      self.pad.pressed[k] = OK[k] and p.pressed[k] or false
    end
    return self.pad
  end
  function c:idle(b, i, h)
    if src.idle then src:idle(b, i, h) end
  end
  return c
end

---------------------------------------------------------------------------
-- The match: live footwork, the menus, and the staging of each exchange
---------------------------------------------------------------------------

local Match = {}
Match.__index = Match
Tac.Match = Match        -- src/wheel.lua builds on it

-- Chance per second that the CPU attacks, by distance band
local BAND_RATE = { close = 1.8, lunge = 0.9, step = 0.4, long = 0 }
local FLECHEUR_RATE = { close = 1.2, lunge = 0.8, step = 0.8, long = 0.35 }

-- sides[i] = { human = bool, ratings = {...}, live = controller,
--              brain, style, level (CPU) }
-- ask(i, menu, info, done): a human picks from menu; done(key), or
-- done(nil) to cancel an attack. class: a subclass of Match (src/wheel.lua).
function Tac.match(b, sides, ask, class)
  local m = setmetatable({
    b = b, sides = sides, ask = ask, mode = "live",
    quiet = 0, cool = 0.8, chain = 0,
    scripts = { Tac.script(), Tac.script() },
    allow = { "ignore", "ignore" },
    picks = { {}, {} },          -- what each side chose, menu by menu
  }, class or Match)
  -- the scoring box asks the match being fenced (set again on a switch of mode)
  m.judgeFn = function(_, i, region) return m:judge(i, region) end
  b.o.judge = m.judgeFn
  return m
end

-- One frame. advance(dt) moves the bout on.
function Match:frame(dt, advance)
  if self.waiting then return end
  local b = self.b
  if self.mode == "live" then
    if b.phase == "fence" then
      self.quiet = self.quiet + dt
      self.cool = max(0, self.cool - dt)
      for i = 1, 2 do
        if self:cpuWantsAttack(i, dt) then
          self:startAttack(i)
          return
        end
      end
    end
    advance(dt)
  else
    advance(dt * Tac.SLOW)
    self:watch()
  end
end

function Match:canAttack(i)
  local b = self.b
  if self.mode ~= "live" or self.waiting or b.phase ~= "fence" then return false end
  local f = b.f[i]
  return (f.legs == "guard" or f.legs == "step") and f.arm == "guard"
end

-- The human asks to attack.
function Match:requestAttack(i)
  if self:canAttack(i) then self:startAttack(i) end
end

function Match:gap()
  local b = self.b
  return b.f[2].x - b.f[1].x
end

function Match:cpuWantsAttack(i, dt)
  local s = self.sides[i]
  if s.human or self.cool > 0 or not self:canAttack(i) then return false end
  local b = self.b
  local me, op = b.f[i], b.f[3 - i]
  local gap = (op.x - me.x) * me.face
  if gap > 3.1 then return false end
  local band = Tac.band(gap)
  local rate = (s.style == "flecheur" and FLECHEUR_RATE or BAND_RATE)[band]
  rate = rate * (Tac.AGGR[s.style] or 1) * (0.8 + 0.1 * (s.level or 2)) * (1 + min(2, self.quiet / 6))
  -- an opponent stepping in is in preparation: a good moment
  if op.legs == "step" and op.sdir > 0 and band ~= "long" then rate = rate * 1.8 end
  return rnd() < 1 - exp(-rate * dt)
end

-- Pick for side i: ask the human, or let the CPU decide.
function Match:choose(i, menu, info, payoff, done)
  local s = self.sides[i]
  info.menu = menu
  info.side = i
  if s.human then
    self.ask(i, menu, info, done)
  else
    done(s.brain:choose(menu, payoff))
  end
end

-- Both sides have chosen: each one's habits are now known to the other.
function Match:record(i, menu, key)
  local p = self.picks[i][menu] or {}
  self.picks[i][menu] = p
  p[key] = (p[key] or 0) + 1
  local o = self.sides[3 - i]
  if o.brain then o.brain:observe(menu, key) end
end

function Match:attackCtx(ai, recov)
  local b = self.b
  local di = 3 - ai
  local A, D = b.f[ai], b.f[di]
  local gap = (D.x - A.x) * A.face
  local band, bandName = Tac.band(gap)
  return {
    ai = ai, di = di, gap = gap, band = band, bandName = bandName,
    A = self.sides[ai].ratings, D = self.sides[di].ratings,
    adv = (D.legs == "step" and D.sdir > 0) or nil,
    recov = recov or (D.legs == "lunge") or nil,
    room = core.END + D.face * D.x,
  }
end

-- Side ai attacks: both choose, then the exchange is staged.
function Match:startAttack(ai, recov)
  local di = 3 - ai
  local ctx = self:attackCtx(ai, recov)
  self.waiting = true
  local info = { ctx = ctx, cancel = true }
  self:choose(ai, "attack", info, function(a, d) return Tac.value(Tac.attackOdds(a, d, ctx)) end, function(a)
    if not a then
      -- changed their mind: back to the footwork
      self.waiting = false
      self.cool = 0.3
      return
    end
    local dinfo = { ctx = ctx }
    self:choose(di, "defend", dinfo, function(d, a2) return -Tac.value(Tac.attackOdds(a2, d, ctx)) end, function(d)
      self.waiting = false
      self:record(ai, "attack", a)
      self:record(di, "defend", d)
      self.chain = 0
      local o = Tac.attackOdds(a, d, ctx)
      local res = Tac.roll(o)
      self.last = { stage = "attack", by = ai, act = { [ai] = a, [di] = d }, chance = Tac.landChance(o), res = res }
      self:stageAttack(ai, a, d, res, ctx)
    end)
  end)
end

-- When a point should arrive: time for the action's point to travel dist
-- metres ahead of the pelvis it starts from.
local function arrive(action, dist, spd)
  local t = Fencer.timeTo(action, max(0.2, dist))
  if not t then
    local p = Fencer.measure().path[action]
    t = p[#p][1]
  end
  return t / spd
end
Tac.arrive = arrive

function Match:begin(stage, ai)
  local b = self.b
  self.mode = "exchange"
  self.ex = {
    stage = stage, ai = ai, t0 = b.time, untilT = b.time + 2,
    parry0 = b.lastParry and b.lastParry.t or -1,
    short0 = b.stats[ai].short or 0,
  }
  for i = 1, 2 do
    self.scripts[i]:clear()
    b.f[i].ctl = self.scripts[i]
  end
  self.allow = { "ignore", "ignore" }
  self.stopOther = false
  self.corps = false
end

-- The scoring box asks: fencer i's point is on the other fencer's body.
-- The exchange's outcome is already drawn, so the director answers.
function Match:judge(i, region)
  if self.mode ~= "exchange" then return nil end
  local v = self.allow[i]
  if v == "after" then
    -- lands second: only once the other fencer's hit is on
    v = self.b.lights[3 - i] and "valid" or "ignore"
  end
  if v == "parry" then
    self.allow[i] = "ignore"
    return "parry"
  elseif v == "valid" or v == "off" then
    if self.stopOther then
      local o = 3 - i
      self.scripts[o]:clear()
      self.allow[o] = "ignore"
    end
    return v
  end
  return "ignore"
end

function Match:stageAttack(ai, a, d, res, ctx)
  local b = self.b
  local di = 3 - ai
  local A, D = b.f[ai], b.f[di]
  self:begin("attack", ai)
  local sa, sd = self.scripts[ai], self.scripts[di]
  local T = Fencer.T
  local R = Fencer.measure()
  local now = b.time
  local t0 = now + 0.04
  local gap = ctx.gap
  local dist = gap - 0.13            -- to the front of their trunk
  local slow = (res == "counter")    -- an attack in two tempi gives the counter its chance
  local lands = (res == "hit" or res == "off" or res == "double" or res == "parried")
  local hold = 0.55
  local tOff, tLand, line = t0, nil, "high"
  local inLunge = D.legs == "lunge"

  -- the attacker
  if a == "direct" then
    if slow then
      sa:press(t0, "x", "high", 0.8)
      sa:press(t0 + 0.42, "a", "high", hold)
      tLand = t0 + 0.42 + arrive("lunge", dist, A.spd)
    else
      sa:press(t0, "a", "high", hold)
      tLand = t0 + arrive("lunge", dist, A.spd)
    end
  elseif a == "disengage" then
    line = "low"
    if slow then
      sa:press(t0, "x", "high", 0.8)
      sa:press(t0 + 0.16, "down")
      sa:press(t0 + 0.42, "a", "low", hold)
      tLand = t0 + 0.42 + arrive("lunge", dist, A.spd)
    elseif gap < 1.8 then
      -- close: the point goes under their blade as the arm goes out
      sa:press(t0, "a", "low", hold)
      tLand = t0 + arrive("lunge", dist, A.spd)
    else
      sa:press(t0, "a", "high", hold)
      sa:press(t0 + 0.06, "down")
      tLand = t0 + arrive("lunge", dist, A.spd) + 0.03
    end
  elseif a == "step" then
    -- already in lunge distance, the step is no more than a shuffle
    local n = clamp(ceil((gap - 2.1) / T.stepDist), 0, 3)
    local tl = t0
    if n > 0 then
      tl = t0 + ((n - 1) + 0.62) * T.step / A.spd
      sa:move(t0, 1, (n - 1) * T.step / A.spd + 0.1)
    end
    sa:press(tl, "a", "high", hold)
    tOff = tl
    dist = dist - n * T.stepDist * 0.8
    tLand = tl + arrive("lunge", dist, A.spd)
  elseif a == "beat" then
    local tb = t0 + (slow and 0.05 or 0)
    if gap > 2.5 then
      sa:move(t0, 1, 0.1)
      tb = t0 + 0.6 * T.step / A.spd
      dist = dist - T.stepDist
    end
    sa:press(tb, "b")
    sa:press(tb + 0.12, "a", "high", hold)
    tOff = tb + 0.12
    tLand = tOff + arrive("lunge", dist, A.spd)
  elseif a == "feint" then
    line = "low"
    local tl = t0 + (slow and 0.42 or 0.17)
    sa:press(t0, "x", "high", 0.8)
    sa:press(tl, "a", "low", hold)
    tLand = tl + arrive("lunge", dist, A.spd) - 0.02
  else -- flèche
    local tf = t0
    if gap > 2.95 then
      sa:move(t0, 1, 0.1)
      tf = t0 + 0.6 * T.step / A.spd
      dist = dist - T.stepDist
    end
    tOff = tf
    if slow then
      sa:press(tf, "x", "high", 0.8)
      tf = tf + 0.35
    end
    sa:press(tf, "y", "high", 0.6)
    dist = dist - 0.1
    tLand = tf + arrive("fleche", dist, A.spd)
  end

  -- an attack that must arrive but would fall short: the defender steps
  -- into it (or the referee would see it fall short)
  local reach = (a == "fleche") and R.fleche or R.lunge
  if lands and dist > reach - 0.06 and not inLunge then
    sd:move(t0, 1, 0.1)
  end

  -- the defender. A blade action against a blade that is not moving is a
  -- beat, so parries wait until the attack is really coming.
  local function coming() return A:attacking() end
  local function parryAt(tl) return max(t0 + 0.02, tl - (T.parrySnap + T.parryActive * 0.5) / D.spd) end
  local function counter(t, cond)
    -- a stop-hit: the arm alone when close (or from a lunge), else a lunge
    local btn = (inLunge or gap - 0.13 <= R.ext + 0.3) and "x" or "a"
    if cond then sd:when(t, cond, btn, "high", 0.6) else sd:press(t, btn, "high", 0.6) end
  end
  -- the attack has been under way for a while: a counter now is not simultaneous
  local function underway(b2)
    return A.offense and A.offStart and A.offStart >= now and b2.time - A.offStart >= 0.13
  end
  if res == "parried" then
    sd:when(parryAt(tLand), coming, "b", line)
    self.allow[ai] = "parry"
  elseif res == "hit" or res == "off" or res == "double" then
    self.allow[ai] = (res == "off") and "off" or "valid"
    if d == "parry" or d == "circle" then
      if line == "low" then
        sd:when(parryAt(tLand) - 0.04, coming, "b", "high")   -- parries the line it was shown
      else
        sd:when(tLand - 0.01, coming, "b", "high")            -- too late
      end
    elseif d == "retreat" then
      sd:move(tLand + 0.03, -1, 0.12)                         -- too late
    elseif d == "counter" and res == "double" then
      counter(t0, underway)
      self.allow[di] = "valid"
    end
  elseif res == "counter" then
    if a == "step" then
      counter(t0 + 0.03)                -- into the preparation
    elseif a == "beat" then
      counter(t0)                       -- evades the beat
    else
      counter(t0, underway)
    end
    self.allow[di] = "valid"
    self.stopOther = true
  elseif res == "short" then
    if inLunge then
      sd:move(t0, -1, 0.6)
    else
      sd:press(t0 + 0.05, "l1")
      sd:move(t0 + 0.4, -1, (a == "step" or a == "fleche") and 0.5 or 0.1)
    end
  elseif res == "out" then
    sd:press(t0 + 0.03, "l1")
    sd:move(t0 + 0.38, -1, 2.5)
  elseif res == "corps" then
    sd:move(t0 + 0.05, 1, 0.35)
    self.corps = true
  end
  self.ex.res = res
  self.ex.untilT = max(tLand, t0) + 1.0
  if res == "out" then self.ex.untilT = t0 + 3 end
end

-- A parry: the parrier ripostes, the fencer parried answers.
function Match:afterParry(ri)
  local b = self.b
  local pi = 3 - ri
  self.chain = (self.ex and self.ex.stage == "riposte") and (self.chain + 1) or 1
  local ctx = {
    ri = ri, pi = pi, chain = self.chain,
    R = self.sides[ri].ratings, P = self.sides[pi].ratings,
    fleche = b.f[pi].legs == "fleche" or nil,
    gap = (b.f[pi].x - b.f[ri].x) * b.f[ri].face,
  }
  self.waiting = true
  self:choose(ri, "riposte", { ctx = ctx }, function(r, c) return Tac.value(Tac.riposteOdds(r, c, ctx)) end, function(r)
    self:choose(pi, "parried", { ctx = ctx }, function(c, r2) return -Tac.value(Tac.riposteOdds(r2, c, ctx)) end, function(c)
      self.waiting = false
      self:record(ri, "riposte", r)
      self:record(pi, "parried", c)
      local o = Tac.riposteOdds(r, c, ctx)
      local res = Tac.roll(o)
      self.last = { stage = "riposte", by = ri, act = { [ri] = r, [pi] = c }, chance = Tac.landChance(o), res = res }
      self:stageRiposte(ri, r, c, res, ctx)
    end)
  end)
end

function Match:stageRiposte(ri, r, c, res, ctx)
  local b = self.b
  local pi = 3 - ri
  local Rf, P = b.f[ri], b.f[pi]
  self:begin("riposte", ri)
  local sr, sp = self.scripts[ri], self.scripts[pi]
  local T = Fencer.T
  local M = Fencer.measure()
  local now = b.time
  local gap = (P.x - Rf.x) * Rf.face
  local useX = gap - 0.13 <= M.ext - 0.02
  local btn, act = useX and "x" or "a", useX and "extend" or "lunge"
  local t1 = now + (r == "rdelayed" and 0.36 or 0.03)
  -- the riposte is slow when the remise or the recovery wins
  if (res == "remise" or res == "short") and r == "rdirect" then t1 = t1 + 0.30 end
  -- the indirect riposte, and a delayed one that waited for the counter-
  -- parry to commit, finish in the other line
  local line = "high"
  sr:press(t1, btn, "high", 0.5)
  if r == "rindirect" or (r == "rdelayed" and c == "cparry" and res ~= "parried") then
    sr:press(t1 + 0.06, "down")
    line = "low"
  end
  local tLand = t1 + arrive(act, gap - 0.13, Rf.spd) + (line == "low" and 0.04 or 0)
  -- a blade action against a still blade is a beat: the counter-parry
  -- waits for the riposte to come
  local function coming() return Rf:attacking() end

  -- the fencer who was parried
  local keep = (P.legs == "lunge") and "a" or "x"
  local function freeArm(dt)
    if P.arm == "deflect" then P.ad = min(P.ad, P.at + dt) end
  end
  if c == "cparry" then
    sp:hold(keep, now, 0.9)
    freeArm(0.02)
    if res == "parried" then
      sp:when(max(now + 0.01, tLand - (T.parrySnap + T.parryActive * 0.5) / P.spd), coming, "b", line)
    elseif line == "low" then
      sp:when(now + 0.01, coming, "b", "high")  -- the line it was shown
    else
      sp:when(tLand, coming, "b", "high")       -- too late
    end
  elseif c == "remise" then
    sp:hold(keep, now, 1.2)
    if res == "remise" or (res == "hit" and r ~= "rdelayed") then freeArm(0.08) end
  else
    sp:move(now, -1, 0.6)
  end

  if res == "hit" or res == "off" then
    self.allow[ri] = (res == "off") and "off" or "valid"
    -- the remise lands too, after the riposte: two lamps, the riposte's touch
    if c == "remise" and r ~= "rdelayed" then self.allow[pi] = "after" end
  elseif res == "parried" then
    self.allow[ri] = "parry"
  elseif res == "remise" then
    self.allow[pi] = "valid"
    self.stopOther = true
  end
  self.ex.untilT = tLand + 0.9
end

-- The attack fell short: the defender may attack the recovery.
function Match:afterShort(ai)
  local di = 3 - ai
  local ctx = self:attackCtx(di, true)
  self.waiting = true
  local s = self.sides[di]
  local function go(k)
    self.waiting = false
    self:record(di, "recovery", k)
    if k == "onrec" then
      self:startAttack(di, true)
    else
      self:toLive()
    end
  end
  if s.human then
    self.ask(di, "recovery", { ctx = ctx, menu = "recovery", side = di }, go)
  else
    -- worth it if some attack does well against how they usually defend
    local q = s.brain:predict("defend")
    local best = -1
    for _, a in ipairs(Tac.MENU.attack) do
      local ev = 0
      for d, p in pairs(q) do ev = ev + p * Tac.value(Tac.attackOdds(a, d, ctx)) end
      best = max(best, ev)
    end
    local p = (best > 0.1 and 0.8 or 0.25) * (s.brain.pref.onrec or 1)
    go(rnd() < p and "onrec" or "guard")
  end
end

function Match:watch()
  local b, ex = self.b, self.ex
  local ph = b.phase
  if ph ~= "fence" and ph ~= "lockout" then
    self:toLive()
    return
  end
  if ph == "lockout" then return end
  local lp = b.lastParry
  if lp and lp.t > ex.parry0 then
    ex.parry0 = lp.t
    self:afterParry(lp.by)
    return
  end
  if ex.stage == "attack" and ex.res ~= "out" and (b.stats[ex.ai].short or 0) > ex.short0 then
    ex.short0 = b.stats[ex.ai].short
    self:afterShort(ex.ai)
    return
  end
  if self.corps then
    local f1, f2 = b.f[1], b.f[2]
    if f2.x - f1.x < 1.0 then
      b.corpsFleche = (f1.legs == "fleche" or f2.legs == "fleche")
      b:halt("corps")
      return
    end
  end
  if b.time > ex.untilT then self:toLive() end
end

-- Back to the footwork.
function Match:toLive()
  local b = self.b
  self.mode = "live"
  self.ex = nil
  self.quiet = 0
  self.cool = 0.6
  self.corps = false
  for i = 1, 2 do
    self.scripts[i]:clear()
    local s = self.sides[i]
    b.f[i].ctl = s.live
    if s.live and s.live.idle then s.live:idle(b, i, 0) end
  end
end

return Tac
