-- Training: drills with a scripted coach. Each coach is an AI (src/ai.lua)
-- with its own think(), so it moves and fences through the same virtual
-- pad as every other fencer. Success is judged from the referee's actual
-- decisions, so the drills teach the real rules.

local core = require("src.core")
local gfx = require("src.gfx")
local input = require("src.input")
local audio = require("src.audio")
local settings = require("src.settings")
local Play = require("src.play")
local AI = require("src.ai")
local Ctl = require("src.controller")
local Fencer = require("src.fencer")
local Menu = require("src.menu")
local Profile = require("src.profile")

local lg = love.graphics
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local C = core.C
local W, H, PPM, GROUND = core.W, core.H, core.PPM, core.GROUND
local rnd = function() return love.math.random() end

local TR = {}

local function coach(think, opts)
  local c = AI.new(2, "balanced")
  c.P.sigma = 0
  c.P.freeze = 0
  c.think = think
  if opts then for k, v in pairs(opts) do c[k] = v end end
  return c
end

local function gapOf(b) return b.f[2].x - b.f[1].x end
local function reachL() return Fencer.measure().lunge + 0.13 end

---------------------------------------------------------------------------
-- The drills
---------------------------------------------------------------------------

TR.DRILLS = {
  {
    name = "FOOTWORK",
    short = "ADVANCE, RETREAT AND JUMP",
    text = {
      "Fencing is distance. Move with ← and → (towards the coach is an advance). R1 is a quick jump forward (balestra), L1 a jump back.",
      "Put your FRONT FOOT in the green zone and stop there.",
    },
    keys = { { "←→", "STEP" }, { "R1", "JUMP FWD" }, { "L1", "JUMP BACK" } },
    goal = 6,
    gap = { -2.4, 3.4 },
    zones = { -1.4, -2.9, -0.4, -1.9, -3.6, -1.0 },
    coach = function() return coach(function() end) end,
    step = function(d, b, h)
      if d.done or not b:live() then return end
      local f = b.f[1]
      local z = d.zones[d.count + 1]
      local front = max(f.ffx, f.bfx)
      if abs(front - z) < 0.18 and f.legs == "guard" then
        d.hold = (d.hold or 0) + h
        if d.hold > 0.25 then
          d.hold = 0
          d:success("GOOD")
        end
      else
        d.hold = 0
      end
    end,
    drawWorld = function(d, b, sx)
      if d.done then return end
      local z = d.zones[d.count + 1]
      local x1, x2 = floor(sx(b, z - 0.18)), floor(sx(b, z + 0.18))
      local blink = floor(core.time * 4) % 2 == 0
      core.color(C.green, blink and 0.55 or 0.35)
      gfx.rect(x1, GROUND - 3, x2 - x1, 6)
      core.color(C.greenL)
      gfx.rect(x1, GROUND - 3, 1, 6)
      gfx.rect(x2, GROUND - 3, 1, 6)
    end,
  },
  {
    name = "THE LUNGE",
    short = "HIT FROM THE RIGHT DISTANCE",
    text = {
      "Close in until the distance at the bottom turns orange, then lunge with A. The front foot shoots forward and the arm extends first.",
      "Too far and the lunge falls short. Too close and you crowd yourself. The coach moves now and then.",
    },
    keys = { { "←→", "DISTANCE" }, { "A", "LUNGE" } },
    goal = 5,
    gap = { -1.7, 1.7 },
    coach = function()
      return coach(function(self, b, i, me, op, now)
        if #self.sched > 0 or me.legs ~= "guard" then return end
        self.nextMove = self.nextMove or now + 2
        if now >= self.nextMove then
          self.nextMove = now + 1.8 + rnd() * 2
          local dir = (me.x > 3.6 and 1) or (me.x < 0.6 and -1) or (rnd() < 0.5 and 1 or -1)
          self:move(dir, 0.1, now)
        end
      end)
    end,
    judge = function(d, b, dec)
      if dec.scorer == 1 then return true, "TOUCH!" end
    end,
    short_msg = "TOO FAR: THE LUNGE FELL SHORT",
  },
  {
    name = "HIGH AND LOW",
    short = "ATTACK THE OPEN LINE",
    text = {
      "The coach guards one line and parries anything that comes into it. The flashing mark shows the open line.",
      "Hold ↑ or ↓ as you press A to lunge into it: high is the chest, low the flank.",
    },
    keys = { { "↑↓", "LINE" }, { "A", "LUNGE" } },
    goal = 5,
    gap = { -1.3, 1.3 },
    coach = function()
      return coach(function(self, b, i, me, op, now)
        self.guardLine = self.guardLine or "high"
        if me.line ~= self.guardLine and me.arm == "guard" and #self.sched == 0 then
          self:press(now, self.guardLine == "high" and "up" or "down")
        end
        if op.offense and op.offStart and self.seen ~= op.offStart then
          self.seen = op.offStart
          local tHit = self:predict(me, op, now)
          self:planParry(now, tHit, self.guardLine)
        end
      end)
    end,
    onReset = function(d, b)
      local c = b.f[2].ctl
      c.guardLine = rnd() < 0.5 and "high" or "low"
    end,
    judge = function(d, b, dec)
      if dec.scorer == 1 then return true, "INTO THE OPEN LINE!" end
    end,
    onParry = function(d, b, di)
      if di == 2 then d:toast("PARRIED: GO FOR THE OPEN LINE") end
    end,
    drawWorld = function(d, b, sx)
      local f = b.f[2]
      local c = f.ctl
      if not c.guardLine or not b:live() then return end
      local open = c.guardLine == "high" and 0.18 or 0.66
      local j = f.j
      local x = floor(sx(b, f.x + f.face * (j.hipx + (j.neckx - j.hipx) * open + 0.16)))
      local y = floor(GROUND - (j.hipy + (j.necky - j.hipy) * open) * PPM)
      if floor(core.time * 5) % 2 == 0 then
        core.color(C.yellow)
        gfx.rect(x - 1, y - 1, 3, 3)
        core.color(C.ink)
        gfx.px(x, y)
      end
    end,
  },
  {
    name = "PARRY-RIPOSTE",
    short = "TAKE THE PRIORITY WITH A PARRY",
    text = {
      "The coach will lunge, high or low. Parry with B, holding ↑ or ↓ for the line the attack comes in (watch the orange arrow).",
      "A parry takes the priority: riposte at once with X.",
    },
    keys = { { "B", "PARRY" }, { "↑↓", "LINE" }, { "X", "RIPOSTE" } },
    goal = 5,
    gap = { -1.375, 1.375 },
    coachSpd = 0.85,
    coach = function()
      return coach(function(self, b, i, me, op, now)
        if #self.sched > 0 or me.legs ~= "guard" or me.arm ~= "guard" then return end
        -- lunge from 1.9-2.2 m, so the attack takes long enough to read
        local gap = gapOf(b)
        if gap > 2.2 or gap < 1.9 then
          if now >= (self.nextStep or 0) then
            self:move(gap > 2.2 and 1 or -1, 0.08, now)
            self.nextStep = now + 0.5
          end
          self.waitUntil = nil
        elseif not self.waitUntil then
          self.waitUntil = now + 0.6 + rnd() * 0.9
        elseif now >= self.waitUntil then
          self.waitUntil = nil
          self:press(now, "a", rnd() < 0.5 and "high" or "low", 0.9)
        end
      end)
    end,
    judge = function(d, b, dec)
      if dec.scorer == 1 and (dec.kind == "riposte" or dec.kind == "counter-riposte") then
        return true, "PARRY-RIPOSTE!"
      elseif dec.scorer == 2 then
        return false, "PARRY IN THE LINE OF THE ATTACK"
      elseif dec.scorer == 1 then
        return false, "PARRY FIRST, THEN RIPOSTE"
      end
    end,
  },
  {
    name = "ATTACK FIRST",
    short = "PRIORITY GOES TO WHOEVER STARTS",
    text = {
      "The coach steps forward (preparation) and lunges as soon as it is in distance. If you wait and both lamps light, its attack has the priority.",
      "Lunge while it is still stepping in: your attack starts first, so it is yours.",
    },
    keys = { { "A", "LUNGE" }, { "←→", "DISTANCE" } },
    goal = 3,
    gap = { -1.75, 1.75 },
    coach = function()
      return coach(function(self, b, i, me, op, now)
        if #self.sched > 0 or op.offense then return end
        if me.legs ~= "guard" and me.legs ~= "step" then return end
        local gap = gapOf(b)
        if gap > reachL() - 0.1 then
          if now >= (self.nextStep or 0) then
            self:move(1, 0.08, now)
            self.nextStep = now + 0.55 + rnd() * 0.5
          end
          self.inDistance = nil
        elseif me.arm == "guard" then
          -- a short pause in distance: the moment to attack into
          self.inDistance = self.inDistance or now
          if now - self.inDistance > 0.35 then
            self:press(now, "a", rnd() < 0.5 and "high" or "low", 0.5)
            self.inDistance = nil
          end
        end
      end)
    end,
    judge = function(d, b, dec)
      if dec.scorer == 1 and (dec.kind == "attack" or dec.kind == "beat-attack") then
        return true, "YOUR ATTACK HAD PRIORITY!"
      elseif dec.scorer == 2 then
        return false, "ITS ATTACK STARTED FIRST"
      end
    end,
  },
  {
    name = "POINT IN LINE",
    short = "BEAT THE BLADE, THEN ATTACK",
    text = {
      "The coach holds its arm straight with the point at you: a point in line. It has the priority, so attacking straight into it loses.",
      "When the blades cross, beat its blade with B, then lunge at once with A.",
    },
    keys = { { "B", "BEAT" }, { "A", "LUNGE" } },
    goal = 3,
    gap = { -1.45, 1.45 },
    coach = function()
      return coach(function(self, b, i, me, op, now)
        if me.arm == "guard" and #self.sched == 0 and not (self.holdUntil.x and now < self.holdUntil.x) then
          self:press(now, "x", "high", 1000)
        end
        -- lost the line (beaten, or the phrase moved on): take it again
        local holding = me.arm == "extend" and b.row.holder == i
        if holding or op.offense or me.arm ~= "extend" then
          self.lostT = nil
        else
          self.lostT = self.lostT or now
          if now - self.lostT > 0.7 then
            self.holdUntil.x = nil
            self.lostT = nil
          end
        end
      end)
    end,
    judge = function(d, b, dec)
      if dec.scorer == 1 and dec.kind == "beat-attack" then
        return true, "BEAT-ATTACK!"
      elseif dec.scorer == 2 then
        return false, "BEAT THE BLADE FIRST (B)"
      elseif dec.scorer == 1 then
        return false, "GOOD, BUT BEAT THE BLADE FIRST"
      end
    end,
  },
  {
    name = "DISENGAGE",
    short = "CHANGE LINE DURING THE LUNGE",
    text = {
      "This coach parries the line your attack STARTS in.",
      "Lunge in one line, then press the other direction (↑ or ↓) while your arm is going out: the blade slips round the parry.",
    },
    keys = { { "A", "LUNGE" }, { "↑↓", "SWITCH" } },
    goal = 3,
    gap = { -1.05, 1.05 },
    coach = function()
      return coach(function(self, b, i, me, op, now)
        if op.offense and op.offStart and self.seen ~= op.offStart then
          self.seen = op.offStart
          local tHit = self:predict(me, op, now)
          local first = op.attackLine
          self.readLine = first
          -- read the line once, early; then parry it on time
          self:press(op.offStart + 0.12, "none", nil, nil, function(s, bb, m, o)
            s.readLine = o.attackLine
            return true
          end)
          local e = { t = max(now, tHit - 0.12), btn = "b" }
          e.cond = function(s) e.line = s.readLine; return true end
          self.sched[#self.sched + 1] = e
        end
      end)
    end,
    judge = function(d, b, dec)
      if dec.scorer == 1 then return true, "AROUND THE PARRY!" end
    end,
    onParry = function(d, b, di)
      if di == 2 then d:toast("PARRIED: SWITCH LINE MID-LUNGE") end
    end,
  },
  {
    name = "FLÈCHE",
    short = "SCORE FROM LONG DISTANCE",
    text = {
      "This coach steps back whenever you step in. Close the gap in one explosive move:",
      "Y is a flèche, a running attack. Or jump forward with R1 and lunge with A as you land.",
    },
    keys = { { "Y", "FLÈCHE" }, { "R1", "JUMP" }, { "A", "LUNGE" } },
    goal = 3,
    gap = { -1.6, 1.6 },
    coach = function()
      return coach(function(self, b, i, me, op, now)
        if #self.sched > 0 or me.legs ~= "guard" then return end
        local dRear = core.END + me.face * me.x
        local gap = gapOf(b)
        local seen = op.legs == "step" and op.sdir > 0 and (op.time - (op.stepT0 or op.time)) > 0.2
        if seen and gap < 3.4 and dRear > 1.0 then
          self:move(-1, 0.1, now)
        elseif gap < 2.7 and dRear > 1.0 and not op.offense and op.legs == "guard" then
          self:move(-1, 0.1, now)
        end
      end)
    end,
    step = function(d, b)
      local f = b.f[1]
      if f.legs == "jump" and f.jdir > 0 then d.jumpT = b.time end
    end,
    judge = function(d, b, dec)
      if dec.scorer == 1 then
        local f = b.f[1]
        if f.offFlavor == "fleche" or (d.jumpT and b.time - d.jumpT < 2.5) then
          return true, "FROM LONG RANGE!"
        end
        return false, "USE THE FLÈCHE OR THE JUMP"
      end
    end,
    short_msg = "SHORT: GET A LITTLE CLOSER FIRST",
  },
}

---------------------------------------------------------------------------
-- Running a drill
---------------------------------------------------------------------------

local Drill = {}
Drill.__index = Drill

function Drill:toast(s)
  self.msg = { text = s, t = 1.8 }
end

function Drill:success(msg)
  self.count = self.count + 1
  self:toast(msg)
  audio.play("fanfare", 0.25, 1.5)
  if self.count >= self.def.goal and not self.done then
    self.done = true
    Profile.markDrill(self.n)
  end
end

function Drill:step(b, h)
  if self.msg then
    self.msg.t = self.msg.t - h
    if self.msg.t <= 0 then self.msg = nil end
  end
  local st = b.stats[1]
  if (st.short or 0) > self.shorts then
    self.shorts = st.short or 0
    if self.def.short_msg then self:toast(self.def.short_msg) end
  end
  if self.def.step then self.def.step(self, b, h) end
  if b.phase ~= self.lastPhase then
    if b.phase == "engarde" and self.def.onReset then self.def.onReset(self, b) end
    self.lastPhase = b.phase
  end
  if self.done and not b.over and (b.phase == "reset" or b:live()) and (not self.msg or self.msg.t < 1.0) then
    b.winner = 1
    b:finish()
  end
end

function Drill:judge(b, dec)
  if not self.def.judge then return nil end
  local ok, msg = self.def.judge(self, b, dec)
  if ok then
    self.count = self.count + 1
    audio.play("fanfare", 0.25, 1.5)
    if self.count >= self.def.goal and not self.done then
      self.done = true
      Profile.markDrill(self.n)
    end
  end
  return ok, msg
end

function Drill:onParry(b, di, ai)
  if self.def.onParry then self.def.onParry(self, b, di, ai) end
end

function Drill:drawWorld(b, sx)
  if self.def.drawWorld then self.def.drawWorld(self, b, sx) end
end

function Drill:drawHud(b)
  local def = self.def
  local y = 20
  gfx.panel(2, y, W - 4, 12, C.panel, C.edge, 0.85)
  gfx.text(self.n .. " · " .. def.name, 6, y + 3, C.yellow)
  gfx.text(string.format("%d/%d", min(self.count, def.goal), def.goal), W - 6, y + 3,
    self.done and C.greenL or C.text, "right")
  if self.msg and b.phase ~= "decision" then
    gfx.text(self.msg.text, W / 2, 44, C.yellow, "center", true)
  end
  if b:live() then
    gfx.hints(def.keys, W / 2, 135, "center")
  end
end

-- Bout options for drill n, with the given controller for the player.
function TR.setup(n, playerCtl)
  local def = TR.DRILLS[n]
  local d = setmetatable({ def = def, n = n, count = 0, shorts = 0, zones = def.zones }, Drill)
  local me, nation = Profile.fencer()
  local opts = {
    left = { name = me, nation = nation, human = true, ctl = playerCtl },
    right = { name = "COACH", ctl = def.coach(), spd = def.coachSpd or 0.95 },
    touches = 999, endless = true, noClock = true, skipIntro = true,
    drill = d, title = "TRAINING", quitLabel = "LEAVE DRILL",
    resetGap = function() return def.gap[1], def.gap[2] end,
  }
  return opts, d
end

-- Put a new drill bout on the drill's marks.
function TR.place(b, n)
  local def = TR.DRILLS[n]
  b.f[1]:place(def.gap[1], "guard")
  b.f[2]:place(def.gap[2], "guard")
  b.cam = (def.gap[1] + def.gap[2]) / 2
  if def.onReset then def.onReset(b.o.drill, b) end
end

function TR.start(app, n, direct)
  local def = TR.DRILLS[n]
  local function back() TR.menu(app, n) end
  local function go()
    local opts = TR.setup(n, Ctl.human(input))
    opts.restart, opts.onQuit, opts.onFinish = go, back, back
    app.set(Play.new(app, opts))
    TR.place(app.current().bout, n)
  end
  if direct then return go() end
  -- the intro card
  local s = {}
  function s:update()
    if input.pressed.a then audio.play("select", 0.5); go()
    elseif input.pressed.b then audio.play("back", 0.5); back() end
  end
  function s:draw()
    core.color(C.night)
    gfx.rect(0, 0, W, H)
    gfx.panel(10, 8, W - 20, H - 16)
    gfx.text("DRILL " .. n, W / 2, 13, C.dim, "center")
    gfx.text(def.name, W / 2, 24, C.yellow, "center", false, 2)
    local y = 44
    for _, para in ipairs(def.text) do
      y = y + gfx.para(para, 18, y, W - 36, C.text, 10) + 4
    end
    gfx.hints(def.keys, W / 2, H - 42, "center")
    gfx.text(string.format("GOAL: %d", def.goal), W / 2, H - 27, C.dim, "center")
    gfx.hints({ { "A", "START" }, { "B", "BACK" } }, W / 2, H - 19, "center")
  end
  app.set(s)
end

function TR.menu(app, sel)
  local items = {}
  for n, def in ipairs(TR.DRILLS) do
    items[#items + 1] = {
      label = n .. ". " .. def.name,
      value = function() return Profile.drillDone(n) and "DONE" or "" end,
      action = function() TR.start(app, n) end,
      hint = def.short,
    }
  end
  items[#items + 1] = { label = "BACK", action = function() app.toTitle() end }
  local m = Menu.new(items, { back = function() app.toTitle() end })
  m.sel = sel or 1
  local s = {}
  function s:update() m:update() end
  function s:draw()
    core.color(C.night)
    gfx.rect(0, 0, W, H)
    gfx.panel(20, 6, W - 40, H - 12)
    gfx.text("TRAINING", W / 2, 11, C.yellow, "center")
    local hint = m:draw(26, 24, W - 52)
    local done = 0
    for n2 = 1, #TR.DRILLS do if Profile.drillDone(n2) then done = done + 1 end end
    gfx.text(hint or string.format("%d OF %d DRILLS DONE", done, #TR.DRILLS), W / 2, H - 28, C.dim, "center")
    gfx.hints({ { "A", "START" }, { "B", "BACK" } }, W / 2, H - 19, "center")
  end
  app.set(s)
end

return TR
