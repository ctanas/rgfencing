-- Bout: one foil bout under FIE rules, as the referee and the scoring box see it.
--
--   * Target: the trunk (lamé). A hit elsewhere lights the white lamp,
--     stops the phrase and scores nothing.
--   * Lockout: after the first hit the other fencer has 300 ms to land.
--   * Right of way: the first fencer to start an attack has priority. A
--     parry, or a beat, takes it over; an attack that falls short, is
--     withdrawn or parried loses it. If both lamps light, only the fencer
--     with priority can score. Attacks started together are simultaneous.
--   * Back line: crossing your end line with both feet is a touch against.
--   * Time: 3 min periods; 15-touch bouts have three, with a break at 8.
--     A tie at time goes to a priority minute.
--
-- The simulation runs at a fixed 120 Hz. Drawing lives in src/view.lua.

local core = require("src.core")
local Fencer = require("src.fencer")
local Ctl = require("src.controller")
local audio = require("src.audio")

local abs, max, min, floor = math.abs, math.max, math.min, math.floor

local B = {}
B.__index = B

B.LOCKOUT = 0.300
B.SIMUL = 0.10       -- attacks started this close together are simultaneous
B.RIPOSTE = 0.65     -- after a parry, the riposte must start within this
B.BEATWIN = 0.50     -- after a beat, the attack must start within this
B.CORPS = 0.50       -- pelvis gap (m) that counts as body contact
B.GLOW = 1.4         -- how long a new score glows (s)
B.DT = 1 / 120

local EMPTY = Ctl.newPad()

B.LABEL = {
  attack = "ATTACK",
  ["beat-attack"] = "BEAT-ATTACK",
  riposte = "PARRY-RIPOSTE",
  ["counter-riposte"] = "COUNTER-RIPOSTE",
  counterattack = "COUNTERATTACK",
  remise = "REMISE",
  line = "POINT IN LINE",
}

function B.startX(i)
  return (i == 1 and -1 or 1) * (core.ENGARDE + Fencer.STANCE_F)
end

function B.new(o)
  local b = setmetatable({}, B)
  b.o = o
  b.touches = o.touches or 5
  b.periods = o.periods or (b.touches >= 15 and 3 or (b.touches >= 10 and 2 or 1))
  b.periodTime = o.periodTime or 180
  b.breakAt = (b.touches >= 15 and 8) or nil
  b.breakDone = false
  b.clock = b.periodTime
  b.period = 1
  b.score = { 0, 0 }
  b.time = 0
  b.acc = 0
  b.f = {}
  for i = 1, 2 do
    local s = (i == 1) and o.left or o.right
    local f = Fencer.new({
      face = i == 1 and 1 or -1, side = i, spd = s.spd or 1,
      x = B.startX(i), pose = o.skipIntro and "guard" or "stand",
    })
    f.name = s.name or (i == 1 and "LEFT" or "RIGHT")
    f.nation = s.nation
    f.ctl = s.ctl
    f.human = s.human
    b.f[i] = f
  end
  b.f[1].opp, b.f[2].opp = b.f[2], b.f[1]
  b.row = { holder = nil, kind = nil, since = 0, chain = 0, deadline = 0 }
  b.lights = {}
  b.hitKind = {}
  b.stats = {}
  for i = 1, 2 do
    b.stats[i] = { touches = 0, kinds = {}, parries = 0, beats = 0, attacks = 0, offTarget = 0, against = 0 }
  end
  b.fx = {}
  b.cam = 0
  b.shake = 0
  b.flash = nil
  b.over = false
  b:setPhase(o.skipIntro and "engarde" or "intro")
  return b
end

function B:side(i) return i == 1 and "LEFT" or "RIGHT" end

function B:sfx(name, vol, pitch)
  if not self.o.silent then audio.play(name, vol, pitch) end
end

---------------------------------------------------------------------------
-- Phases
---------------------------------------------------------------------------

function B:setPhase(p)
  self.phase = p
  self.pt = 0
  if p == "intro" then
    for i = 1, 2 do
      local f = self.f[i]
      f:place(B.startX(i), "stand")
    end
    self.call = nil
  elseif p == "engarde" then
    self.call = { text = "EN GARDE !", big = true }
    for i = 1, 2 do
      local f = self.f[i]
      if f.legs == "stand" or f.legs == "walk" then
        f:comeEnGarde()
      elseif f.arm == "pose" then
        f.arm = "guard"
      end
    end
  elseif p == "fence" then
    self.call = { text = "ALLEZ !", big = true, ttl = 0.7 }
    self:resetPhrase()
  elseif p == "halt" then
    self.call = { text = "HALTE !", big = true }
  elseif p == "decision" then
    self.call = nil
    for i = 1, 2 do
      local f = self.f[i]
      f.hit = nil        -- the point leaves the target: the blade straightens
      f:relax()
    end
  elseif p == "break" then
    self.breakClock = 60
    self.call = { text = "BREAK", big = true }
  elseif p == "priority" then
    self.call = { text = "PRIORITY MINUTE", big = false }
  elseif p == "over" then
    self.call = nil
  end
end

function B:resetPhrase()
  self.row.holder, self.row.kind, self.row.since, self.row.chain = nil, nil, self.time, 0
  self.lights = {}
  self.hitKind = {}
  self.firstHitT = nil
  self.rowAtHit = nil
  self.haltReason = nil
  for i = 1, 2 do
    local f = self.f[i]
    f.hit = nil
    f.offKind = nil
    f.offense = false
    f.events = {}
  end
end

-- Put the fencers back on guard: on the en-garde lines after a touch, or
-- where they were, at fencing distance, after a halt without one.
function B:resetPositions(toLines)
  local a, b = self.f[1], self.f[2]
  local x1, x2
  if self.o.resetGap then
    x1, x2 = self.o.resetGap(self)
  elseif toLines then
    x1, x2 = B.startX(1), B.startX(2)
  else
    local mid = (a.x + b.x) / 2
    local gap = max(b.x - a.x, 3.4)
    mid = core.clamp(mid, -core.END + 0.6 + gap / 2, core.END - 0.6 - gap / 2)
    x1, x2 = mid - gap / 2, mid + gap / 2
  end
  a:walkTo(x1, "stand")
  b:walkTo(x2, "stand")
end

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------

function B:update(dt)
  self.acc = self.acc + min(dt, 0.1)
  local first = true
  while self.acc >= B.DT do
    self.acc = self.acc - B.DT
    self:step(B.DT, first)
    first = false
  end
  -- camera and effects at frame rate
  local a, b = self.f[1], self.f[2]
  local target = core.clamp((a.x + b.x) / 2, -5.6, 5.6)
  if not self.lockCam then self.cam = core.approach(self.cam, target, 5, dt) end
  self.refX = core.approach(self.refX or 0, core.clamp((a.x + b.x) / 2, -6, 6), 2.5, dt)
  -- body wires: moving towards your reel gives slack (the reel winds in a
  -- moment late), moving away pulls the wire taut; underdamped, so sudden
  -- moves leave a small wobble
  self.cordSag = self.cordSag or { { 0, 0 }, { 0, 0 } }
  for i = 1, 2 do
    local f, s = self.f[i], self.cordSag[i]
    local toReel = -(f.vx or 0) * f.homeFace
    local target = core.clamp(toReel, -1, 3) * 3.5
    local w, z = 9, 0.3
    s[2] = s[2] + (w * w * (target - s[1]) - 2 * z * w * s[2]) * dt
    s[1] = core.clamp(s[1] + s[2] * dt, -4, 22)
  end
  if self.cheer then
    self.cheer = self.cheer - dt
    if self.cheer <= 0 then self.cheer = nil end
  end
  if self.scoreGlow then
    for i = 1, 2 do self.scoreGlow[i] = math.max(0, self.scoreGlow[i] - dt) end
  end
  if self.shake > 0 then self.shake = max(0, self.shake - dt) end
  if self.call and self.call.ttl then
    self.call.ttl = self.call.ttl - dt
    if self.call.ttl <= 0 then self.call = nil end
  end
  if self.flash then
    self.flash.t = self.flash.t - dt
    if self.flash.t <= 0 then self.flash = nil end
  end
  local fx = self.fx
  for k = #fx, 1, -1 do
    local p = fx[k]
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(fx, k)
    else
      p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
      p.vy = p.vy - 6 * dt
    end
  end
end

function B:live()
  return self.phase == "fence" or self.phase == "lockout"
end

function B:step(h, first)
  self.time = self.time + h
  self.pt = self.pt + h
  local live = self:live()
  for i = 1, 2 do
    local f = self.f[i]
    if live then
      local pad = f.ctl and f.ctl:get(self, i, h, first) or EMPTY
      Ctl.apply(f, pad)
    else
      Ctl.idle(f)
      if f.ctl and f.ctl.idle then f.ctl:idle(self, i, h) end
    end
    f:update(h)
  end
  self:separate()

  if live then
    self:events(true)
    self:checkHits()
    self:events(false)
    self:updateRow()
    if self.o.drill and self.o.drill.step then self.o.drill:step(self, h) end
    if self.phase == "fence" then
      self:checkHalts()
      if not self.o.noClock and self.phase == "fence" then
        self.clock = self.clock - h
        if self.clock <= 0 then
          self.clock = 0
          self:halt("time")
        end
      end
    elseif self.phase == "lockout" and self.time - self.firstHitT >= B.LOCKOUT then
      self:halt("hit")
    end
  else
    self:events(false, true)
    if self.o.drill and self.o.drill.step then self.o.drill:step(self, h) end
  end
  self:phaseLogic(h)
  self.skip = false
end

-- Fencer events. Pass 1 (before the hit check) handles the start of
-- offensive actions and blade actions; pass 2 everything else.
function B:events(early, quiet)
  for i = 1, 2 do
    local f = self.f[i]
    local ev = f.events
    local k = 1
    local keep = {}
    while k <= #ev do
      local e = ev[k]
      local t = e.type
      local isEarly = (t == "offense" or t == "offense_cont" or t == "blade")
      if quiet then
        self:soundEvent(f, e)
      elseif early and isEarly then
        if t == "offense" then self:onOffense(i, e.a)
        elseif t == "offense_cont" then self:onOffenseCont(i)
        else self:onBlade(i) end
      elseif early then
        keep[#keep + 1] = e
      else
        if t == "offense_end" then
          self:onOffenseEnd(i, e.a)
        elseif t == "lunge_full" or t == "fleche_end" then
          if not self.lights[i] and f.offense then
            self.stats[i].short = (self.stats[i].short or 0) + 1
            f:endOffense("short")
          end
        end
        self:soundEvent(f, e)
      end
      k = k + 1
    end
    f.events = early and keep or {}
  end
end

function B:soundEvent(f, e)
  local t = e.type
  if t == "step" then self:sfx("step", 0.35, 0.9 + love.math.random() * 0.2)
  elseif t == "stomp" then self:sfx("stomp", 0.6 * (e.a or 1), 0.95 + love.math.random() * 0.1)
  elseif t == "swish" then self:sfx("swish", 0.35 * (e.a or 1), 0.9 + love.math.random() * 0.25)
  elseif t == "disengage" then self:sfx("swish", 0.2, 1.4)
  end
end

---------------------------------------------------------------------------
-- Right of way
---------------------------------------------------------------------------

function B:onOffense(i, action)
  local f, o = self.f[i], self.f[3 - i]
  local row, now = self.row, self.time
  f.offStart = now
  f.offFlavor = action
  f.offStartX = f.x
  self.stats[i].attacks = self.stats[i].attacks + 1
  if row.holder == i then
    if row.kind == "parry" then
      f.offKind = row.chain > 1 and "counter-riposte" or "riposte"
    elseif row.kind == "beat" then
      f.offKind = "beat-attack"
    else
      f.offKind = "attack"
    end
    row.kind = f.offKind
    row.since = now
  elseif row.holder == 3 - i then
    if row.kind == "attack" and now - row.since <= B.SIMUL and o.offense then
      row.holder = nil
      row.kind = "simultaneous"
      row.since = now
      f.offKind = "attack"
    else
      f.offKind = "counterattack"
    end
  else
    row.holder = i
    row.kind = "attack"
    row.since = now
    f.offKind = "attack"
  end
end

-- An extended arm becomes a lunge or flèche: same action, still an attack.
function B:onOffenseCont(i)
  local row = self.row
  local f = self.f[i]
  f.offFlavor = f.offAction
  if row.holder == i and row.kind == "line" then
    row.kind = "attack"
    row.since = self.time
    f.offKind = "attack"
  end
end

function B:onOffenseEnd(i, reason)
  local row, f = self.row, self.f[i]
  if row.holder == i and row.kind ~= "parry" and row.kind ~= "beat" then
    row.holder = nil
    row.kind = "ended"
    row.since = self.time
  end
  f.offKind = "remise"
end

function B:updateRow()
  local row, now = self.row, self.time
  if (row.kind == "parry" or row.kind == "beat") and now > row.deadline then
    row.holder = nil
    row.kind = "lapsed"
    row.since = now
  end
  if row.holder then
    local f = self.f[row.holder]
    if row.kind == "line" and not (f.arm == "extend" and f.aphase ~= "in") then
      row.holder = nil
      row.kind = nil
    elseif row.kind == "attack" and f.arm == "extend" and f.aphase == "held" and f.holdX
      and f.legs ~= "lunge" and f.legs ~= "fleche" and now - row.since > 0.2 then
      row.kind = "line"
      f.offKind = "line"
    end
  end
end

-- A blade action: if the other blade is still (on guard, in line or a
-- remise) and the blades cross, it is a beat and takes the priority.
-- Against a moving attack, the parry is judged when the point arrives.
function B:onBlade(i)
  local f, o = self.f[i], self.f[3 - i]
  self.stats[i].blades = (self.stats[i].blades or 0) + 1
  if o:attacking() then return end
  if o.arm ~= "guard" and o.arm ~= "extend" then return end
  local ft = f.x + f.face * f.j.tipx
  local ot = o.x + o.face * o.j.tipx
  local gap = (o.x - f.x) * f.face
  if (ft - ot) * f.face < -0.05 or gap > 3.2 then return end
  local wasHolder = self.row.holder == 3 - i
  o:beaten()
  if o.offense then
    o.offense = false
    self:onOffenseEnd(3 - i, "beaten")
  end
  local row = self.row
  row.holder = i
  row.kind = "beat"
  row.since = self.time
  row.deadline = self.time + B.BEATWIN
  row.chain = 0
  f:parrySucceeded()
  self.stats[i].beats = self.stats[i].beats + 1
  self.lastBeat = { by = i, line = wasHolder, t = self.time }
  local hx, hy = o:handWorld()
  self:sparks((ft + ot) / 2 * 0.5 + hx * 0.5, (hy + f.j.tipy) / 2, 5)
  self:sfx("beat", 0.7, 0.95 + love.math.random() * 0.1)
end

---------------------------------------------------------------------------
-- Hits
---------------------------------------------------------------------------

function B:checkHits()
  if self.firstHitT and self.time - self.firstHitT > B.LOCKOUT then return end
  for i = 1, 2 do
    local a, d = self.f[i], self.f[3 - i]
    if not self.lights[i] and a:canHit() then
      local tx, ty = a:tipWorld()
      local region = d:regionAt(tx, ty)
      if region then
        if d:parryActive() and d.parryLine == a.attackLine then
          self:onParry(3 - i, i)
        else
          self:registerHit(i, region, tx, ty)
        end
      end
    end
  end
end

function B:onParry(di, ai)
  local A, D = self.f[ai], self.f[di]
  local row = self.row
  local chain = 1
  if row.holder == ai and (row.kind == "riposte" or row.kind == "counter-riposte") then
    chain = (row.chain or 1) + 1
  end
  A:deflect()
  A.offKind = "remise"
  -- a parried flèche is checked in its run, open to the riposte
  if A.legs == "fleche" and A.fphase ~= "stop" then A:stopFleche() end
  row.holder = di
  row.kind = "parry"
  row.since = self.time
  row.chain = chain
  row.deadline = self.time + B.RIPOSTE
  D:parrySucceeded()
  self.stats[di].parries = self.stats[di].parries + 1
  self.lastParry = { by = di, line = D.parryLine, t = self.time }
  local hx, hy = D:handWorld()
  self:sparks(hx + D.face * 0.12, hy + 0.08, 8)
  self:sfx("parry", 0.8, 0.95 + love.math.random() * 0.1)
  if self.o.drill and self.o.drill.onParry then self.o.drill:onParry(self, di, ai) end
end

function B:registerHit(i, region, tx, ty)
  local a, d = self.f[i], self.f[3 - i]
  self.lights[i] = region
  self.hitKind[i] = a.offKind or "remise"
  -- the blade bends against the target: remember the point in the
  -- defender's own frame so it follows them
  a.hit = { lx = (tx - d.x) * d.face, ly = ty }
  d:flinch()
  if not self.firstHitT then
    self.firstHitT = self.time
    self.rowAtHit = { holder = self.row.holder, kind = self.row.kind }
    self.phase = "lockout"
  end
  if region == "off" then self.stats[i].offTarget = self.stats[i].offTarget + 1 end
  self.flash = { side = i, region = region, t = 0.12 }
  self:sfx("buzz", 0.55, region == "valid" and 1 or 1.12)
  self:sparks(tx, ty, 3)
end

function B:separate()
  local a, b = self.f[1], self.f[2]
  local gap = b.x - a.x
  local minGap = B.CORPS * 0.85
  if gap < minGap then
    local push = (minGap - gap) / 2
    for _, p in ipairs({ { a, -push }, { b, push } }) do
      local f, d = p[1], p[2]
      f.x, f.ffx, f.bfx = f.x + d, f.ffx + d, f.bfx + d
    end
  end
  for i = 1, 2 do
    local f = self.f[i]
    local lim = core.RUNOFF - 0.5
    local d = 0
    if f.x < -lim then d = -lim - f.x elseif f.x > lim then d = lim - f.x end
    if d ~= 0 then f.x, f.ffx, f.bfx = f.x + d, f.ffx + d, f.bfx + d end
  end
end

function B:checkHalts()
  local a, b = self.f[1], self.f[2]
  if b.x - a.x < B.CORPS then
    self.corpsFleche = (a.legs == "fleche" or b.legs == "fleche")
    self:halt("corps")
    return
  end
  if max(a.ffx, a.bfx) < -core.END then
    self.outSide = 1
    self:halt("out")
  elseif min(b.ffx, b.bfx) > core.END then
    self.outSide = 2
    self:halt("out")
  end
end

function B:halt(reason)
  if self.phase == "halt" then return end
  self.haltReason = self.haltReason or reason
  self:setPhase("halt")
end

---------------------------------------------------------------------------
-- Decision
---------------------------------------------------------------------------

function B:label(i)
  local k = self.hitKind[i] or "attack"
  local f = self.f[i]
  if k == "attack" and f.offFlavor == "fleche" then return "FLÈCHE ATTACK" end
  return B.LABEL[k] or "ATTACK"
end

function B:decide()
  local L = self.lights
  local r = self.haltReason
  local d = { scorer = nil, line1 = "", line3 = nil, kind = nil, lights = { L[1], L[2] } }
  if L[1] or L[2] then
    if L[1] and L[2] then
      local h = self.rowAtHit and self.rowAtHit.holder
      if not h then
        local simul = self.rowAtHit and self.rowAtHit.kind == "simultaneous"
        d.line1 = simul and "SIMULTANEOUS ATTACKS" or "SIMULTANEOUS ACTIONS"
        d.line3 = simul and "BOTH ATTACKED TOGETHER" or "NEITHER HAD PRIORITY"
        d.why = simul and "simultaneous" or "nopriority"
      elseif L[h] == "valid" then
        local o = 3 - h
        d.scorer = h
        d.kind = self.hitKind[h]
        d.line1 = self:label(h) .. " FROM THE " .. self:side(h)
        local ok = self.hitKind[o]
        if d.kind == "line" then
          d.line3 = "ATTACK INTO THE POINT IN LINE"
        elseif ok == "counterattack" then
          d.line3 = "COUNTERATTACK NOT IN TIME"
        elseif ok == "remise" then
          d.line3 = (d.kind == "riposte" or d.kind == "counter-riposte") and "THE RIPOSTE BEATS THE REMISE"
            or "THE REMISE HAS NO PRIORITY"
        else
          d.line3 = "PRIORITY TO THE " .. self:side(h)
        end
        d.why = "priority"
      else
        d.line1 = self:label(h) .. " OFF TARGET"
        d.line3 = "THE PRIORITY HIT WAS OFF TARGET"
        d.why = "priorityoff"
      end
    else
      local i = L[1] and 1 or 2
      if L[i] == "valid" then
        d.scorer = i
        d.kind = self.hitKind[i]
        d.line1 = self:label(i) .. " FROM THE " .. self:side(i)
        if d.kind == "counterattack" and self.rowAtHit and self.rowAtHit.holder == 3 - i then
          d.line3 = "COUNTERATTACK IN TIME"
        end
        d.why = "single"
      else
        d.line1 = "OFF TARGET"
        d.line3 = "ONLY THE TRUNK IS VALID IN FOIL"
        d.why = "off"
      end
    end
  elseif r == "out" then
    d.scorer = 3 - self.outSide
    d.line1 = "BACK LINE CROSSED"
    d.line3 = self:side(self.outSide) .. " LEFT THE PISTE"
    d.kind = "out"
    d.why = "out"
  elseif r == "corps" and self.corpsFleche then
    d.line1 = "FLÈCHE: NO HIT"
    d.line3 = "HALT AS THE FENCERS PASS"
    d.why = "pass"
  elseif r == "corps" then
    d.line1 = "CORPS-À-CORPS"
    d.line3 = "BODY CONTACT STOPS THE BOUT"
    d.why = "corps"
  elseif r == "time" then
    d.line1 = "TIME"
    d.why = "time"
  else
    d.line1 = "HALTE"
  end
  d.line2 = d.scorer and ("TOUCH " .. self:side(d.scorer)) or "NO TOUCH"
  d.time = (r == "time")
  return d
end

function B:applyDecision(d)
  if d.scorer then
    local s = d.scorer
    self.score[s] = self.score[s] + 1
    self.scoreGlow = self.scoreGlow or { 0, 0 }
    self.scoreGlow[s] = B.GLOW
    local st = self.stats[s]
    st.touches = st.touches + 1
    st.kinds[d.kind] = (st.kinds[d.kind] or 0) + 1
    self.stats[3 - s].against = self.stats[3 - s].against + 1
    self:sfx("cheer", 0.6, 0.95 + love.math.random() * 0.1)
    self.cheer = 2.0
  end
  if self.o.drill and self.o.drill.judge then
    local ok, msg = self.o.drill:judge(self, d)
    d.drillOk, d.drillMsg = ok, msg
  end
end

-- What comes after the decision.
function B:nextAfterDecision(d)
  if self.o.endless then
    return "reset", d.scorer ~= nil or d.why == "out"
  end
  local s1, s2 = self.score[1], self.score[2]
  if self.priorityMinute then
    if d.scorer then self.winner = d.scorer; return "over" end
    if d.time then self.winner = self.priorityHolder; return "over" end
    return "reset", false
  end
  if s1 >= self.touches or s2 >= self.touches then
    self.winner = s1 > s2 and 1 or 2
    return "over"
  end
  if d.time or self.clock <= 0 then
    if self.period < self.periods then
      self.period = self.period + 1
      self.clock = self.periodTime
      self.breakDone = true
      return "break"
    end
    if s1 == s2 then
      self.priorityMinute = true
      self.priorityHolder = love.math.random(1, 2)
      self.clock = 60
      return "priority"
    end
    self.winner = s1 > s2 and 1 or 2
    return "over"
  end
  if self.breakAt and not self.breakDone and max(s1, s2) >= self.breakAt then
    self.breakDone = true
    if self.period < self.periods then
      self.period = self.period + 1
      self.clock = self.periodTime
    end
    return "break"
  end
  return "reset", d.scorer ~= nil or d.why == "out"
end

function B:phaseLogic(h)
  local p, t = self.phase, self.pt
  if p == "intro" then
    local a, b = self.f[1], self.f[2]
    if self.skip and t > 0.2 then
      for i = 1, 2 do self.f[i]:place(B.startX(i), "guard") end
      self:setPhase("engarde")
      return
    end
    if t > 0.45 and not self.salute1 then
      self.salute1 = true
      for _, f in ipairs({ a, b }) do f:setPose(Fencer.ARM.salute1, Fencer.BACK.stand) end
    elseif t > 1.15 and not self.salute2 then
      self.salute2 = true
      for _, f in ipairs({ a, b }) do f:setPose(Fencer.ARM.salute2, Fencer.BACK.stand) end
    elseif t > 1.7 then
      self:setPhase("engarde")
    end
  elseif p == "engarde" then
    if t > 0.65 and self.call and self.call.text == "EN GARDE !" then
      self.call = { text = "PRÊTS ?", big = true }
    end
    if t > 1.3 then self:setPhase("fence") end
  elseif p == "halt" then
    if t > 0.85 then
      local d = self:decide()
      self:applyDecision(d)
      self.decision = d
      self:setPhase("decision")
    end
  elseif p == "decision" then
    if t > 2.6 or (self.skip and t > 0.5) then
      local nxt, toLines = self:nextAfterDecision(self.decision)
      if nxt == "over" then
        self:finish()
      elseif nxt == "break" then
        self:setPhase("break")
        self:resetPositions(true)
      elseif nxt == "priority" then
        self:setPhase("priority")
        self:resetPositions(true)
      else
        self:setPhase("reset")
        self:resetPositions(toLines)
      end
    end
  elseif p == "reset" then
    local a, b = self.f[1], self.f[2]
    if self.skip and t > 0.3 then
      a:finishWalk()
      b:finishWalk()
    end
    if (a.legs ~= "walk" and b.legs ~= "walk") or t > 6 then
      self:setPhase("engarde")
    end
  elseif p == "break" then
    self.breakClock = self.breakClock - h
    if self.breakClock <= 0 or (self.skip and t > 0.5) then self:setPhase("engarde") end
  elseif p == "priority" then
    if t > 2.6 or (self.skip and t > 0.6) then self:setPhase("engarde") end
  elseif p == "over" then
    if self.skip and t > 0.8 and not self.done then
      self.done = true
      if self.o.onFinish then self.o.onFinish(self) end
    end
  end
end

function B:finish()
  self:setPhase("over")
  self.over = true
  local w = self.winner
  for i = 1, 2 do
    local f = self.f[i]
    f:walkTo(f.x, "stand")
    if i == w then
      f:setPose(Fencer.ARM.victory, Fencer.BACK.victory, "stand")
    else
      f.standLean = 0.12
      f:setPose(Fencer.ARM.down, Fencer.BACK.stand, "stand")
    end
  end
  self:sfx("cheer", 0.9, 1)
  self.cheer = 3
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------

function B:sparks(x, y, n)
  if not love.graphics then return end
  local r = love.math.random
  for _ = 1, n do
    self.fx[#self.fx + 1] = {
      x = x, y = y, vx = (r() - 0.5) * 3, vy = r() * 2 + 0.5,
      life = 0.15 + r() * 0.2, col = r() < 0.5 and core.C.yellow or core.C.lampW,
    }
  end
end

function B:draw()
  require("src.view").draw(self)
end

return B
