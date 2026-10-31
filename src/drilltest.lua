-- Headless check that every training drill can be completed: a scripted
-- student does what the drill asks, against the real coach and referee.
--
--   love . --autotest drills

local Bout = require("src.bout")
local AI = require("src.ai")
local Fencer = require("src.fencer")
local TR = require("src.training")

local T = {}

local function student(think)
  local c = AI.new(4, "balanced")
  c.think = think
  return c
end

local function gap(b) return math.abs(b.f[2].x - b.f[1].x) end
local function reach() return Fencer.measure().lunge + 0.10 end
local function idle(me) return me.legs == "guard" and me.arm == "guard" end

T._students = {}
local STUDENTS = {
  -- 1 footwork: walk the front foot to each zone
  function(self, b, i, me, op, now)
    local d = b.o.drill
    local z = d:zoneX(d.count + 1)
    if not z or #self.sched > 0 then return end
    if math.abs(me.ffx - z) > 0.12 and me.legs == "guard" then
      self:move(((z - me.ffx) * me.face > 0) and 1 or -1, 0.06, now)
    end
  end,
  -- 2 lunge: close in, lunge
  function(self, b, i, me, op, now)
    if #self.sched > 0 or not idle(me) then return end
    if gap(b) > reach() - 0.05 then self:move(1, 0.06, now) else self:press(now, "a", "high", 0.5) end
  end,
  -- 3 high and low: lunge into the line the coach does not guard
  function(self, b, i, me, op, now)
    if #self.sched > 0 or not idle(me) then return end
    local open = op.ctl.guardLine == "high" and "low" or "high"
    if gap(b) > reach() - 0.05 then self:move(1, 0.06, now) else self:press(now, "a", open, 0.5) end
  end,
  -- 4 parry-riposte: parry in the attack's line, riposte with X
  function(self, b, i, me, op, now)
    local row = b.row
    if row.holder == i and row.kind == "parry" and self.answered ~= row.since then
      self.answered = row.since
      self:press(now + 0.15, "x", nil, 0.3)
      return
    end
    if op.offense and op.offStart and self.seen ~= op.offStart and now > op.offStart + 0.22 then
      self.seen = op.offStart
      local tHit = self:predict(me, op, now)
      self:planParry(now, tHit, op.attackLine)
    end
  end,
  -- 5 attack first: lunge as the coach steps into distance
  function(self, b, i, me, op, now)
    if #self.sched > 0 or not idle(me) then return end
    -- the coach is stepping into distance, or has just arrived
    local g = gap(b)
    if op.legs == "step" then g = g - 0.30 * (1 - math.min(1, op.lt / op.ld)) end
    if g < reach() - 0.05 and now - (op.stepT0 or 0) > 0.05 then self:press(now, "a", "high", 0.5) end
  end,
  -- 6 point in line: beat when the blades cross, the AI's beat logic lunges
  function(self, b, i, me, op, now)
    local row = b.row
    if row.holder == i and row.kind == "beat" and self.answered ~= row.since then
      self.answered = row.since
      self:press(now + 0.04, "a", "high", 0.5)
      return
    end
    if #self.sched > 0 or not idle(me) then return end
    local mt = me.x + me.face * me.j.tipx
    local ot = op.x + op.face * op.j.tipx
    if row.holder == 3 - i and row.kind == "line" and (mt - ot) * me.face > 0 and gap(b) < reach() - 0.05 then
      self:press(now, "b", "high")
    elseif gap(b) > reach() - 0.05 then
      self:move(1, 0.06, now)
    end
  end,
  -- 7 disengage: lunge high, switch low mid-way
  function(self, b, i, me, op, now)
    if #self.sched > 0 or not idle(me) then return end
    if gap(b) > reach() - 0.05 then self:move(1, 0.06, now); return end
    self:press(now, "a", "high", 0.5)
    self:press(now + 0.16, "down")
  end,
  -- 8 flèche from long range
  function(self, b, i, me, op, now)
    if #self.sched > 0 or not idle(me) then return end
    if gap(b) <= Fencer.measure().fleche - 0.15 then self:press(now, "y", "high")
    else self:move(1, 0.06, now) end
  end,
}

T._students = STUDENTS

function T.run()
  for side = 1, 2 do
  print(string.format("drills from the %s, scripted student (60 s each):", side == 1 and "left" or "right"))
  for n, def in ipairs(TR.DRILLS) do
    love.math.setRandomSeed(n)
    local opts, d = TR.setup(n, student(STUDENTS[n]), side)
    opts.silent = true
    local b = Bout.new(opts)
    TR.place(b, n)
    local t, decs, lastDec = 0, {}, nil
    while t < 60 and not b.over do
      b.skip = (b.phase == "decision" or b.phase == "over") and b.pt > 0.6
      b:step(Bout.DT, true)
      t = t + Bout.DT
      if b.decision and b.decision ~= lastDec then
        lastDec = b.decision
        local k = (b.decision.drillOk and "ok" or "no") .. ":" .. (b.decision.drillMsg or b.decision.line1)
        decs[k] = (decs[k] or 0) + 1
      end
    end
    local list = {}
    for k, v in pairs(decs) do list[#list + 1] = v .. "x " .. k end
    table.sort(list)
    print(string.format("%d %-14s %s %d/%d in %4.1f s   %s", n, def.name, d.done and "DONE" or "----",
      d.count, def.goal, t, table.concat(list, ", ")))
  end
  end
end

return T
