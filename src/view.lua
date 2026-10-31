-- Drawing a bout: arena, piste, referee, fencers, blades, HUD and calls.
--
-- Fencers are rasterised every frame from their skeleton (src/fencer.lua):
-- each limb is a filled quad with a 1-pixel ink outline, drawn back to
-- front, so the pixel art always matches the geometry the rules use.

local core = require("src.core")
local gfx = require("src.gfx")
local art = require("src.art")
local settings = require("src.settings")
local Fencer = require("src.fencer")

local lg = love.graphics
local floor, max, min, abs, sin, cos, sqrt = math.floor, math.max, math.min, math.abs, math.sin, math.cos, math.sqrt
local C = core.C
local W, H, PPM, GROUND = core.W, core.H, core.PPM, core.GROUND

local V = {}

local FAR, NEAR = 119, 137          -- piste edges on screen
local TOPBAR, BOTBAR = 18, 148

local function screenX(b, wx) return W / 2 + (wx - b.cam) * PPM end
-- Piste markings converge slightly towards the far edge.
local function persp(b, wx, y)
  return W / 2 + (wx - b.cam) * PPM * (1 + (y - GROUND) / 18 * 0.10)
end

---------------------------------------------------------------------------
-- Primitive shapes with outlines
---------------------------------------------------------------------------

local function quad(x1, y1, x2, y2, h1, h2, ext)
  local dx, dy = x2 - x1, y2 - y1
  local L = sqrt(dx * dx + dy * dy)
  if L < 1e-3 then dx, dy, L = 0, -1, 1 end
  dx, dy = dx / L, dy / L
  local nx, ny = -dy, dx
  x1, y1 = x1 - dx * ext, y1 - dy * ext
  x2, y2 = x2 + dx * ext, y2 + dy * ext
  lg.polygon("fill", x1 + nx * h1, y1 + ny * h1, x2 + nx * h2, y2 + ny * h2,
    x2 - nx * h2, y2 - ny * h2, x1 - nx * h1, y1 - ny * h1)
end

-- A limb through joints p (x1,y1,x2,y2,x3,y3) with widths w (px).
local function limb(p, w, col)
  local n = #p / 2
  core.color(C.ink)
  for k = 1, n - 1 do
    quad(p[2 * k - 1], p[2 * k], p[2 * k + 1], p[2 * k + 2], w[k] / 2 + 1, w[k + 1] / 2 + 1, 1)
  end
  for k = 2, n - 1 do lg.circle("fill", p[2 * k - 1], p[2 * k], w[k] / 2 + 1, 8) end
  core.color(col)
  for k = 1, n - 1 do
    quad(p[2 * k - 1], p[2 * k], p[2 * k + 1], p[2 * k + 2], w[k] / 2, w[k + 1] / 2, 0)
  end
  for k = 2, n - 1 do lg.circle("fill", p[2 * k - 1], p[2 * k], w[k] / 2, 8) end
end

local function outlinedPoly(pts, col)
  core.color(C.ink)
  for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
    lg.push()
    lg.translate(o[1], o[2])
    lg.polygon("fill", pts)
    lg.pop()
  end
  core.color(col)
  lg.polygon("fill", pts)
end

---------------------------------------------------------------------------
-- Arena
---------------------------------------------------------------------------

local function drawStands(b)
  local cw = art.crowdW
  local off = -b.cam * PPM * 0.35
  local x0 = floor(W / 2 - cw / 2 + off)
  local frame = (b.cheer and b.cheer > 0 and floor(core.time * 7) % 2 == 0) and 2 or 1
  lg.setColor(1, 1, 1, 1)
  lg.draw(art.crowd[frame], x0, TOPBAR - 2)
  -- barrier boards
  local bw = art.boardsW
  local bx = floor(W / 2 - bw / 2 - b.cam * PPM * 0.75)
  lg.draw(art.boards, bx, 92)
  -- floor (dithered once, at start-up)
  lg.setColor(1, 1, 1, 1)
  lg.draw(art.floor, 0, 104)
end

local function pistePoly(b, x1, x2, col)
  core.color(col)
  lg.polygon("fill",
    persp(b, x1, FAR), FAR, persp(b, x2, FAR), FAR,
    persp(b, x2, NEAR + 1), NEAR + 1, persp(b, x1, NEAR + 1), NEAR + 1)
end

local function pisteLine(b, wx, col)
  core.color(col)
  gfx.line(persp(b, wx, FAR), FAR, persp(b, wx, NEAR), NEAR)
end

local function drawPiste(b)
  local E, R, Wz = core.END, core.RUNOFF, core.WARN
  -- shadow under the piste
  core.color(C.ink)
  lg.polygon("fill", persp(b, -R, NEAR + 1), NEAR + 1, persp(b, R, NEAR + 1), NEAR + 1,
    persp(b, R, NEAR + 3), NEAR + 3, persp(b, -R, NEAR + 3), NEAR + 3)
  pistePoly(b, -R, -E, C.runoff)
  pistePoly(b, E, R, C.runoff)
  pistePoly(b, -E, -Wz, C.warn)
  pistePoly(b, Wz, E, C.warn)
  pistePoly(b, -Wz, Wz, C.piste)
  -- metal texture: lighter stripes along the piste
  core.color(C.pisteL, 0.35)
  for _, y in ipairs({ FAR + 2, FAR + 7, FAR + 12 }) do
    gfx.line(persp(b, -R, y), y, persp(b, R, y), y)
  end
  core.color(C.pisteD)
  gfx.line(persp(b, -R, NEAR), NEAR, persp(b, R, NEAR), NEAR)
  core.color(C.pisteL)
  gfx.line(persp(b, -R, FAR), FAR, persp(b, R, FAR), FAR)
  -- markings: centre, en-garde, warning, end lines
  pisteLine(b, 0, C.line)
  pisteLine(b, -core.ENGARDE, C.line)
  pisteLine(b, core.ENGARDE, C.line)
  pisteLine(b, -Wz, C.warnL)
  pisteLine(b, Wz, C.warnL)
  pisteLine(b, -E, C.line)
  pisteLine(b, E, C.line)
  -- the centre line is drawn wider
  pisteLine(b, 0.034, C.line)
end

local function lampColor(b, side)
  local L = b.lights[side]
  if L == "valid" then return core.SIDE[side].col end
  if L == "off" then return C.lampW end
  return nil
end

local function drawReels(b)
  for side = 1, 2 do
    local wx = (side == 1 and -1 or 1) * (core.RUNOFF + 0.4)
    local x = floor(persp(b, wx, FAR - 2))
    if x > -12 and x < W + 12 then
      local y = FAR - 2
      core.color(C.ink)
      gfx.rect(x - 4, y - 8, 9, 9)
      core.color(C.suit)
      gfx.rect(x - 3, y - 7, 7, 7)
      core.color(C.dim)
      gfx.rect(x - 2, y - 5, 5, 3)
      core.color(C.ink)
      gfx.rect(x - 1, y - 4, 3, 1)
      -- lamp
      local lc = lampColor(b, side)
      core.color(C.ink)
      gfx.rect(x - 3, y - 12, 7, 4)
      core.color(lc or C.lampOff)
      gfx.rect(x - 2, y - 11, 5, 2)
      if lc then
        core.color(lc, 0.25)
        lg.circle("fill", x + 0.5, y - 10, 9, 16)
      end
    end
  end
end

-- The body cord runs from the fencer's back, sags to the floor and goes
-- off to the reel at the end of the piste.
local function drawCord(b, f)
  local j = f.j
  local face = f.face
  local bx = screenX(b, f.x) + face * (-0.13) * PPM
  local by = GROUND - (j.hipy + 0.20) * PPM
  local fx = screenX(b, f.x - face * 0.75)
  local fy = GROUND + 3
  local rx = screenX(b, -face * (core.RUNOFF + 0.2))
  core.color(C.ink)
  local px, py = bx, by
  for k = 1, 6 do
    local t = k / 6
    local x = (1 - t) * (1 - t) * bx + 2 * (1 - t) * t * (bx - face * 3) + t * t * fx
    local y = (1 - t) * (1 - t) * by + 2 * (1 - t) * t * (fy + 3) + t * t * fy
    gfx.line(px, py, x, y)
    px, py = x, y
  end
  gfx.line(fx, fy, rx, fy)
  gfx.line(rx, fy, rx, FAR - 4)
end

---------------------------------------------------------------------------
-- Referee (behind the piste, facing us)
---------------------------------------------------------------------------

local function box(x, y, w, h, col)
  core.color(C.ink)
  gfx.rect(x - 1, y - 1, w + 2, h + 2)
  core.color(col)
  gfx.rect(x, y, w, h)
end

local function arm(x, y, ang, len)
  local ex, ey = x + cos(ang) * len, y + sin(ang) * len
  core.color(C.ink)
  for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { 1, 1 }, { -1, 1 } }) do
    gfx.line(x + o[1], y + o[2], ex + o[1], ey + o[2])
  end
  core.color(C.suit)
  gfx.line(x, y, ex, ey)
  gfx.line(x + 1, y, ex + 1, ey)
  core.color(C.refSkin)
  gfx.rect(ex, ey, 2, 2)
end

local function refPose(b)
  local p = b.phase
  local up, dl, dr = -math.pi / 2, math.pi * 0.62, math.pi * 0.38
  if p == "halt" then return dl, up end
  if p == "decision" and b.decision then
    local s = b.decision.scorer
    if s == 1 then return -math.pi * 0.80, dr end
    if s == 2 then return dl, -math.pi * 0.20 end
    return math.pi * 0.20, math.pi * 0.80  -- crossed: no touch
  end
  if p == "over" and b.winner then
    return b.winner == 1 and -math.pi * 0.80 or dl, b.winner == 2 and -math.pi * 0.20 or dr
  end
  if p == "engarde" then return math.pi * 0.85, math.pi * 0.15 end
  return dl, dr
end

local function drawReferee(b)
  local x = floor(W / 2 + ((b.refX or 0) - b.cam) * PPM * 0.9)
  if x < -20 or x > W + 20 then return end
  local feet = FAR - 6
  -- legs and shoes
  box(x - 4, feet - 14, 3, 14, C.suit)
  box(x + 1, feet - 14, 3, 14, C.suit)
  core.color(C.ink)
  gfx.rect(x - 5, feet, 4, 1)
  gfx.rect(x + 1, feet, 4, 1)
  -- jacket
  box(x - 5, feet - 28, 10, 15, C.suit)
  core.color(C.suitL)
  gfx.rect(x - 5, feet - 28, 1, 15)
  core.color(C.shirt)
  gfx.rect(x - 1, feet - 28, 2, 4)
  core.color(C.tie)
  gfx.rect(x - 1, feet - 27, 2, 5)
  -- head
  box(x - 3, feet - 36, 6, 7, C.refSkin)
  core.color(C.refHair)
  gfx.rect(x - 3, feet - 36, 6, 2)
  gfx.rect(x - 3, feet - 34, 1, 1)
  gfx.rect(x + 2, feet - 34, 1, 1)
  core.color(C.ink)
  gfx.rect(x - 2, feet - 32, 1, 1)
  gfx.rect(x + 1, feet - 32, 1, 1)
  -- arms
  local la, ra = refPose(b)
  arm(x - 5, feet - 27, la, 11)
  arm(x + 4, feet - 27, ra, 11)
end

---------------------------------------------------------------------------
-- Fencers
---------------------------------------------------------------------------

local function shoe(fx, fy, face, len, col)
  -- fx, fy: floor point under the ankle
  local x1 = fx - face * 2
  local x2 = fx + face * len
  local lo, hi = min(x1, x2), max(x1, x2)
  core.color(C.ink)
  gfx.rect(lo - 1, fy - 3, hi - lo + 3, 4)
  core.color(col)
  gfx.rect(lo, fy - 2, hi - lo + 1, 2)
end

function V.fencer(b, f)
  local j = f.j
  local face = f.face
  local ox = screenX(b, f.x)
  local function P(lx, ly) return ox + face * lx * PPM, GROUND - ly * PPM end
  local side = core.SIDE[f.side]

  -- far arm
  local a1x, a1y = P(j.bshx, j.bshy)
  local a2x, a2y = P(j.belx, j.bely)
  local a3x, a3y = P(j.bhx, j.bhy)
  limb({ a1x, a1y, a2x, a2y, a3x, a3y }, { 3.4, 3, 2.4 }, C.whiteS)

  -- back leg
  local hx, hy = P(-0.03, j.hipy)
  local kx, ky = P(j.bkx, j.bky)
  local fx, fy = P(j.bfx, j.bfy)
  limb({ hx, hy, kx, ky, fx, fy }, { 5.4, 4, 3 }, C.whiteS)
  local gx, gy = P(j.bfx, j.bfy - Fencer.ANKLE)
  shoe(gx, gy + 1, face, f.legs == "fleche" and 5 or 3, C.shoe)

  -- hips
  local px, py = P(0, j.hipy)
  core.color(C.ink)
  lg.circle("fill", px, py, 4.2, 10)
  core.color(C.white)
  lg.circle("fill", px, py, 3.2, 10)

  -- trunk: jacket, then the lamé (the valid target)
  local sl, cl = sin(f.lean), cos(f.lean)
  local T = Fencer.TORSO
  local function TP(s, t)
    return P(j.hipx + sl * s * T + cl * t, j.hipy + cl * s * T - sl * t)
  end
  local pts = {}
  for _, st in ipairs({ { -0.08, -0.13 }, { -0.08, 0.13 }, { 0.55, 0.17 }, { 0.98, 0.09 }, { 1.0, -0.09 }, { 0.5, -0.15 } }) do
    local x, y = TP(st[1], st[2])
    pts[#pts + 1], pts[#pts + 2] = x, y
  end
  outlinedPoly(pts, C.white)
  local lp = {}
  for _, st in ipairs({ { -0.05, -0.11 }, { -0.05, 0.12 }, { 0.55, 0.15 }, { 0.86, 0.10 }, { 0.86, -0.10 }, { 0.5, -0.13 } }) do
    local x, y = TP(st[1], st[2])
    lp[#lp + 1], lp[#lp + 2] = x, y
  end
  core.color(C.lame)
  lg.polygon("fill", lp)
  core.color(C.lameL)
  local l1x, l1y = TP(0.12, 0.10)
  local l2x, l2y = TP(0.70, 0.11)
  gfx.line(l1x, l1y, l2x, l2y)
  core.color(C.lameD)
  local d1x, d1y = TP(0.05, -0.09)
  local d2x, d2y = TP(0.75, -0.10)
  gfx.line(d1x, d1y, d2x, d2y)
  -- side colour on the back of the collar
  core.color(side.col)
  local cx, cy = TP(0.93, -0.06)
  gfx.rect(cx - 1, cy, 2, 1)

  -- front leg
  hx, hy = P(0.03, j.hipy)
  kx, ky = P(j.fkx, j.fky)
  fx, fy = P(j.ffx, j.ffy)
  limb({ hx, hy, kx, ky, fx, fy }, { 5.6, 4.2, 3.2 }, C.white)
  gx, gy = P(j.ffx, j.ffy - Fencer.ANKLE)
  shoe(gx, gy + 1, face, 5, C.shoe)

  -- mask
  local mx, my = P(j.headx, j.heady)
  lg.setColor(1, 1, 1, 1)
  lg.draw(art.mask, floor(mx + 0.5), floor(my + 0.5), 0, face, 1, 4, 5)

  -- sword arm
  local s1x, s1y = P(j.shx, j.shy)
  local s2x, s2y = P(j.elx, j.ely)
  local s3x, s3y = P(j.hx, j.hy)
  limb({ s1x, s1y, s2x, s2y, s3x, s3y }, { 3.6, 3.2, 2.8 }, C.white)
  -- glove in the side colour
  core.color(C.ink)
  gfx.rect(s3x - 2, s3y - 2, 4, 4)
  core.color(side.col)
  gfx.rect(s3x - 1, s3y - 1, 2, 2)
end

function V.blade(b, f)
  local j = f.j
  local face = f.face
  local ox = screenX(b, f.x)
  local hx, hy = ox + face * j.hx * PPM, GROUND - j.hy * PPM
  local dx, dy = cos(f.bl) * face, -sin(f.bl)
  local L = Fencer.BLADE * PPM
  local tx, ty
  local path = {}
  if f.hit and f.opp then
    -- the blade bends against the target
    local o = f.opp
    tx = screenX(b, o.x + o.face * f.hit.lx)
    ty = GROUND - f.hit.ly * PPM
    local qx, qy = hx + dx * L * 0.55, hy + dy * L * 0.55
    for k = 0, 8 do
      local t = k / 8
      path[#path + 1] = { (1 - t) * (1 - t) * hx + 2 * (1 - t) * t * qx + t * t * tx,
        (1 - t) * (1 - t) * hy + 2 * (1 - t) * t * qy + t * t * ty }
    end
  else
    tx, ty = hx + dx * L, hy + dy * L
    path[1], path[2] = { hx, hy }, { tx, ty }
  end
  -- shadow, then steel
  core.color(C.ink, 0.8)
  for k = 1, #path - 1 do gfx.line(path[k][1], path[k][2] + 1, path[k + 1][1], path[k + 1][2] + 1) end
  core.color(C.blade)
  for k = 1, #path - 1 do gfx.line(path[k][1], path[k][2], path[k + 1][1], path[k + 1][2]) end
  core.color(C.bladeD)
  gfx.px(tx, ty)
  -- bell guard, across the blade
  local nx, ny = -dy, dx
  core.color(C.ink)
  gfx.line(hx + dx * 1.5 - nx * 2.5, hy + dy * 1.5 - ny * 2.5 + 1, hx + dx * 1.5 + nx * 2.5, hy + dy * 1.5 + ny * 2.5 + 1)
  core.color(C.guard)
  gfx.line(hx + dx * 1.5 - nx * 2.5, hy + dy * 1.5 - ny * 2.5, hx + dx * 1.5 + nx * 2.5, hy + dy * 1.5 + ny * 2.5)
end

---------------------------------------------------------------------------
-- Assists: priority marker, attack line, distance
---------------------------------------------------------------------------

local KIND_TAG = {
  attack = "ATTACK", parry = "RIPOSTE", riposte = "RIPOSTE", ["counter-riposte"] = "RIPOSTE",
  beat = "BEAT", ["beat-attack"] = "ATTACK", line = "LINE",
}

local function drawAssists(b)
  if not settings.data.assist or b.o.noAssist then return end
  if not b:live() then return end
  local row = b.row
  if row.holder then
    local f = b.f[row.holder]
    local x = floor(screenX(b, f.x + f.face * f.j.headx))
    local y = floor(GROUND - (f.j.heady + 0.22) * PPM) - 9 + floor(sin(core.time * 8) + 0.5)
    gfx.text("▼", x, y, C.yellow, "center", true)
  end
  -- the line of an incoming attack, next to the human fencer
  for i = 1, 2 do
    local me, op = b.f[i], b.f[3 - i]
    if me.human and op.offense then
      local up = op.attackLine == "high"
      local x = floor(screenX(b, me.x + me.face * 0.75))
      local y = floor(GROUND - (up and 1.30 or 0.78) * PPM)
      gfx.text(up and "▲" or "▼", x, y, C.orange, "center", true)
    end
  end
end

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------

local function lamp(x, y, w, h, col, lit)
  core.color(C.ink)
  gfx.rect(x - 1, y - 1, w + 2, h + 2)
  if lit then
    core.color(col)
    gfx.rect(x, y, w, h)
    core.color(C.lampW, 0.6)
    gfx.rect(x + 1, y, w - 2, 1)
  else
    core.color(col, 0.22)
    gfx.rect(x, y, w, h)
  end
end

function V.topBar(b)
  core.color(C.ink)
  gfx.rect(0, 0, W, TOPBAR)
  core.color(C.panelL)
  gfx.rect(0, TOPBAR - 1, W, 1)
  local L = b.lights
  lamp(3, 3, 30, 4, C.red, L[1] == "valid")
  lamp(36, 3, 7, 4, C.lampW, L[1] == "off")
  lamp(W - 43, 3, 7, 4, C.lampW, L[2] == "off")
  lamp(W - 33, 3, 30, 4, C.green, L[2] == "valid")
  -- names
  local f1, f2 = b.f[1], b.f[2]
  local n1 = f1.name .. (f1.nation and (" " .. f1.nation) or "")
  local n2 = (f2.nation and (f2.nation .. " ") or "") .. f2.name
  local room = W / 2 - 42
  gfx.text(f1.name, 3, 10, C.redL)
  if f1.nation and gfx.textWidth(n1) <= room then gfx.text(f1.nation, 3 + gfx.textWidth(f1.name) + 6, 10, C.dim) end
  gfx.text(f2.name, W - 3, 10, C.greenL, "right")
  if f2.nation and gfx.textWidth(n2) <= room then gfx.text(f2.nation, W - 3 - gfx.textWidth(f2.name) - 6, 10, C.dim, "right") end
  -- score
  if not b.o.drill then
    local s1, s2 = tostring(b.score[1]), tostring(b.score[2])
    gfx.text(s1, W / 2 - 17, 2, C.text, "right", false, 2)
    gfx.text(s2, W / 2 + 18, 2, C.text, "left", false, 2)
  end
  -- clock
  if not b.o.noClock then
    local running = b.phase == "fence"
    local col = running and C.yellow or C.text
    if b.priorityMinute then col = C.orange end
    gfx.text(core.fmtClock(b.phase == "break" and b.breakClock or b.clock), W / 2 + 1, 3, col, "center")
    -- period dots
    local np = b.periods
    for k = 1, np do
      core.color(k <= b.period and C.text or C.dark)
      gfx.rect(W / 2 - (np * 4) / 2 + (k - 1) * 4 + 1, 12, 2, 2)
    end
  else
    gfx.text("·", W / 2 + 1, 3, C.dim, "center")
  end
  if b.priorityMinute then
    local px = b.priorityHolder == 1 and (3 + gfx.textWidth(n1) + 6) or (W - 3 - gfx.textWidth(n2) - 12)
    gfx.text("P", px, 10, C.orange)
  end
end

function V.bottomBar(b)
  core.color(C.ink)
  gfx.rect(0, BOTBAR, W, H - BOTBAR)
  core.color(C.panelL)
  gfx.rect(0, BOTBAR, W, 1)
  -- whole piste: 18 m over 144 px (8 px/m)
  local x0, k = W / 2, 8
  local y = BOTBAR + 5
  local function X(wx) return floor(x0 + wx * k) end
  core.color(C.runoff)
  gfx.rect(X(-core.RUNOFF), y, X(core.RUNOFF) - X(-core.RUNOFF), 3)
  core.color(C.piste)
  gfx.rect(X(-core.WARN), y, X(core.WARN) - X(-core.WARN), 3)
  core.color(C.warn)
  gfx.rect(X(-core.END), y, X(-core.WARN) - X(-core.END), 3)
  gfx.rect(X(core.WARN), y, X(core.END) - X(core.WARN), 3)
  core.color(C.line)
  for _, wx in ipairs({ -core.END, -core.ENGARDE, 0, core.ENGARDE, core.END }) do
    gfx.rect(X(wx), y - (wx == 0 and 1 or 0), 1, wx == 0 and 5 or 3)
  end
  for i = 1, 2 do
    local f = b.f[i]
    local x = X(f.x)
    core.color(C.ink)
    gfx.rect(x - 2, y - 3, 5, 9)
    core.color(core.SIDE[i].col)
    gfx.rect(x - 1, y - 2, 3, 7)
  end
  -- distance between the fencers
  local gap = b.f[2].x - b.f[1].x
  local R = Fencer.measure()
  local col = C.dim
  if settings.data.assist and not b.o.noAssist then
    if gap <= R.lunge + 0.14 then col = C.orange
    elseif gap <= R.lunge + 0.14 + Fencer.T.stepDist then col = C.yellow end
  end
  gfx.text(string.format("%.1f M", gap), 3, BOTBAR + 3, col)
  -- priority
  local row = b.row
  if settings.data.assist and not b.o.noAssist and b:live() and row.holder then
    local tag = KIND_TAG[row.kind] or "PRIORITY"
    gfx.text(tag, W - 3, BOTBAR + 3, core.SIDE[row.holder].light, "right")
  elseif b.o.bottomRight then
    gfx.text(b.o.bottomRight, W - 3, BOTBAR + 3, C.dim, "right")
  end
end

local function drawCalls(b)
  local c = b.call
  if c then
    local pop = 1
    if c.big then
      gfx.text(c.text, W / 2, 34, C.text, "center", true, 2)
    else
      gfx.text(c.text, W / 2, 38, C.text, "center", true)
    end
  end
  if b.phase == "priority" then
    local who = b.f[b.priorityHolder]
    gfx.text("PRIORITY MINUTE", W / 2, 32, C.orange, "center", true, 2)
    gfx.text("PRIORITY: " .. who.name .. " (" .. b:side(b.priorityHolder) .. ")", W / 2, 54, C.text, "center", true)
    gfx.text("FIRST TOUCH WINS. NO TOUCH: PRIORITY WINS", W / 2, 66, C.dim, "center", true)
  end
  if b.phase == "break" then
    gfx.text("ONE MINUTE BREAK", W / 2, 54, C.dim, "center", true)
  end
  local d = b.decision
  if b.phase == "decision" and d then
    local w = 220
    local x = (W - w) / 2
    local hgt = d.line3 and 46 or 36
    if d.drillMsg then hgt = hgt + 11 end
    gfx.panel(x, 24, w, hgt)
    gfx.text(d.line1, W / 2, 28, C.text, "center")
    local col = d.scorer and core.SIDE[d.scorer].light or C.dim
    gfx.text(d.line2, W / 2, 39, col, "center", false, 2)
    local y = 57
    if d.line3 then
      gfx.text(d.line3, W / 2, y, C.dim, "center")
      y = y + 11
    end
    if d.drillMsg then
      gfx.text(d.drillMsg, W / 2, y, d.drillOk and C.greenL or C.orange, "center")
    end
  end
end

---------------------------------------------------------------------------

function V.draw(b)
  local sh = 0
  if b.shake and b.shake > 0 then sh = (floor(core.time * 60) % 2 == 0) and 1 or -1 end
  lg.push()
  lg.translate(0, sh)
  drawStands(b)
  drawReferee(b)
  drawPiste(b)
  drawReels(b)
  -- light pool from the lamps that are lit
  if b.flash then
    local col = b.flash.region == "valid" and core.SIDE[b.flash.side].col or C.lampW
    core.color(col, 0.10)
    gfx.rect(0, TOPBAR, W, BOTBAR - TOPBAR)
  end
  for i = 1, 2 do drawCord(b, b.f[i]) end
  -- the fencer further forward in an exchange is drawn last
  local order = { 1, 2 }
  if b.f[1].legs == "lunge" or b.f[1].legs == "fleche" then order = { 2, 1 } end
  for _, i in ipairs(order) do V.fencer(b, b.f[i]) end
  for _, i in ipairs(order) do V.blade(b, b.f[i]) end
  for _, p in ipairs(b.fx) do
    core.color(p.col)
    gfx.px(screenX(b, p.x), GROUND - p.y * PPM)
  end
  if b.o.drill and b.o.drill.drawWorld then b.o.drill:drawWorld(b, screenX) end
  if not b.o.noHud then drawAssists(b) end
  lg.pop()
  if b.o.noHud then return end
  V.topBar(b)
  V.bottomBar(b)
  drawCalls(b)
  if b.o.drill and b.o.drill.drawHud then b.o.drill:drawHud(b) end
end

V.screenX = screenX
return V
