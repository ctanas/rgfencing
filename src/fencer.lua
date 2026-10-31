-- Fencer: body model, footwork and blade actions.
--
-- A fencer is a small skeleton in metres. Local coordinates: +x is forward
-- (towards the opponent), +y is up, the origin is on the floor under the
-- pelvis. World x = self.x + self.face * localX.
--
-- Two layers run side by side:
--   legs  guard | step | jump | lunge | fleche | walk | stand
--   arm   guard | extend | parry | deflect | beaten | pose
-- Commands (from the human or the AI, through src/controller.lua) are
-- buffered for a moment, so a press during a step still comes out.
--
-- The fencer knows nothing about the rules. It reports what it does as
-- events (offense started/ended, blade action, footstep...) and the bout
-- (src/bout.lua) turns them into right-of-way, lights and touches.

local core = require("src.core")

local sin, cos, atan2, sqrt, abs = math.sin, math.cos, math.atan2, math.sqrt, math.abs
local max, min, pi, acos = math.max, math.min, math.pi, math.acos
local clamp, lerp, approach = core.clamp, core.lerp, core.approach
local seg, smooth, easeOut = core.seg, core.smooth, core.easeOut

-- Damped spring on s = { value, velocity }: pulls towards target with
-- angular frequency w (rad/s) and damping ratio z (< 1 overshoots).
local function spring(s, target, w, z, dt)
  local a = w * w * (target - s[1]) - 2 * z * w * s[2]
  s[2] = s[2] + a * dt
  s[1] = s[1] + s[2] * dt
end

local function easeOutBack(u)
  local c1 = 1.70158
  return 1 + (c1 + 1) * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
end

local F = {}
F.__index = F

-- Body (m)
F.THIGH, F.SHIN, F.ANKLE = 0.50, 0.48, 0.06
F.TORSO = 0.52
F.UPPER, F.FORE, F.BLADE = 0.30, 0.28, 0.88
local THIGH, SHIN, ANKLE, TORSO = F.THIGH, F.SHIN, F.ANKLE, F.TORSO
local UPPER, FORE, BLADE = F.UPPER, F.FORE, F.BLADE

-- Stance: feet relative to the pelvis, pelvis height.
F.STANCE_F, F.STANCE_B = 0.40, -0.38
local STANCE_F, STANCE_B = F.STANCE_F, F.STANCE_B
local GUARD_HY, STAND_HY, LUNGE_HY = 0.80, 0.98, 0.57

-- Timings (s) and distances (m), at speed 1.
F.T = {
  step = 0.24, stepDist = 0.30,
  jumpF = 0.30, jumpFDist = 0.55,
  jumpB = 0.32, jumpBDist = 0.60,
  ext = 0.09, lungeExt = 0.07, lungeDrive = 0.30,
  lungeFoot = 0.80, lungePelvis = 0.45, lungeHold = 1.2, recover = 0.30,
  withdraw = 0.10,
  parrySnap = 0.04, parryActive = 0.18, parryBonus = 0.06, parryReturn = 0.12, parryCool = 0.10,
  deflect = 0.32, beaten = 0.28,
  flecheExt = 0.08, flecheLaunch = 0.10, flecheRun = 0.36, flecheDist = 1.25, flecheStop = 0.35,
  switch = 0.08,
}
local T = F.T

-- Sword arm poses: { upper arm, forearm, blade } as absolute angles
-- (0 = straight forward, + = up).
local ARM = {
  guard = { high = { -1.05, 0.12, 0.22 }, low = { -1.15, -0.10, -0.42 } },
  parry = { high = { -0.70, 0.62, 1.12 }, low = { -1.32, -0.48, -1.08 } },
  deflect = { high = { -0.25, 0.55, 1.50 }, low = { -0.95, -0.75, -1.45 } },
  stand = { -1.50, -1.32, -1.10 },
  salute1 = { -0.70, 1.62, 1.57 },
  salute2 = { -0.55, -0.30, -0.80 },
  victory = { 1.05, 1.30, 1.45 },
  down = { -1.45, -1.25, -1.30 },
}
F.ARM = ARM
-- Non-sword arm: { upper arm, forearm }, kept in (pi/2 .. 3pi/2) so they
-- interpolate the right way round.
local BACK = {
  guard = { pi - 0.25, pi / 2 + 0.35 },
  lunge = { pi + 0.42, pi + 0.40 },
  fleche = { pi + 0.30, pi + 0.15 },
  stand = { 3 * pi / 2 - 0.12, 3 * pi / 2 - 0.04 },
  victory = { pi - 0.55, pi / 2 + 0.10 },
}
F.BACK = BACK

function F.new(o)
  local f = setmetatable({}, F)
  f.face = o.face or 1
  f.homeFace = f.face
  f.side = o.side or 1
  f.spd = o.spd or 1
  f.line = "high"
  f.attackLine = "high"
  f.events = {}
  f.j = {}
  f.l0 = {}
  f.a0 = { 0, 0, 0 }
  f.time = 0
  f:place(o.x or 0, o.pose or "guard")
  return f
end

function F:emit(kind, a, b)
  local e = self.events
  e[#e + 1] = { type = kind, a = a, b = b }
end

-- Put the fencer at pelvis x in a clean guard (or standing) pose.
function F:place(x, mode)
  self.x = x
  self.face = self.homeFace or self.face
  local face = self.face
  local arm, back
  if mode == "stand" then
    self.ffx, self.bfx = x + face * 0.12, x - face * 0.12
    self.hy, self.lean = STAND_HY, 0
    arm, back = ARM.stand, BACK.stand
    self.legs, self.arm = "stand", "pose"
    self.poseArm, self.poseBack = ARM.stand, BACK.stand
  else
    self.ffx, self.bfx = x + face * STANCE_F, x + face * STANCE_B
    self.hy, self.lean = GUARD_HY, 0.06
    arm, back = ARM.guard[self.line], BACK.guard
    self.legs, self.arm = "guard", "guard"
  end
  self.ffy, self.bfy = 0, 0
  self.ffp, self.bfp = 0, 0
  self.vface = face
  self.vx, self.glide, self.prevX = 0, 0, x
  self.walkSwing, self.protract = 0, 0
  self.wturn = nil
  self.sp = {
    hip = { 0, 0 }, lean = { 0, 0 }, head = { 0, 0 }, blade = { 0, 0 },
    b1 = { back[1], 0 }, b2 = { back[2], 0 },
  }
  self.a1, self.a2, self.bl = arm[1], arm[2], arm[3]
  self.ba1, self.ba2 = back[1], back[2]
  self.lt, self.ld, self.at, self.ad = 0, 1, 0, 1
  self.offense, self.offAction, self.offKind = false, nil, nil
  self.cmd, self.cmdArg, self.cmdT = nil, nil, 0
  self.holdA, self.holdX, self.wantDir = false, false, 0
  self.switchT = 0
  self.hit = nil
  self.lungeLanded = false
  self.parryLine = nil
  self.events = {}
  self:computeJoints()
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function F:toWorld(lx) return self.x + self.face * lx end

function F:tipWorld()
  local j = self.j
  return self.x + self.face * j.tipx, j.tipy
end

function F:handWorld()
  local j = self.j
  return self.x + self.face * j.hx, j.hy
end

-- The arm is extended and threatening: only then can the point register.
function F:canHit()
  if self.arm ~= "extend" or self.switchT > 0 then return false end
  if self.aphase == "held" then return true end
  if self.aphase == "out" then return self.at >= 0.5 * self.ad end
  return false
end

function F:parryActive()
  if self.arm ~= "parry" then return false end
  local p = self.pphase
  return p == "active" or (p == "snap" and self.at >= 0.5 * self.ad)
end

-- Lunge in progress (until the recovery starts).
function F:lunging()
  return self.legs == "lunge" and self.lphase ~= "recover"
end

-- Point travelling forward as part of an attack (not a held arm).
function F:attacking()
  if self.legs == "lunge" then return self.lphase == "ext" or self.lphase == "drive" end
  if self.legs == "fleche" then return self.fphase ~= "stop" end
  return self.arm == "extend" and self.aphase == "out"
end

-- Which part of this fencer, if any, is at world point (wx, wy)?
-- "valid" = the lamé (trunk), "off" = mask or legs. Arms are ignored: in a
-- side view they are beside the body, not in front of it.
function F:regionAt(wx, wy)
  local j = self.j
  local lx, ly = (wx - self.x) * self.face, wy
  -- trunk
  local sl, cl = sin(j.lean), cos(j.lean)
  local dx, dy = lx - j.hipx, ly - j.hipy
  local s = (dx * sl + dy * cl) / TORSO
  local t = dx * cl - dy * sl
  if s >= -0.02 and s <= 0.95 and t >= -0.13 and t <= 0.14 then return "valid" end
  -- mask
  local hx, hy = lx - j.headx, ly - j.heady
  if hx * hx + hy * hy <= 0.15 * 0.15 then return "off" end
  -- legs
  local function nearSeg(ax, ay, bx, by, r)
    local vx, vy = bx - ax, by - ay
    local L2 = vx * vx + vy * vy
    local u = L2 > 0 and clamp(((lx - ax) * vx + (ly - ay) * vy) / L2, 0, 1) or 0
    local px, py = ax + vx * u - lx, ay + vy * u - ly
    return px * px + py * py <= r * r
  end
  if nearSeg(j.hipx + 0.03, j.hipy, j.fkx, j.fky, 0.09) or nearSeg(j.fkx, j.fky, j.ffx, j.ffy, 0.07)
    or nearSeg(j.hipx - 0.03, j.hipy, j.bkx, j.bky, 0.09) or nearSeg(j.bkx, j.bky, j.bfx, j.bfy, 0.07) then
    return "off"
  end
  return nil
end

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------

function F:queue(cmd, arg)
  self.cmd, self.cmdArg, self.cmdT = cmd, arg, 0.15
end

-- Up/down: changes the guard line, or the attack line (a disengage) while
-- the arm is going out.
function F:lineInput(line)
  if self.arm == "extend" and (self.aphase == "out" or self.aphase == "held") then
    if line ~= self.attackLine then
      self.attackLine = line
      self.switchT = T.switch / self.spd
      self:emit("disengage")
    end
  end
  self.line = line
end

local function armFree(self)
  local a = self.arm
  return a == "guard" or a == "extend" or (a == "parry" and (self.pphase == "ret" or self.pphase == "cool" or self.parryWon))
end

function F:can(cmd, arg)
  local L = self.legs
  if cmd == "lunge" then
    if not armFree(self) then return false end
    if L == "guard" then return true end
    if L == "step" then return self.lt >= 0.6 * self.ld end
    if L == "jump" then return self.jdir > 0 and self.lt >= 0.7 * self.ld end
    return false
  elseif cmd == "extend" then
    return armFree(self) and L ~= "fleche" and L ~= "walk" and L ~= "stand"
      and not (self.arm == "extend" and self.aphase ~= "in")
  elseif cmd == "blade" then
    local a = self.arm
    if L == "walk" or L == "stand" or L == "fleche" then return false end
    if a == "guard" or a == "extend" then return true end
    -- successive parry in the other line
    if a == "parry" then return self.pphase ~= "cool" and arg ~= self.parryLine end
    return false
  elseif cmd == "fleche" then
    if not armFree(self) then return false end
    return L == "guard" or (L == "step" and self.lt >= 0.6 * self.ld)
  elseif cmd == "jump" then
    if L == "guard" then return true end
    if L == "step" then return self.lt >= 0.6 * self.ld end
    return false
  end
  return false
end

function F:run(cmd, arg)
  if cmd == "lunge" then self:startLunge(arg)
  elseif cmd == "extend" then self:startExtend(arg)
  elseif cmd == "blade" then self:startBlade(arg or self.line)
  elseif cmd == "fleche" then self:startFleche(arg)
  elseif cmd == "jump" then self:startJump(arg)
  end
end

-- An offensive action starts (or an extended arm turns into a lunge).
function F:beginOffense(action, line)
  local continuing = self.offense and self.arm == "extend" and self.aphase ~= "in"
  self.attackLine = line or self.line
  self.line = self.attackLine
  if continuing then
    self.offAction = action
    self:emit("offense_cont", action)
    return
  end
  self.offense = true
  self.offAction = action
  self:emit("offense", action)
end

function F:endOffense(reason)
  if self.offense then
    self.offense = false
    self:emit("offense_end", reason)
  end
end

function F:armExtend(dur)
  if self.arm == "extend" and (self.aphase == "out" or self.aphase == "held") then return end
  self.arm = "extend"
  self.aphase = "out"
  self.at = 0
  self.ad = dur / self.spd
  self.a0[1], self.a0[2], self.a0[3] = self.a1, self.a2, self.bl
  self.parryWon = false
end

function F:snapshot()
  local s = self.l0
  s.x, s.ffx, s.bfx, s.hy, s.lean = self.x, self.ffx, self.bfx, self.hy, self.lean
  s.ba1, s.ba2, s.ffy, s.bfy = self.ba1, self.ba2, self.ffy, self.bfy
  return s
end

function F:startLunge(line)
  -- an advance in progress: the back foot finishes its travel during the drive
  local bEnd = self.bfx
  if self.legs == "step" or self.legs == "jump" then bEnd = self.endB end
  self:beginOffense("lunge", line)
  local s = self:snapshot()
  s.bEnd = bEnd
  s.fStart = self.legs == "step" and self.endF or self.ffx
  self.legs = "lunge"
  self.lphase = "ext"
  self.lt = 0
  self.lungeLanded = false
  self.fwdAfterLunge = false
  self:armExtend(T.lungeExt)
end

function F:startExtend(line)
  self:beginOffense("extend", line)
  self:armExtend(T.ext)
end

function F:startFleche(line)
  self:beginOffense("fleche", line)
  self:snapshot()
  self.legs = "fleche"
  self.fphase = "ext"
  self.lt = 0
  self:armExtend(T.flecheExt)
end

function F:startStep(dir)
  self:snapshot()
  self.legs = "step"
  self.sdir = dir
  self.lt = 0
  self.stepT0 = self.time
  self.ld = T.step / self.spd
  self.stepSound = false
  local face = self.face
  self.endX = self.x + T.stepDist * dir * face
  self.endF = self.endX + face * STANCE_F
  self.endB = self.endX + face * STANCE_B
  -- the pelvis follows a Hermite curve from its current speed, and keeps
  -- cruising if the direction is still held: chained steps flow
  local cruise = T.stepDist / self.ld
  local v0 = clamp(self.vx * face * dir, -cruise, 1.4 * cruise)
  self.pX0, self.pX1 = self.x, self.endX
  self.pV0 = v0 * dir * face
  self.pV1 = (self.wantDir == dir) and cruise * dir * face or 0
  self.pT0, self.pD = 0, self.ld
end

local function hermite(self)
  local u = clamp((self.lt - self.pT0) / self.pD, 0, 1)
  local u2, u3, D = u * u, u * u * u, self.pD
  return (2 * u3 - 3 * u2 + 1) * self.pX0 + (u3 - 2 * u2 + u) * D * self.pV0
    + (-2 * u3 + 3 * u2) * self.pX1 + (u3 - u2) * D * self.pV1
end

function F:startJump(dir)
  self:snapshot()
  self.legs = "jump"
  self.jdir = dir
  self.lt = 0
  local face = self.face
  local dist = (dir > 0 and T.jumpFDist or T.jumpBDist) * dir
  self.ld = (dir > 0 and T.jumpF or T.jumpB) / self.spd
  self.endX = self.x + dist * face
  self.endF = self.endX + face * STANCE_F
  self.endB = self.endX + face * STANCE_B
  self:emit("swish", 0.4)
end

function F:startBlade(line)
  if self.offense then self:endOffense("withdrawn") end
  self.arm = "parry"
  self.pphase = "snap"
  self.at = 0
  self.ad = T.parrySnap / self.spd
  self.parryLine = line
  self.parryBonus = (line == self.line) and T.parryBonus or 0
  self.parryWon = false
  self.line = line
  self.a0[1], self.a0[2], self.a0[3] = self.a1, self.a2, self.bl
  self:emit("blade", line)
end

-- Push a spring (hip, lean, head, blade): secondary motion.
function F:kick(name, v)
  local s = self.sp[name]
  if s then s[2] = s[2] + v end
end

-- Touched: a flinch through the trunk and head.
function F:flinch()
  self:kick("lean", -1.6)
  self:kick("head", -3)
  self:kick("hip", 0.35)
end

-- My attack has been parried: blade knocked aside.
function F:deflect()
  self:kick("lean", -0.9)
  self:kick("head", -1.5)
  self.arm = "deflect"
  self.at = 0
  self.ad = T.deflect
  self.offense = false
  self.switchT = 0
  self.defl = ARM.deflect[self.attackLine]
end

-- Cut a flèche short (it was parried): decelerate from here.
function F:stopFleche()
  self.fphase = "stop"
  self.lt = 0
  local s = self.l0
  s.x, s.hy, s.lean = self.x, self.hy, self.lean
end

-- My blade has been beaten while in line or on guard.
function F:beaten()
  self.arm = "beaten"
  self.at = 0
  self.ad = T.beaten
  self.offense = false
  local g = ARM.guard[self.line]
  self.defl = { g[1] + 0.25, g[2] + 0.45, g[3] + (self.line == "high" and 0.85 or -0.75) }
end

-- My parry (or beat) found the blade: free to riposte straight away.
function F:parrySucceeded()
  self.parryWon = true
  self:kick("blade", (self.parryLine == "low") and -3.5 or 3.5)
end

-- Scripted pose for ceremonies (salute, victory...).
function F:setPose(arm, back, legs)
  self.arm = "pose"
  self.poseArm = arm
  self.poseBack = back
  if legs then
    if legs == "stand" and self.legs ~= "stand" then self:snapshot(); self.lt = 0 end
    if legs == "guard" and self.legs ~= "guard" then self.lt = 0 end
    self.legs = legs
  end
end

-- Walk to x, standing up, blade down. A long walk away from the
-- opponent turns round first (and back again on arrival).
function F:walkTo(x, pose)
  local home = self.homeFace
  self.legs = "walk"
  self.walkX = x
  self.walkPose = pose or "stand"
  self.walkPhase = 0
  self.offense = false
  self.wt = 0
  self.wturn = ((x - self.x) * home < -1.2) and "out" or nil
  if self.face ~= home then self.wturn = "walking" end
  if self.arm ~= "pose" then self:setPose(ARM.stand, BACK.stand) end
end

function F:finishWalk()
  if self.legs ~= "walk" then return end
  local d = self.walkX - self.x
  self.x, self.ffx, self.bfx = self.walkX, self.ffx + d, self.bfx + d
  self.prevX = self.x
  self.face, self.vface = self.homeFace, self.homeFace
  self.wturn = nil
  self.walkSwing = 0
  self.legs = "stand"
end

-- After "Halte!": stand up, blade down.
function F:relax()
  if self.legs == "walk" then return end
  self:setPose(ARM.stand, BACK.stand, "stand")
end

-- On "En garde!": the back foot goes back, the knees bend, the blade comes up.
function F:comeEnGarde()
  self:finishWalk()
  self:snapshot()
  self.legs = "engarde"
  self.lt = 0
  self.ld = 0.42
  self.endF = self.x + self.face * STANCE_F
  self.endB = self.x + self.face * STANCE_B
  self:setPose(ARM.guard[self.line], BACK.guard)
end

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------

function F:update(dt)
  self.time = self.time + dt
  if self.switchT > 0 then self.switchT = self.switchT - dt end
  if self.cmd then
    if self:can(self.cmd, self.cmdArg) then
      local c, a = self.cmd, self.cmdArg
      self.cmd = nil
      self:run(c, a)
    else
      self.cmdT = self.cmdT - dt
      if self.cmdT <= 0 then self.cmd = nil end
    end
  end
  if self.legs == "guard" and self.wantDir ~= 0 then
    if self.cmd == "jump" then
      -- the jump is about to go
    else
      self:startStep(self.wantDir)
    end
  end
  self:updateLegs(dt)
  self:updateArm(dt)
  -- velocity and secondary motion
  self.vx = (self.x - self.prevX) / dt
  self.prevX = self.x
  local vn = clamp(self.vx * self.face / 1.25, -1.6, 1.6)
  local sp, L = self.sp, self.legs
  local sw = (L == "walk") and self.walkSwing or 0
  spring(sp.hip, 0, 18, 0.42, dt)
  spring(sp.lean, (L == "step" or L == "guard" or L == "jump") and 0.07 * vn or 0, 12, 0.5, dt)
  spring(sp.head, 0, 16, 0.4, dt)
  spring(sp.blade, 0, 17, 0.32, dt)
  spring(sp.b1, self.ba1 - 0.18 * vn - 0.35 * sw, 14, 0.55, dt)
  spring(sp.b2, self.ba2 - 0.30 * vn - 0.25 * sw, 13, 0.5, dt)
  self.protract = approach(self.protract, (self.arm == "extend" and self.aphase ~= "in") and 1 or 0, 22, dt)
  self:computeJoints()
end

local function approachBack(self, target, rate, dt)
  self.ba1 = approach(self.ba1, target[1], rate, dt)
  self.ba2 = approach(self.ba2, target[2], rate, dt)
end

function F:updateLegs(dt)
  local L = self.legs
  local face = self.face
  local s = self.l0
  self.lt = self.lt + dt

  if L == "guard" then
    -- momentum left over from a step that wasn't continued
    if abs(self.glide) > 0.005 then
      self.x = self.x + self.glide * dt
      self.glide = self.glide * math.exp(-22 * dt)
    else
      self.glide = 0
    end
    -- a light bounce on bent knees, and breathing
    local ph = self.time * 2.6 + self.side * 1.7
    self.hy = approach(self.hy, GUARD_HY - 0.022 * (0.5 - 0.5 * cos(ph)), 12, dt)
    self.lean = approach(self.lean, 0.06 + 0.012 * sin(ph * 0.5), 12, dt)
    self.ffx = approach(self.ffx, self.x + face * STANCE_F, 16, dt)
    self.bfx = approach(self.bfx, self.x + face * STANCE_B, 16, dt)
    self.ffy = approach(self.ffy, 0, 25, dt)
    self.bfy = approach(self.bfy, 0, 25, dt)
    self.ffp = approach(self.ffp, 0, 20, dt)
    self.bfp = approach(self.bfp, 0, 20, dt)
    if self.arm ~= "pose" then approachBack(self, BACK.guard, 10, dt) end

  elseif L == "step" then
    local u = clamp(self.lt / self.ld, 0, 1)
    local lead, follow = seg(u, 0, 0.6), seg(u, 0.4, 1)
    if self.sdir > 0 then
      self.ffx = lerp(s.ffx, self.endF, smooth(lead))
      self.bfx = lerp(s.bfx, self.endB, smooth(follow))
      self.ffy = 0.05 * sin(pi * lead)
      self.bfy = 0.03 * sin(pi * follow)
      self.ffp = 0.35 * sin(pi * lead)       -- heel first, toe up
      self.bfp = -0.30 * sin(pi * follow)    -- pushes off the ball of the foot
    else
      self.bfx = lerp(s.bfx, self.endB, smooth(lead))
      self.ffx = lerp(s.ffx, self.endF, smooth(follow))
      self.bfy = 0.05 * sin(pi * lead)
      self.ffy = 0.03 * sin(pi * follow)
      self.bfp = -0.25 * sin(pi * lead)
      self.ffp = 0.25 * sin(pi * follow)
    end
    -- let go mid-step: re-plan to come to rest on the step's mark, taking
    -- as long as a steady deceleration needs (never speeding up)
    if self.pV1 ~= 0 and self.wantDir ~= self.sdir then
      local dirw = self.sdir * face
      local rest = max(0, (self.endX - self.x) * dirw)
      local v = max(0.05, self.vx * dirw)
      local D = clamp(1.5 * rest / v, 0.04, 0.3)
      self.pX0, self.pV0 = self.x, self.vx
      self.pT0, self.pD = self.lt, D
      self.pV1 = 0
      self.ld = max(self.ld, self.lt + D)
    end
    self.x = hermite(self)
    self.hy = approach(self.hy, GUARD_HY - 0.012 * sin(pi * u), 20, dt)
    self.lean = approach(self.lean, 0.06, 12, dt)
    if self.arm ~= "pose" then approachBack(self, BACK.guard, 10, dt) end
    if not self.stepSound and u >= 0.6 then
      self.stepSound = true
      self:emit("step")
      self:kick("hip", -0.35)
      self:kick("blade", -1.4)
    end
    -- change of direction early in the step
    if self.wantDir == -self.sdir and u < 0.45 then
      self:startStep(self.wantDir)
    elseif u >= 1 then
      if self.wantDir ~= 0 then
        self:startStep(self.wantDir)
      else
        self.legs = "guard"
        self.glide = (self.pV1 ~= 0) and self.vx or 0
        self:kick("hip", -0.25)
      end
    end

  elseif L == "jump" then
    local u = clamp(self.lt / self.ld, 0, 1)
    -- a quick crouch, the leap, and the landing taken in the knees
    local air = seg(u, 0.12, 1)
    local fa, ba = seg(u, 0.10, 0.92), seg(u, 0.16, 1)
    self.x = lerp(s.x, self.endX, smooth(air))
    self.ffx = lerp(s.ffx, self.endF, smooth(fa))
    self.bfx = lerp(s.bfx, self.endB, smooth(ba))
    self.ffy = 0.10 * sin(pi * fa)
    self.bfy = 0.08 * sin(pi * ba)
    self.ffp = -0.25 * sin(pi * fa)
    self.bfp = -0.30 * sin(pi * ba)
    self.hy = GUARD_HY - 0.035 * sin(pi * seg(u, 0, 0.14)) + 0.06 * sin(pi * air)
    if u >= 1 then
      self:emit("stomp", 0.6)
      self:kick("hip", -0.8)
      self:kick("blade", -2)
      self.legs = "guard"
    end

  elseif L == "lunge" then
    local ext, drive = T.lungeExt / self.spd, T.lungeDrive / self.spd
    if self.lphase == "ext" then
      self.lean = approach(self.lean, 0.10, 10, dt)
      self.ffp = approach(self.ffp, 0.35, 30, dt)
      if s.bEnd ~= self.bfx then self.bfx = approach(self.bfx, s.bEnd, 30, dt) end
      if self.lt >= ext then
        self.lphase = "drive"
        self.lt = self.lt - ext
        s.x, s.ffx, s.bfx, s.hy, s.lean = self.x, self.ffx, self.bfx, self.hy, self.lean
        s.ba1, s.ba2 = self.ba1, self.ba2
        self:emit("swish", 0.6)
      end
    end
    if self.lphase == "drive" then
      local v = clamp(self.lt / drive, 0, 1)
      local e = easeOut(v)
      local vf = min(1, v * 1.12)
      self.ffx = s.ffx + face * T.lungeFoot * easeOut(vf)
      self.ffy = 0.11 * sin(pi * vf)
      self.ffp = 0.5 * (1 - vf * vf)
      self.x = s.x + face * T.lungePelvis * e
      self.bfx = lerp(s.bfx, s.bEnd, min(1, v * 2.5))
      self.bfy = 0
      self.hy = lerp(s.hy, LUNGE_HY, e)
      self.lean = lerp(s.lean, 0.28, e)
      self.ba1 = lerp(s.ba1, BACK.lunge[1], e)
      self.ba2 = lerp(s.ba2, BACK.lunge[2], e)
      if v >= 1 then
        self.lphase = "hold"
        self.lt = 0
        self.ffy = 0
        self.lungeLanded = true
        self.ffp = 0
        self:kick("hip", -1.1)
        self:kick("lean", 0.7)
        self:kick("head", 2)
        self:emit("stomp", 1)
        self:emit("lunge_full")
      end
    elseif self.lphase == "hold" then
      if not self.holdA or self.lt > T.lungeHold or self.wantDir < 0 then
        self.lphase = "recover"
        self.lt = 0
        -- forward recovery only on a fresh press of forward during the lunge
        self.recFwd = self.wantDir > 0 and self.fwdAfterLunge
        s.x, s.ffx, s.bfx, s.hy, s.lean = self.x, self.ffx, self.bfx, self.hy, self.lean
        s.ba1, s.ba2 = self.ba1, self.ba2
      end
    elseif self.lphase == "recover" then
      local v = clamp(self.lt / (T.recover / self.spd), 0, 1)
      local e = smooth(v)
      if self.recFwd then
        -- forward recovery: the back foot comes up behind the front foot
        local px = s.ffx - face * STANCE_F
        self.x = lerp(s.x, px, e)
        self.bfx = lerp(s.bfx, s.ffx - face * (STANCE_F - STANCE_B), e)
        self.bfy = 0.06 * sin(pi * v)
      else
        local px = s.bfx - face * STANCE_B
        self.x = lerp(s.x, px, e)
        self.ffx = lerp(s.ffx, s.bfx + face * (STANCE_F - STANCE_B), e)
        self.ffy = 0.07 * sin(pi * v)
        self.ffp = 0.3 * sin(pi * v)
      end
      self.hy = lerp(s.hy, GUARD_HY, e)
      self.lean = lerp(s.lean, 0.06, e)
      self.ba1 = lerp(s.ba1, BACK.guard[1], e)
      self.ba2 = lerp(s.ba2, BACK.guard[2], e)
      if v >= 1 then
        self.legs = "guard"
        self.lt = 0
        self.ffy, self.bfy = 0, 0
        self:kick("hip", -0.4)
        self:emit("step")
      end
    end

  elseif L == "fleche" then
    local P = self.fphase
    if P == "ext" then
      local v = clamp(self.lt / (T.flecheExt / self.spd), 0, 1)
      self.lean = lerp(s.lean, 0.32, v)
      self.hy = lerp(s.hy, 0.76, v)
      if v >= 1 then
        self.fphase = "launch"
        self.lt = 0
        s.x, s.ffx, s.bfx, s.hy, s.lean = self.x, self.ffx, self.bfx, self.hy, self.lean
        s.ba1, s.ba2 = self.ba1, self.ba2
        self:emit("swish", 1)
      end
    elseif P == "launch" then
      local v = clamp(self.lt / (T.flecheLaunch / self.spd), 0, 1)
      self.x = s.x + face * 0.22 * v
      self.lean = lerp(s.lean, 0.55, v)
      self.hy = lerp(s.hy, 0.80, v)
      -- the back leg swings through
      self.bfx = lerp(s.bfx, s.x + face * 0.45, smooth(v))
      self.bfy = 0.14 * sin(pi * v)
      self.ba1 = lerp(s.ba1, BACK.fleche[1], v)
      self.ba2 = lerp(s.ba2, BACK.fleche[2], v)
      if v >= 1 then
        self.fphase = "run"
        self.lt = 0
        s.x = self.x
      end
    elseif P == "run" then
      local dur = T.flecheRun / self.spd
      local v = clamp(self.lt / dur, 0, 1)
      self.x = s.x + face * T.flecheDist * v
      -- two running strides; the feet swing alternately past the body
      local c = v * 2
      local function foot(ph)
        local a = 2 * pi * ph
        return -0.42 * cos(a), max(0, sin(a)) * 0.16
      end
      local fx, fy = foot(c + 0.5)
      local bx, by = foot(c)
      self.ffx, self.ffy = self.x + face * fx, fy
      self.bfx, self.bfy = self.x + face * bx, by
      self.hy = 0.80 + 0.03 * abs(sin(2 * pi * c))
      self.lean = 0.52
      if v >= 1 then
        self.fphase = "stop"
        self.lt = 0
        s.x, s.hy, s.lean = self.x, self.hy, self.lean
        self:emit("fleche_end")
      end
    elseif P == "stop" then
      local v = clamp(self.lt / (T.flecheStop / self.spd), 0, 1)
      self.x = s.x + face * 0.28 * easeOut(v)
      self.lean = lerp(s.lean, 0.06, v)
      self.hy = lerp(s.hy, GUARD_HY, v)
      self.ffx = approach(self.ffx, self.x + face * STANCE_F, 14, dt)
      self.bfx = approach(self.bfx, self.x + face * STANCE_B, 14, dt)
      self.ffy = approach(self.ffy, 0, 20, dt)
      self.bfy = approach(self.bfy, 0, 20, dt)
      approachBack(self, BACK.guard, 8, dt)
      if v >= 1 then
        self.legs = "guard"
        self.lt = 0
      end
    end

  elseif L == "walk" then
    local home = self.homeFace
    self.wt = self.wt + dt
    if self.wturn == "out" or self.wturn == "back" then
      -- turning round on the spot: the side view squashes through edge-on
      local u = clamp(self.wt / 0.26, 0, 1)
      local from = (self.wturn == "out") and home or -home
      self.vface = from * cos(pi * u)
      if u >= 0.5 then self.face = -from end
      self.hy = approach(self.hy, STAND_HY - 0.015, 10, dt)
      self.lean = approach(self.lean, 0, 10, dt)
      self.ffx = approach(self.ffx, self.x + 0.08 * self.face, 14, dt)
      self.bfx = approach(self.bfx, self.x - 0.08 * self.face, 14, dt)
      self.ffy = 0.03 * sin(pi * u)
      self.bfy = 0.03 * sin(pi * seg(u, 0.3, 1))
      self.walkSwing = approach(self.walkSwing, 0, 10, dt)
      if u >= 1 then
        self.vface = self.face
        self.wt = 0
        if self.wturn == "out" then
          self.wturn = "walking"
        else
          self.wturn = nil
          self.legs = (self.walkPose == "guard") and "guard" or "stand"
          self.lt = 0
        end
      end
    else
      -- the walk: heel to toe, hips rising and falling, arms swinging
      local d = self.walkX - self.x
      local spd = abs(d) > 2 and 2.0 or 1.5
      local stepx = clamp(d, -spd * dt, spd * dt)
      self.x = self.x + stepx
      self.walkPhase = self.walkPhase + abs(stepx) / 1.1
      local ph = 2 * pi * self.walkPhase
      local moving = abs(d) > 0.01
      local t = (d >= 0 and 1 or -1) * face        -- +1 walking forwards
      local amp = moving and 0.24 or 0
      local sa, sb = sin(ph), sin(ph + pi)
      self.ffx = approach(self.ffx, self.x + face * (0.06 + t * amp * sa), 30, dt)
      self.bfx = approach(self.bfx, self.x + face * (-0.06 + t * amp * sb), 30, dt)
      self.ffy = moving and max(0, cos(ph)) * 0.07 or approach(self.ffy, 0, 20, dt)
      self.bfy = moving and max(0, cos(ph + pi)) * 0.07 or approach(self.bfy, 0, 20, dt)
      self.ffp = moving and 0.35 * t * cos(ph) or approach(self.ffp, 0, 20, dt)
      self.bfp = moving and 0.35 * t * cos(ph + pi) or approach(self.bfp, 0, 20, dt)
      self.hy = approach(self.hy, STAND_HY - (moving and 0.035 * abs(sa) or 0), 18, dt)
      self.lean = approach(self.lean, moving and 0.05 * t or 0, 8, dt)
      self.walkSwing = moving and sa * t or approach(self.walkSwing, 0, 10, dt)
      self.vface = self.face
      if abs(d) < 0.005 then
        self.x = self.walkX
        if self.wturn == "walking" then
          self.wturn = "back"
          self.wt = 0
        else
          self.legs = (self.walkPose == "guard") and "guard" or "stand"
          self.lt = 0
        end
      end
    end

  elseif L == "engarde" then
    local u = clamp(self.lt / self.ld, 0, 1)
    local bu, fu = seg(u, 0, 0.7), seg(u, 0.25, 1)
    self.bfx = lerp(s.bfx, self.endB, smooth(bu))
    self.bfy = 0.05 * sin(pi * bu)
    self.bfp = -0.25 * sin(pi * bu)
    self.ffx = lerp(s.ffx, self.endF, smooth(fu))
    self.ffy = 0.03 * sin(pi * fu)
    self.hy = lerp(s.hy, GUARD_HY, smooth(u))
    self.lean = lerp(s.lean, 0.06, smooth(u))
    if u >= 1 then
      self.legs = "guard"
      self.arm = "guard"
      self.lt = 0
      self:kick("hip", -0.4)
    end

  elseif L == "stand" then
    self.ffp = approach(self.ffp, 0, 20, dt)
    self.bfp = approach(self.bfp, 0, 20, dt)
    self.walkSwing = approach(self.walkSwing, 0, 10, dt)
    self.hy = approach(self.hy, STAND_HY, 8, dt)
    self.lean = approach(self.lean, self.standLean or 0, 8, dt)
    self.ffx = approach(self.ffx, self.x + face * 0.12, 10, dt)
    self.bfx = approach(self.bfx, self.x - face * 0.12, 10, dt)
    self.ffy = approach(self.ffy, 0, 20, dt)
    self.bfy = approach(self.bfy, 0, 20, dt)
  end
end

-- Arm angles that point the blade at the opponent's target in the attack line.
function F:aimAngles()
  local j = self.j
  local shx, shy = j.shx, j.shy
  local tx, ty
  local o = self.opp
  if o then
    local oj = o.j
    local k = self.attackLine == "high" and 0.66 or 0.18
    local px = oj.hipx + (oj.neckx - oj.hipx) * k + 0.10
    local py = oj.hipy + (oj.necky - oj.hipy) * k
    tx = (o.x - self.x) * self.face + o.face * self.face * px
    ty = py
  else
    tx, ty = shx + 2.2, shy + (self.attackLine == "high" and -0.12 or -0.40)
  end
  local reach = UPPER + FORE
  local a = atan2(ty - shy, tx - shx)
  a = clamp(a, -0.60, 0.35)
  local wx, wy = shx + cos(a) * reach, shy + sin(a) * reach
  local b
  if tx - wx > 0.25 then
    b = atan2(ty - wy, tx - wx)
  else
    b = a
  end
  b = clamp(b, a - 0.40, a + 0.30)
  return a, a, b
end

function F:keepExtended()
  local L = self.legs
  if L == "lunge" then return self.lphase ~= "recover" end
  if L == "fleche" then return self.fphase ~= "stop" end
  return self.holdX
end

function F:updateArm(dt)
  local A = self.arm
  self.at = self.at + dt
  if A == "guard" then
    -- fencers keep the point alive: small circles around the guard
    local g = ARM.guard[self.line]
    local ph = self.time * 2.2 + self.side
    local play = (self.legs == "guard") and 1 or 0.4
    self.a1 = approach(self.a1, g[1] + 0.03 * play * sin(ph * 0.7), 24, dt)
    self.a2 = approach(self.a2, g[2] + 0.04 * play * sin(ph), 24, dt)
    self.bl = approach(self.bl, g[3] + 0.06 * play * sin(ph * 1.3 + 0.5), 24, dt)

  elseif A == "extend" then
    local a1, a2, bl = self:aimAngles()
    if self.aphase == "out" then
      local u = clamp(self.at / self.ad, 0, 1)
      -- the point leads: the blade lines up on the target before the arm
      -- is fully out, so the point travels straight at it
      local e = easeOut(u)
      local a0 = self.a0
      self.a1 = lerp(a0[1], a1, e)
      self.a2 = lerp(a0[2], a2, easeOut(min(1, u * 1.4)))
      self.bl = lerp(a0[3], bl, easeOut(min(1, u * 2.2)))
      if u >= 1 then
        self.aphase = "held"
        self.at = 0
        self:emit("extended")
      end
    elseif self.aphase == "held" then
      local r = self.switchT > 0 and 40 or 30
      self.a1 = approach(self.a1, a1, r, dt)
      self.a2 = approach(self.a2, a2, r, dt)
      self.bl = approach(self.bl, bl, r, dt)
      if not self:keepExtended() then
        self.aphase = "in"
        self.at = 0
        self.ad = T.withdraw / self.spd
        self.a0[1], self.a0[2], self.a0[3] = self.a1, self.a2, self.bl
        self:endOffense("withdrawn")
      end
    elseif self.aphase == "in" then
      local u = clamp(self.at / self.ad, 0, 1)
      local g = ARM.guard[self.line]
      local a0 = self.a0
      self.a1 = lerp(a0[1], g[1], smooth(u))
      self.a2 = lerp(a0[2], g[2], smooth(u))
      self.bl = lerp(a0[3], g[3], smooth(u))
      if u >= 1 then self.arm = "guard" end
    end
    if self.aphase == "out" and not self:keepExtended() and self.at >= self.ad then
      -- a tapped extension: out and straight back
      self.aphase = "held"
    end

  elseif A == "parry" then
    local P = self.pphase
    local p = ARM.parry[self.parryLine]
    if P == "snap" then
      local u = clamp(self.at / self.ad, 0, 1)
      local a0 = self.a0
      local e = easeOutBack(u)
      self.a1 = lerp(a0[1], p[1], e)
      self.a2 = lerp(a0[2], p[2], e)
      self.bl = lerp(a0[3], p[3], e)
      if u >= 1 then
        self.pphase = "active"
        self.at = 0
        self.ad = (T.parryActive + self.parryBonus) / self.spd
      end
    elseif P == "active" then
      self.a1, self.a2, self.bl = p[1], p[2], p[3]
      if self.at >= self.ad then
        self.pphase = "ret"
        self.at = 0
        self.ad = T.parryReturn / self.spd
      end
    elseif P == "ret" then
      local g = ARM.guard[self.line]
      local u = clamp(self.at / self.ad, 0, 1)
      self.a1 = lerp(p[1], g[1], smooth(u))
      self.a2 = lerp(p[2], g[2], smooth(u))
      self.bl = lerp(p[3], g[3], smooth(u))
      if u >= 1 then
        self.pphase = "cool"
        self.at = 0
        self.ad = (self.parryWon and 0 or T.parryCool) / self.spd
      end
    elseif P == "cool" then
      local g = ARM.guard[self.line]
      self.a1, self.a2, self.bl = g[1], g[2], g[3]
      if self.at >= self.ad then self.arm = "guard" end
    end

  elseif A == "deflect" or A == "beaten" then
    local d = self.defl
    self.a1 = approach(self.a1, d[1], 30, dt)
    self.a2 = approach(self.a2, d[2], 30, dt)
    self.bl = approach(self.bl, d[3], 30, dt)
    if self.at >= self.ad then
      if self:keepExtended() and self.legs ~= "walk" then
        -- remise: the point comes back into line (no new offensive action)
        self.arm = "guard"
        self:armExtend(T.ext * 1.2)
      else
        self.arm = "guard"
      end
    end

  elseif A == "pose" then
    local p, b = self.poseArm, self.poseBack
    self.a1 = approach(self.a1, p[1], 9, dt)
    self.a2 = approach(self.a2, p[2], 9, dt)
    self.bl = approach(self.bl, p[3], 9, dt)
    if b then approachBack(self, b, 9, dt) end
  end
end

---------------------------------------------------------------------------
-- Skeleton
---------------------------------------------------------------------------

-- Two-bone IK with the knee bending forward. Returns knee and ankle (the
-- ankle is pulled in if the foot is out of reach).
local function ik(hx, hy, fx, fy)
  local dx, dy = fx - hx, fy - hy
  local d = sqrt(dx * dx + dy * dy)
  local maxd = THIGH + SHIN - 1e-3
  if d > maxd then
    dx, dy = dx * maxd / d, dy * maxd / d
    d = maxd
  end
  if d < 1e-3 then d = 1e-3 end
  local a = atan2(dy, dx)
  local c = clamp((THIGH * THIGH + d * d - SHIN * SHIN) / (2 * THIGH * d), -1, 1)
  local b = acos(c)
  return hx + THIGH * cos(a + b), hy + THIGH * sin(a + b), hx + dx, hy + dy
end

function F:computeJoints()
  local j = self.j
  local face, x = self.face, self.x
  local sp = self.sp
  local hy, lean = self.hy + sp.hip[1], self.lean + sp.lean[1]
  local sl, cl = sin(lean), cos(lean)
  local nod = sp.head[1]
  j.lean = lean
  j.hipx, j.hipy = 0, hy
  j.neckx, j.necky = sl * TORSO, hy + cl * TORSO
  -- the shoulder comes forward as the arm extends
  j.shx, j.shy = sl * (TORSO - 0.06) + 0.03 + 0.04 * self.protract, hy + cl * (TORSO - 0.06)
  j.headx, j.heady = j.neckx + sl * 0.13 + 0.03 + 0.25 * nod, j.necky + cl * 0.13 - 0.10 * abs(nod)
  -- sword arm (the blade spring only moves a blade that cannot hit)
  local sw = self.walkSwing
  local a1 = self.a1 + ((self.legs == "walk") and 0.22 * sw or 0)
  local bl = self.bl + ((self.arm ~= "extend") and sp.blade[1] or 0)
  j.elx, j.ely = j.shx + cos(a1) * UPPER, j.shy + sin(a1) * UPPER
  j.hx, j.hy = j.elx + cos(self.a2) * FORE, j.ely + sin(self.a2) * FORE
  j.tipx, j.tipy = j.hx + cos(bl) * BLADE, j.hy + sin(bl) * BLADE
  -- other arm (from the far shoulder)
  local b1, b2 = sp.b1[1], sp.b2[1]
  j.bshx, j.bshy = j.shx - 0.08, j.shy - 0.01
  j.belx, j.bely = j.bshx + cos(b1) * UPPER, j.bshy + sin(b1) * UPPER
  j.bhx, j.bhy = j.belx + cos(b2) * (FORE - 0.02), j.bely + sin(b2) * (FORE - 0.02)
  -- legs
  local fl = (self.ffx - x) * face
  local bk = (self.bfx - x) * face
  j.fkx, j.fky, j.ffx, j.ffy = ik(0.03, hy, fl, ANKLE + self.ffy)
  j.bkx, j.bky, j.bfx, j.bfy = ik(-0.03, hy, bk, ANKLE + self.bfy)
end

---------------------------------------------------------------------------
-- Reach, measured once by running the actions on a lone fencer.
---------------------------------------------------------------------------

function F.measure()
  if F.REACH then return F.REACH end
  local R = { path = {} }
  -- run each action on a lone fencer and record how far the point gets,
  -- and when, so the AI can tell when an attack would arrive
  local function run(cmd, steps)
    local f = F.new({ face = 1, x = 0 })
    f.holdA, f.holdX = true, true
    f:run(cmd, "high")
    local best, path = -1, {}
    for k = 1, steps do
      f:update(1 / 120)
      local tx = f.j.tipx + f.x
      if tx > best then
        best = tx
        path[#path + 1] = { k / 120, tx }
      end
    end
    R.path[cmd] = path
    return best
  end
  R.ext = run("extend", 60)
  R.lunge = run("lunge", 90)
  R.fleche = run("fleche", 120)
  R.guardTip = F.new({ face = 1, x = 0 }).j.tipx
  F.REACH = R
  return R
end

-- Time (at speed 1) for the point of this action to get dist metres ahead
-- of the pelvis it started from; nil if it never does.
function F.timeTo(action, dist)
  local path = F.measure().path[action]
  if not path then return nil end
  for _, p in ipairs(path) do
    if p[2] >= dist then return p[1] end
  end
  return nil
end

return F
