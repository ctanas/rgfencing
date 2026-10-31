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
local Nations = require("src.nations")
local Bout = require("src.bout")

local lg = love.graphics
local floor, max, min, abs, sin, cos, sqrt = math.floor, math.max, math.min, math.abs, math.sin, math.cos, math.sqrt
local C = core.C
-- layout (design) units, for the HUD and overlays
local W, H, PPM, GROUND = core.W, core.H, core.PPM, core.GROUND

local V = {}

local FAR, NEAR = 119, 137          -- piste edges (design units)
local TOPBAR, BOTBAR = 18, 148

-- The arena and fencers are drawn in canvas pixels, at the current scale.
-- These are refreshed at the start of every draw (V.draw).
local S, CW, PPMc, GROUNDc, FARc, NEARc, ow = 1, 240, 30, 128, 119, 137, 1
local function refresh()
  S, CW = core.S, core.CW
  PPMc, GROUNDc = PPM * S, GROUND * S
  FARc, NEARc = FAR * S, NEAR * S
  ow = gfx.ow
end
local function R(v) return max(1, floor(v * S + 0.5)) end

-- The camera moves in whole canvas pixels, so the scene doesn't shimmer.
local function camPx(b) return floor(b.cam * PPMc + 0.5) end
local function screenX(b, wx) return CW / 2 + wx * PPMc - camPx(b) end
-- The same in design units, for overlays drawn with the gfx helpers.
local function dX(b, wx) return screenX(b, wx) / S end
-- Piste markings converge slightly towards the far edge.
local function persp(b, wx, y)
  return CW / 2 + (wx * PPMc - camPx(b)) * (1 + (y - GROUNDc) / (18 * S) * 0.10)
end

---------------------------------------------------------------------------
-- Primitive shapes with outlines (canvas pixels)
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

-- A limb through joints p (x1,y1,x2,y2,x3,y3) with widths w (design px,
-- scaled here). pass: "ink" (outline only), "fill" (colour only) or nil
-- (both). Drawing the outlines of several parts before any of their fills
-- joins them into one silhouette, with no seam where they meet.
local function limb(p, w, col, pass)
  local n = #p / 2
  if pass ~= "fill" then
    core.color(C.ink)
    for k = 1, n - 1 do
      quad(p[2 * k - 1], p[2 * k], p[2 * k + 1], p[2 * k + 2], w[k] * S / 2 + ow, w[k + 1] * S / 2 + ow, ow)
    end
    for k = 2, n - 1 do lg.circle("fill", p[2 * k - 1], p[2 * k], w[k] * S / 2 + ow, 12) end
  end
  if pass ~= "ink" then
    core.color(col)
    for k = 1, n - 1 do
      quad(p[2 * k - 1], p[2 * k], p[2 * k + 1], p[2 * k + 2], w[k] * S / 2, w[k + 1] * S / 2, 0)
    end
    for k = 2, n - 1 do lg.circle("fill", p[2 * k - 1], p[2 * k], w[k] * S / 2, 12) end
  end
end

local function outlinedPoly(pts, col, pass)
  if pass ~= "fill" then
    core.color(C.ink)
    for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
      lg.push()
      lg.translate(o[1] * ow, o[2] * ow)
      lg.polygon("fill", pts)
      lg.pop()
    end
  end
  if pass ~= "ink" then
    core.color(col)
    lg.polygon("fill", pts)
  end
end

-- Body shapes in the trunk's frame: s along the trunk (in trunk lengths,
-- 0 = hip joint), t across it (metres, + = forward).
local PELVIS = { { 0.20, 0.12 }, { 0.02, 0.135 }, { -0.10, 0.09 }, { -0.15, -0.02 },
  { -0.10, -0.14 }, { 0.05, -0.17 }, { 0.20, -0.15 } }
local JACKET = { { 0.02, -0.15 }, { -0.03, 0.13 }, { 0.55, 0.17 }, { 0.98, 0.09 }, { 1.0, -0.09 }, { 0.5, -0.15 } }
local LAME = { { 0.04, -0.13 }, { 0.0, 0.12 }, { 0.55, 0.15 }, { 0.86, 0.10 }, { 0.86, -0.10 }, { 0.5, -0.13 } }

---------------------------------------------------------------------------
-- Arena
---------------------------------------------------------------------------

local function drawStands(b)
  local K = art.K
  local frame = (b.cheer and b.cheer > 0 and floor(core.time * 7) % 2 == 0) and 2 or 1
  local img = art.crowd[frame]
  local cw = img:getWidth() * K
  lg.setColor(1, 1, 1, 1)
  lg.draw(img, floor(CW / 2 - cw / 2 - b.cam * PPMc * 0.35), floor((TOPBAR - 2) * S), 0, K, K)
  -- barrier boards
  local bw = art.boards:getWidth() * K
  lg.draw(art.boards, floor(CW / 2 - bw / 2 - b.cam * PPMc * 0.75), floor(92 * S), 0, K, K)
  -- floor (dithered once, at start-up)
  lg.draw(art.floor, 0, floor(104 * S), 0, K, K)
end

local function pistePoly(b, x1, x2, col)
  core.color(col)
  local y2 = NEARc + ow
  lg.polygon("fill",
    persp(b, x1, FARc), FARc, persp(b, x2, FARc), FARc,
    persp(b, x2, y2), y2, persp(b, x1, y2), y2)
end

local function pisteLine(b, wx, col, th)
  core.color(col)
  gfx.cline(persp(b, wx, FARc), FARc, persp(b, wx, NEARc), NEARc, th or ow)
end

local function drawPiste(b)
  local E, Rn, Wz = core.END, core.RUNOFF, core.WARN
  -- shadow under the piste
  core.color(C.ink)
  local a, z = NEARc + ow, NEARc + 3 * S
  lg.polygon("fill", persp(b, -Rn, a), a, persp(b, Rn, a), a, persp(b, Rn, z), z, persp(b, -Rn, z), z)
  pistePoly(b, -Rn, -E, C.runoff)
  pistePoly(b, E, Rn, C.runoff)
  pistePoly(b, -E, -Wz, C.warn)
  pistePoly(b, Wz, E, C.warn)
  pistePoly(b, -Wz, Wz, C.piste)
  -- metal texture: lighter stripes along the piste
  core.color(C.pisteL, 0.35)
  for _, yd in ipairs({ FAR + 2, FAR + 7, FAR + 12 }) do
    local y = yd * S
    gfx.cline(persp(b, -Rn, y), y, persp(b, Rn, y), y, ow)
  end
  core.color(C.pisteD)
  gfx.cline(persp(b, -Rn, NEARc), NEARc, persp(b, Rn, NEARc), NEARc, ow)
  core.color(C.pisteL)
  gfx.cline(persp(b, -Rn, FARc), FARc, persp(b, Rn, FARc), FARc, ow)
  -- markings: centre (wider), en-garde, warning, end lines
  pisteLine(b, 0, C.line, 2 * ow)
  pisteLine(b, -core.ENGARDE, C.line)
  pisteLine(b, core.ENGARDE, C.line)
  pisteLine(b, -Wz, C.warnL)
  pisteLine(b, Wz, C.warnL)
  pisteLine(b, -E, C.line)
  pisteLine(b, E, C.line)
end

local function lampColor(b, side)
  local L = b.lights[side]
  if L == "valid" then return core.SIDE[side].col end
  if L == "off" then return C.lampW end
  return nil
end

local function crect(x, y, w, h)
  lg.rectangle("fill", floor(x), floor(y), w, h)
end

local function drawReels(b)
  for side = 1, 2 do
    local wx = (side == 1 and -1 or 1) * (core.RUNOFF + 0.4)
    local y = floor((FAR - 2) * S)
    local x = floor(persp(b, wx, y))
    if x > -R(12) and x < CW + R(12) then
      core.color(C.ink)
      crect(x - R(4), y - R(8), R(9), R(9))
      core.color(C.suit)
      crect(x - R(3), y - R(7), R(7), R(7))
      core.color(C.dim)
      crect(x - R(2), y - R(5), R(5), R(3))
      core.color(C.ink)
      crect(x - R(1), y - R(4), R(3), ow)
      -- lamp
      local lc = lampColor(b, side)
      core.color(C.ink)
      crect(x - R(3), y - R(12), R(7), R(4))
      core.color(lc or C.lampOff)
      crect(x - R(2), y - R(11), R(5), R(2))
      if lc then
        core.color(lc, 0.25)
        lg.circle("fill", x + 0.5 * S, y - R(10), 9 * S, 24)
      end
    end
  end
end

-- The body wire runs from a clip on the back of the jacket to the reel at
-- the end of the piste. The reel's spring keeps it under tension, so it
-- hangs in a shallow curve; its extra slack (b.cordSag, a spring driven by
-- how fast the fencer moves towards or away from the reel) adds a little
-- give when retreating and a wobble after sudden moves.
local function drawCord(b, f, i)
  local j = f.j
  local home = f.homeFace
  local ox = floor(screenX(b, f.x) + 0.5)
  -- the clip, on the side of the body facing the reel
  local ax = ox - home * (0.13 + 0.12 * math.sin(j.lean)) * PPMc
  local ay = GROUNDc - (j.hipy + 0.18) * PPMc
  -- the reel's exit
  local ry = (FAR - 7) * S
  local rx = persp(b, -home * (core.RUNOFF + 0.4), (FAR - 2) * S)
  local span = abs(rx - ax)
  local slack = (b.cordSag and b.cordSag[i] and b.cordSag[i][1] or 0) * S
  local sag = max(S, 2 * S + span * 0.03 + slack)
  local floorY = GROUNDc + 3 * S
  local n = max(6, min(32, floor(span / (8 * S))))
  -- a parabola is a good enough catenary for a cable this tight; where
  -- the slack would take it below the floor, it rests on the floor
  local pts = { ax, ay }
  for k = 1, n do
    local t = k / n
    pts[#pts + 1] = ax + (rx - ax) * t
    pts[#pts + 1] = min(ay + (ry - ay) * t + sag * 4 * t * (1 - t), floorY)
  end
  -- grey rubber with a dark underside, so it reads on any background
  for pass = 1, 2 do
    core.color(pass == 1 and C.ink or C.cable)
    local dy = (pass == 1) and ow or 0
    for k = 1, #pts - 2, 2 do
      gfx.cline(pts[k], pts[k + 1] + dy, pts[k + 2], pts[k + 3] + dy, ow)
    end
  end
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

-- A shoe around the ankle (ax, ay), pitched toe-up (+) or heel-up (-).
-- Sizes in design pixels, scaled here.
local function shoe(ax, ay, face, len, pitch, col)
  local c, s = cos(pitch), sin(pitch)
  local pts = {}
  for _, p in ipairs({ { -2.2, -1.8 }, { len, -1.8 }, { len - 1.5, 0.4 }, { -2.2, 0.8 } }) do
    local x, y = p[1] * S, p[2] * S
    x, y = x * c - y * s, x * s + y * c
    pts[#pts + 1] = ax + face * x
    pts[#pts + 1] = ay - y
  end
  outlinedPoly(pts, col)
end

function V.fencer(b, f)
  local j = f.j
  local face = f.vface or f.face
  local sgn = face < 0 and -1 or 1
  local ox = floor(screenX(b, f.x) + 0.5)
  local function P(lx, ly) return ox + face * lx * PPMc, GROUNDc - ly * PPMc end
  local side = core.SIDE[f.side]

  -- far arm
  local a1x, a1y = P(j.bshx, j.bshy)
  local a2x, a2y = P(j.belx, j.bely)
  local a3x, a3y = P(j.bhx, j.bhy)
  limb({ a1x, a1y, a2x, a2y, a3x, a3y }, { 3.4, 3, 2.4 }, C.whiteS)

  -- the trunk's frame
  local sl, cl = sin(j.lean), cos(j.lean)
  local T = Fencer.TORSO
  local function TP(s, t)
    return P(j.hipx + sl * s * T + cl * t, j.hipy + cl * s * T - sl * t)
  end
  local function shape(list)
    local pts = {}
    for _, st in ipairs(list) do
      local x, y = TP(st[1], st[2])
      pts[#pts + 1], pts[#pts + 2] = x, y
    end
    return pts
  end

  -- back leg
  local hx, hy = P(-0.03, j.hipy)
  local kx, ky = P(j.bkx, j.bky)
  local fx, fy = P(j.bfx, j.bfy)
  limb({ hx, hy, kx, ky, fx, fy }, { 5.4, 4, 3 }, C.whiteS)
  shoe(fx, fy, sgn, (f.legs == "fleche" or f.legs == "walk") and 5 or 3, f.bfp or 0, C.shoe)

  -- the pelvis (breeches) and the front leg as one silhouette: both
  -- outlines first, then both fills, so the thigh flows out of the hips
  local pelvis = shape(PELVIS)
  hx, hy = P(0.03, j.hipy)
  kx, ky = P(j.fkx, j.fky)
  fx, fy = P(j.ffx, j.ffy)
  local leg, legw = { hx, hy, kx, ky, fx, fy }, { 5.4, 4.2, 3.2 }
  outlinedPoly(pelvis, C.white, "ink")
  limb(leg, legw, C.white, "ink")
  outlinedPoly(pelvis, C.white, "fill")
  limb(leg, legw, C.white, "fill")
  -- a touch of shade under the seat
  core.color(C.whiteS)
  local s1x, s1y = TP(-0.12, -0.13)
  local s2x, s2y = TP(-0.14, -0.02)
  gfx.cline(s1x, s1y, s2x, s2y, ow)
  shoe(fx, fy, sgn, 5, f.ffp or 0, C.shoe)

  -- trunk on top: the jacket's hem overlaps the top of the breeches and
  -- thigh, then the lamé (the valid target)
  outlinedPoly(shape(JACKET), C.white)
  core.color(C.lame)
  lg.polygon("fill", shape(LAME))
  core.color(C.lameL)
  local l1x, l1y = TP(0.12, 0.10)
  local l2x, l2y = TP(0.70, 0.11)
  gfx.cline(l1x, l1y, l2x, l2y, ow)
  core.color(C.lameD)
  local d1x, d1y = TP(0.05, -0.09)
  local d2x, d2y = TP(0.75, -0.10)
  gfx.cline(d1x, d1y, d2x, d2y, ow)
  -- side colour on the back of the collar
  core.color(side.col)
  local cx, cy = TP(0.93, -0.06)
  crect(cx - R(1), cy, R(2), ow)

  -- mask
  local mx, my = P(j.headx, j.heady)
  local K = art.K
  lg.setColor(1, 1, 1, 1)
  lg.draw(art.mask, floor(mx + 0.5), floor(my + 0.5), 0, sgn * K, K, art.maskO[1], art.maskO[2])

  -- sword arm
  local s1x, s1y = P(j.shx, j.shy)
  local s2x, s2y = P(j.elx, j.ely)
  local s3x, s3y = P(j.hx, j.hy)
  limb({ s1x, s1y, s2x, s2y, s3x, s3y }, { 3.6, 3.2, 2.8 }, C.white)
  -- glove in the side colour
  local g = max(2, R(2))
  core.color(C.ink)
  crect(s3x - g / 2 - ow, s3y - g / 2 - ow, g + 2 * ow, g + 2 * ow)
  core.color(side.col)
  crect(s3x - g / 2, s3y - g / 2, g, g)
end

function V.blade(b, f)
  local j = f.j
  local face = f.vface or f.face
  local ox = floor(screenX(b, f.x) + 0.5)
  local hx, hy = ox + face * j.hx * PPMc, GROUNDc - j.hy * PPMc
  local ba = math.atan2(j.tipy - j.hy, j.tipx - j.hx)
  local dx, dy = cos(ba) * face, -sin(ba)
  local L = Fencer.BLADE * PPMc
  local tx, ty
  local path = {}
  local bent = false
  if f.hit and f.opp then
    -- the blade bends against the target, but only while the point is
    -- still there (a bend shortens the blade, it never stretches it)
    local o = f.opp
    tx = screenX(b, o.x + o.face * f.hit.lx)
    ty = GROUNDc - f.hit.ly * PPMc
    bent = (tx - hx) ^ 2 + (ty - hy) ^ 2 <= (L * 1.02) ^ 2
  end
  if bent then
    local qx, qy = hx + dx * L * 0.55, hy + dy * L * 0.55
    local n = floor(8 * S)
    for k = 0, n do
      local t = k / n
      path[#path + 1] = { (1 - t) * (1 - t) * hx + 2 * (1 - t) * t * qx + t * t * tx,
        (1 - t) * (1 - t) * hy + 2 * (1 - t) * t * qy + t * t * ty }
    end
  else
    tx, ty = hx + dx * L, hy + dy * L
    path[1], path[2] = { hx, hy }, { tx, ty }
  end
  -- shadow, then steel
  core.color(C.ink, 0.8)
  for k = 1, #path - 1 do gfx.cline(path[k][1], path[k][2] + ow, path[k + 1][1], path[k + 1][2] + ow, ow) end
  core.color(C.blade)
  for k = 1, #path - 1 do gfx.cline(path[k][1], path[k][2], path[k + 1][1], path[k + 1][2], ow) end
  core.color(C.bladeD)
  gfx.cpx(tx, ty, ow)
  -- bell guard, across the blade
  local nx, ny = -dy, dx
  local gl, go = 2.5 * S, 1.5 * S
  core.color(C.ink)
  gfx.cline(hx + dx * go - nx * gl, hy + dy * go - ny * gl + ow, hx + dx * go + nx * gl, hy + dy * go + ny * gl + ow, ow)
  core.color(C.guard)
  gfx.cline(hx + dx * go - nx * gl, hy + dy * go - ny * gl, hx + dx * go + nx * gl, hy + dy * go + ny * gl, ow)
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
    local x = floor(dX(b, f.x + f.face * f.j.headx))
    local y = floor(GROUND - (f.j.heady + 0.22) * PPM) - 9 + floor(sin(core.time * 8) + 0.5)
    gfx.text("▼", x, y, C.yellow, "center", true)
  end
  -- the line of an incoming attack, next to the human fencer
  for i = 1, 2 do
    local me, op = b.f[i], b.f[3 - i]
    if me.human and op.offense then
      local up = op.attackLine == "high"
      local x = floor(dX(b, me.x + me.face * 0.75))
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

-- A score digit: a new score flashes white-hot, then fades back to normal
-- through a halo in the scorer's colour.
local function scoreText(b, i, s, x, align)
  local g = b.scoreGlow and b.scoreGlow[i] or 0
  local k2 = 2 * ((S >= 3) and 2 or 1)          -- the font's draw scale
  local w = gfx.font:getWidth(s) * k2
  local X = floor(x * S + 0.5)
  local lx = (align == "right") and (X - w) or X
  local y = floor(2 * S + 0.5) - ((S == 1) and 2 or 3) * k2
  local scale = k2
  if g > 0 then
    local k = g / Bout.GLOW
    local pulse = k ^ 0.7 * (0.8 + 0.2 * sin(core.time * 18))
    local col = core.SIDE[i].col
    local r1, r2 = max(1, floor(S)), max(2, floor(2 * S))
    for _, r in ipairs({ r2, r1 }) do
      lg.setColor(col[1], col[2], col[3], pulse * (r == r2 and 0.28 or 0.6))
      for dy = -r, r do
        for dx = -r, r do
          if (dx ~= 0 or dy ~= 0) and abs(dx) + abs(dy) <= r + ((r == r2) and 1 or 0) then
            lg.print(s, floor(lx + dx), floor(y + dy), 0, scale, scale)
          end
        end
      end
    end
    -- white-hot at first, cooling to the normal colour
    local t, hot = C.text, C.lampW
    local h = k ^ 1.5
    lg.setColor(core.lerp(t[1], hot[1], h), core.lerp(t[2], hot[2], h), core.lerp(t[3], hot[3], h), 1)
  else
    core.color(C.text)
  end
  lg.print(s, floor(lx), floor(y), 0, scale, scale)
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
  -- names, with their flags, kept clear of the score
  local f1, f2 = b.f[1], b.f[2]
  local fw1 = f1.nation and (Nations.drawFlag(f1.nation, 3, 9) + 3) or 0
  local fw2 = f2.nation and (Nations.drawFlag(f2.nation, W - 3 - Nations.flagW(), 9) + 3) or 0
  local room = W / 2 - 42 - 3
  local n1 = gfx.fit(f1.name, room - fw1)
  local n2 = gfx.fit(f2.name, room - fw2)
  gfx.text(n1, 3 + fw1, 10, C.redL)
  gfx.text(n2, W - 3 - fw2, 10, C.greenL, "right")
  -- score
  if not b.o.drill then
    scoreText(b, 1, tostring(b.score[1]), W / 2 - 17, "right")
    scoreText(b, 2, tostring(b.score[2]), W / 2 + 18, "left")
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
    local px = b.priorityHolder == 1 and (3 + fw1 + gfx.textWidth(n1) + 4) or (W - 3 - fw2 - gfx.textWidth(n2) - 10)
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
  refresh()
  local sh = 0
  if b.shake and b.shake > 0 then sh = (floor(core.time * 60) % 2 == 0) and ow or -ow end
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
  for i = 1, 2 do drawCord(b, b.f[i], i) end
  -- the fencer further forward in an exchange is drawn last
  local order = { 1, 2 }
  if b.f[1].legs == "lunge" or b.f[1].legs == "fleche" then order = { 2, 1 } end
  for _, i in ipairs(order) do V.fencer(b, b.f[i]) end
  for _, i in ipairs(order) do V.blade(b, b.f[i]) end
  for _, p in ipairs(b.fx) do
    core.color(p.col)
    gfx.cpx(screenX(b, p.x), GROUNDc - p.y * PPMc, ow)
  end
  if b.o.drill and b.o.drill.drawWorld then b.o.drill:drawWorld(b, dX) end
  if not b.o.noHud then drawAssists(b) end
  lg.pop()
  if b.o.noHud then return end
  V.topBar(b)
  V.bottomBar(b)
  drawCalls(b)
  if b.o.drill and b.o.drill.drawHud then b.o.drill:drawHud(b) end
end

V.screenX = dX
return V
