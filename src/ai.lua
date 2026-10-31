-- AI fencer. It plays through a virtual pad (src/controller.lua), so it has
-- exactly the same moves and timings as the player, and it only reacts to
-- what it could have seen: an attack is noticed after a reaction time,
-- the parry goes into the line the attack was in at that moment (a late
-- change of line fools it), and distance is judged with some error.
--
-- Level (rating 1..4.5) sets reaction time, parry timing, speed, feints
-- and mistakes; style sets what it likes to do.

local core = require("src.core")
local Fencer = require("src.fencer")
local Ctl = require("src.controller")

local max, min, floor, abs = math.max, math.min, math.floor, math.abs
local clamp, lerp, gauss = core.clamp, core.lerp, core.gauss
local rnd = function() return love.math.random() end

local AI = {}
AI.__index = AI

AI.LEVELS = {
  { name = "NOVICE",   react = 0.36, sigma = 0.090, read = 0.00, aggr = 0.40, spd = 0.82, feint = 0.00, dnoise = 0.45, freeze = 0.35 },
  { name = "CLUB",     react = 0.28, sigma = 0.060, read = 0.20, aggr = 0.55, spd = 0.90, feint = 0.10, dnoise = 0.25, freeze = 0.16 },
  { name = "NATIONAL", react = 0.22, sigma = 0.042, read = 0.45, aggr = 0.62, spd = 0.96, feint = 0.25, dnoise = 0.14, freeze = 0.07 },
  { name = "ELITE",    react = 0.17, sigma = 0.028, read = 0.70, aggr = 0.68, spd = 1.00, feint = 0.35, dnoise = 0.06, freeze = 0.03 },
  { name = "LEGEND",   react = 0.14, sigma = 0.022, read = 0.80, aggr = 0.70, spd = 1.03, feint = 0.40, dnoise = 0.04, freeze = 0.02 },
}

AI.STYLES = {
  balanced = { attack = 1.0, parry = 1.0, retreat = 1.0, counter = 1.0, fleche = 0.25, beat = 0.5, line = 0.3, prefGap = 0.25, remise = 0.10 },
  attacker = { attack = 1.5, parry = 0.7, retreat = 0.7, counter = 0.6, fleche = 0.35, beat = 1.0, line = 0.1, prefGap = 0.05, remise = 0.20 },
  counter  = { attack = 0.6, parry = 0.8, retreat = 1.3, counter = 1.8, fleche = 0.10, beat = 0.3, line = 0.7, prefGap = 0.35, remise = 0.05 },
  defender = { attack = 0.5, parry = 1.7, retreat = 1.0, counter = 0.5, fleche = 0.00, beat = 0.4, line = 0.4, prefGap = 0.45, remise = 0.00 },
  flecheur = { attack = 1.1, parry = 0.8, retreat = 0.9, counter = 0.7, fleche = 2.00, beat = 0.6, line = 0.1, prefGap = 0.55, remise = 0.15 },
}
AI.STYLE_ORDER = { "balanced", "attacker", "counter", "defender", "flecheur" }
AI.STYLE_NAME = {
  balanced = "ALL-ROUNDER", attacker = "ATTACKER", counter = "COUNTER-PUNCHER",
  defender = "DEFENDER", flecheur = "FLÈCHEUR",
}

function AI.params(rating)
  local r = clamp(rating, 1, 5)
  local i = min(floor(r), 4)
  local t = r - i
  local a, b = AI.LEVELS[i], AI.LEVELS[i + 1]
  local p = {}
  for k, v in pairs(a) do
    if type(v) == "number" then p[k] = lerp(v, b[k], t) end
  end
  p.name = AI.LEVELS[clamp(floor(r + 0.5), 1, #AI.LEVELS)].name
  return p
end

function AI.new(rating, style)
  local a = setmetatable({}, AI)
  a.rating = rating
  a.P = AI.params(rating)
  a.style = AI.STYLES[style] and style or "balanced"
  a.S = AI.STYLES[a.style]
  a.spd = a.P.spd
  a.pad = Ctl.newPad()
  a.want, a.prev = {}, {}
  a.sched = {}
  a.holdUntil = {}
  a.moveDir, a.moveUntil = 0, 0
  a.nextThink = 0
  return a
end

function AI:idle()
  self.sched = {}
  self.holdUntil = {}
  self.moveUntil = 0
  self.parryPlan = nil
  self.seen = nil
end

-- Schedule a button press at time t (optionally with a line and a hold).
function AI:press(t, btn, line, hold, cond)
  self.sched[#self.sched + 1] = { t = t, btn = btn, line = line, hold = hold, cond = cond }
end

function AI:move(dir, dur, now)
  self.moveDir = dir
  self.moveUntil = now + dur
end

function AI:react()
  return self.P.react * (0.85 + 0.3 * rnd())
end

function AI:get(b, i)
  local now = b.time
  local me, op = b.f[i], b.f[3 - i]
  local W = self.want
  for k in pairs(W) do W[k] = false end
  for btn, t in pairs(self.holdUntil) do
    if now < t then W[btn] = true end
  end
  local s = self.sched
  for k = #s, 1, -1 do
    local e = s[k]
    if now >= e.t then
      table.remove(s, k)
      if not e.cond or e.cond(self, b, me, op) then
        if self.prev[e.btn] then
          -- still held from before: release now, press next step
          W[e.btn] = false
          self.holdUntil[e.btn] = nil
          e.t = now + 1 / 120
          s[#s + 1] = e
        else
          W[e.btn] = true
          if e.line then W[e.line == "high" and "up" or "down"] = true end
          if e.hold then self.holdUntil[e.btn] = now + e.hold end
        end
      end
    end
  end
  if now < self.moveUntil and self.moveDir ~= 0 then
    W[(self.moveDir * me.face > 0) and "right" or "left"] = true
  end

  self:think(b, i, me, op, now)

  local pad = self.pad
  for _, k in ipairs(Ctl.BUTTONS) do
    local d = W[k] or false
    pad.pressed[k] = d and not self.prev[k]
    pad.down[k] = d
    self.prev[k] = d
  end
  return pad
end

local function other(line) return line == "high" and "low" or "high" end

function AI:chooseLine(op)
  if rnd() < 0.65 then return other(op.line) end
  return op.line
end

-- Lunge, perhaps with a feint (start in one line, finish in the other).
function AI:attack(me, op, now, delay)
  local line = self:chooseLine(op)
  local t0 = now + (delay or 0)
  local hold = (Fencer.T.lungeExt + Fencer.T.lungeDrive) / me.spd + self.S.remise * rnd() + 0.02
  if rnd() < self.P.feint then
    self:press(t0, "a", other(line), hold)
    self:press(t0 + (0.07 + rnd() * 0.06) / me.spd, line == "high" and "up" or "down")
  else
    self:press(t0, "a", line, hold)
  end
end

-- Where and when will the opponent's action land, if it can?
function AI:predict(me, op, now)
  local R = Fencer.measure()
  local T = Fencer.T
  local act = op.offAction
  if op.legs == "lunge" then act = "lunge" elseif op.legs == "fleche" then act = "fleche" end
  local reach = R[act] or R.ext
  local from = op.offStartX or op.x
  local dist = (me.x - from) * op.face - 0.13
  local t0 = op.offStart or now
  local tt = Fencer.timeTo(act, dist) or Fencer.timeTo(act, reach)
  local tHit = t0 + tt / op.spd
  return tHit, dist <= reach + 0.02, dist, reach
end

function AI:planParry(now, tHit, line)
  local T = Fencer.T
  local press = tHit - (T.parrySnap + T.parryActive * 0.5) + gauss() * self.P.sigma
  if press < now then press = now end
  self:press(press, "b", line)
  self.parryPlan = { line = line, tHit = tHit, reread = false }
end

function AI:defend(b, i, me, op, now)
  local P, S = self.P, self.S
  if rnd() < P.freeze then return end
  local tHit, reachable, dist, reach = self:predict(me, op, now)
  local rem = max(0, tHit - now)
  local dRear = core.END + me.face * me.x
  local canEscape = dist + 1.5 * rem > reach
  local wRet = (dRear > 0.9) and ((not reachable or canEscape) and S.retreat * 1.2 or 0.15) or 0
  local wPar = reachable and S.parry * 1.3 or 0.1
  local wCtr = S.counter * ((op.offAction == "fleche" or dist > 2.3) and 0.6 or 0.12)
  if op.offKind == "riposte" or op.offKind == "counter-riposte" then
    -- my attack was parried: little room to escape, parry or nothing
    wRet, wCtr = wRet * 0.3, 0
  end
  local total = wRet + wPar + wCtr
  local r = rnd() * total
  local line = op.attackLine
  if r < wRet then
    if rem < 0.3 and rnd() < 0.5 then
      self:press(now, "l1")
    else
      self:move(-1, rem + 0.12, now)
    end
    if reachable and rnd() < 0.45 * S.parry then self:planParry(now, tHit + 0.12, line) end
  elseif r < wRet + wPar then
    self:planParry(now, tHit, line)
  else
    self:press(now, "x", rnd() < 0.5 and "high" or "low", 0.35)
  end
end

function AI:think(b, i, me, op, now)
  local P, S = self.P, self.S
  local R = Fencer.measure()
  local T = Fencer.T
  local gap = (op.x - me.x) * me.face
  local row = b.row

  -- 1. a new offensive action by the opponent
  if op.offense and op.offStart and self.seen ~= op.offStart then
    if self.noticeFor ~= op.offStart then
      self.noticeFor = op.offStart
      self.noticeAt = op.offStart + self:react()
    end
    if now >= self.noticeAt then
      self.seen = op.offStart
      self.sched = {}
      self:defend(b, i, me, op, now)
      return
    end
  end
  -- 1b. the attack changed line after I chose my parry
  local plan = self.parryPlan
  if plan and op.offense and not plan.reread and op.attackLine ~= plan.line then
    plan.reread = true
    if rnd() < P.read and plan.tHit - now > 0.05 then
      self:press(now + P.react * 0.35, "b", op.attackLine)
      plan.line = op.attackLine
    end
  end
  if plan and now > plan.tHit + 0.4 then self.parryPlan = nil end

  -- 2. after my parry: riposte; after my beat: attack
  if row.holder == i and (row.kind == "parry" or row.kind == "beat") and self.answered ~= row.since then
    self.answered = row.since
    self.sched = {}
    self.moveUntil = 0
    if row.kind == "parry" then
      local delay = P.react * 0.4 + rnd() * 0.05
      if gap <= R.ext + 0.08 then
        self:press(now + delay, "x", nil, 0.3)
      else
        self:press(now + delay, "a", nil, 0.3)
      end
    else
      self:attack(me, op, now, 0.02)
    end
    return
  end

  -- busy?
  if #self.sched > 0 or op.offense then return end
  if me.legs ~= "guard" and me.legs ~= "step" then return end
  if me.arm ~= "guard" and me.arm ~= "extend" then return end
  if now < self.nextThink then return end
  self.nextThink = now + 0.06 + rnd() * 0.10

  -- gap at which a lunge lands: point reach plus the 0.13 m from the
  -- opponent's pelvis to the front of the trunk, less a margin
  local reachL = R.lunge + 0.03 + gauss() * P.dnoise * 0.4
  local reachAL = reachL + T.stepDist * 0.9
  local reachF = R.fleche - 0.35
  local dRear = core.END + me.face * me.x
  local opRear = core.END + op.face * op.x
  local aggr = P.aggr * S.attack
  if opRear < 1.6 then aggr = aggr * 1.6 end
  if dRear < 1.4 then aggr = aggr * 1.5 end
  local p = aggr * 0.30

  -- attack on the recovery of a lunge that missed
  if op.legs == "lunge" and (op.lphase == "recover" or (op.lphase == "hold" and not op.offense))
    and gap <= reachL + 0.1 and rnd() < 0.25 + 0.35 * S.counter then
    self:attack(me, op, now, P.react * 0.5)
    return
  end
  -- attack into the preparation (their advance)
  local noticed = op.legs == "step" and op.sdir > 0 and (op.time - (op.stepT0 or op.time)) >= P.react * 0.6
  if noticed and gap - T.stepDist <= reachL and rnd() < 0.35 * S.counter then
    self:attack(me, op, now)
    return
  end
  -- their point in line: beat it, or step away
  if row.holder == 3 - i and row.kind == "line" then
    local ot = op.x + op.face * op.j.tipx
    local mt = me.x + me.face * me.j.tipx
    if (mt - ot) * me.face > 0 then
      if rnd() < 0.5 + S.beat * 0.4 then self:press(now, "b", op.line) end
    elseif dRear > 1.0 then
      self:move(-1, 0.15, now)
    end
    return
  end
  -- direct lunge
  if gap <= reachL and rnd() < p then
    self:attack(me, op, now)
    return
  end
  -- advance-lunge
  if gap > reachL and gap <= reachAL and rnd() < p * 0.6 then
    self:move(1, 0.1, now)
    self:attack(me, op, now, T.step * 0.62 / me.spd)
    return
  end
  -- flèche
  if S.fleche > 0 and gap > reachL - 0.1 and gap <= reachF and rnd() < p * 0.22 * S.fleche then
    self:press(now, "y", self:chooseLine(op))
    return
  end
  -- point in line against an advance
  if noticed and S.line > 0 and gap <= R.ext + 0.7 and rnd() < 0.3 * S.line then
    self:press(now, "x", "high", 0.6)
    return
  end
  -- beat, then attack
  if S.beat > 0 and gap <= reachAL then
    local ot = op.x + op.face * op.j.tipx
    local mt = me.x + me.face * me.j.tipx
    if (mt - ot) * me.face > 0.02 and rnd() < 0.12 * S.beat then
      self:press(now, "b", op.line)
      return
    end
  end
  -- change guard now and then
  if rnd() < 0.04 then
    self:press(now, me.line == "high" and "down" or "up")
    return
  end
  -- footwork: hold the distance just outside their lunge
  local pref = reachL + 0.12 + S.prefGap + gauss() * 0.15
  if opRear < 1.6 then pref = pref - 0.3 end
  if gap > pref + 0.12 then
    self:move(1, 0.08 + rnd() * 0.12, now)
  elseif gap < pref - 0.12 and dRear > 0.9 then
    self:move(-1, 0.08 + rnd() * 0.12, now)
  elseif rnd() < 0.12 then
    self:move(rnd() < 0.5 and 1 or -1, 0.08, now)
  end
end

return AI
