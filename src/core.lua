-- Shared constants, palette and small helpers used by every module.

local core = {
  VERSION = "0.3.0",
  -- Layout ("design") units: every screen is laid out in a 240x160 space.
  W = 240,
  H = 160,
  PPM = 30,          -- design pixels per metre on the piste
  GROUND = 128,      -- design y of the fencers' feet
  time = 0,          -- global clock, seconds
  device = false,    -- true when running fullscreen on the handheld
}

-- Render resolutions. S = canvas pixels per design pixel; the canvas is
-- scaled up by a whole number to fill the RG34XXSP's 720x480 panel.
core.RES = {
  { w = 240, h = 160, s = 1, name = "240×160" },
  { w = 360, h = 240, s = 1.5, name = "360×240" },
  { w = 720, h = 480, s = 3, name = "720×480" },
}
core.res, core.S, core.CW, core.CH = 2, 1.5, 360, 240

function core.setRes(i)
  local r = core.RES[i] or core.RES[2]
  core.res = core.RES[i] and i or 2
  core.S, core.CW, core.CH = r.s, r.w, r.h
end

-- Piste geometry (metres, centre line at x = 0). FIE: 14 m between the end
-- lines, en-garde lines 2 m from the centre, warning zone the last 2 m,
-- run-off beyond the end lines.
core.END = 7
core.WARN = 5
core.ENGARDE = 2
core.RUNOFF = 9

local function hex(s)
  return {
    tonumber(s:sub(1, 2), 16) / 255,
    tonumber(s:sub(3, 4), 16) / 255,
    tonumber(s:sub(5, 6), 16) / 255,
  }
end
core.hex = hex

-- The palette. Everything on screen is drawn with these colours.
core.C = {
  ink = hex"15111c", night = hex"1b1726", wall = hex"241f33", wall2 = hex"2e2842",
  seat = hex"3a3352", floor = hex"211e2c", floor2 = hex"2a2637",
  pisteD = hex"4c5366", piste = hex"6b7487", pisteL = hex"929bad", line = hex"e9edf3",
  warn = hex"9a4648", warnL = hex"b8605a", runoff = hex"363a48",
  white = hex"f3efe6", whiteS = hex"c9c5d4", whiteD = hex"98949f",
  lame = hex"8d9bb6", lameL = hex"d4dded", lameD = hex"5f6a86",
  mesh = hex"2a2a35", meshL = hex"4d4d5e", rim = hex"8d93a3",
  shoe = hex"2c2836", cable = hex"6a6580",
  blade = hex"e2e8f0", bladeD = hex"8b94a6", guard = hex"c3cad6",
  red = hex"e2484a", redD = hex"8f2633", redL = hex"ff9582",
  green = hex"3cc46b", greenD = hex"1f7442", greenL = hex"a0f2b0",
  lampW = hex"fff6d8", lampOff = hex"2b2738",
  gold = hex"f3c64f", silver = hex"c5ccd8", bronze = hex"c27a3e",
  text = hex"f3efe6", dim = hex"8b85a0", dark = hex"58526a",
  skin = hex"e1ae8c", skinD = hex"b07a5e", hair = hex"3b2a22",
  suit = hex"232638", suitL = hex"333852", shirt = hex"b8bcc6", tie = hex"7a2230",
  refSkin = hex"b48a72", refHair = hex"2a201c",
  yellow = hex"ffd84a", orange = hex"f08a3c", blue = hex"5a8ae0",
  panel = hex"1d1929", panelL = hex"2c2740", edge = hex"5c5574",
}

-- Each side's colours: [1] = left (red), [2] = right (green).
core.SIDE = {
  { name = "RED", col = core.C.red, dark = core.C.redD, light = core.C.redL },
  { name = "GREEN", col = core.C.green, dark = core.C.greenD, light = core.C.greenL },
}

function core.color(c, a)
  love.graphics.setColor(c[1], c[2], c[3], a or 1)
end

function core.clamp(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

function core.lerp(a, b, t) return a + (b - a) * t end

-- Frame-rate independent exponential approach.
function core.approach(cur, target, rate, dt)
  return cur + (target - cur) * (1 - math.exp(-rate * dt))
end

-- Progress of u through the window [a, b], clamped to 0..1.
function core.seg(u, a, b)
  if u <= a then return 0 elseif u >= b then return 1 end
  return (u - a) / (b - a)
end

function core.smooth(u) return u * u * (3 - 2 * u) end
function core.easeOut(u) return 1 - (1 - u) * (1 - u) end
function core.easeIn(u) return u * u end

-- Approximately normal noise (sum of uniforms), mean 0, sd ~1.
function core.gauss()
  local r = love.math.random
  return (r() + r() + r() + r() - 2) * 1.732
end

function core.fmtClock(s)
  s = math.max(0, math.ceil(s - 1e-6))
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

return core
