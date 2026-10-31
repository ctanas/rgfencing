-- Pixel art: hand-drawn sprites, and arena layers generated pixel by pixel
-- at start-up (crowd, light shafts, barrier boards). Nothing is loaded
-- from files.

local core = require("src.core")
local gfx = require("src.gfx")

local lg = love.graphics
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local C = core.C

local art = {}

-- Bayer 4x4 ordered-dither thresholds (0..1).
local BAYER = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }
local function bayer(x, y) return (BAYER[(y % 4) * 4 + (x % 4) + 1] + 0.5) / 16 end
art.bayer = bayer

-- Fencing mask, side view, facing right. k ink, w padding / bib, s rim,
-- m mesh, h mesh highlight.
art.MASK = {
  "..kkkkk..",
  ".kwsmmmk.",
  "kwwsmhmmk",
  "kwwsmmhmk",
  "kwwsmmmhk",
  "kwwsmmmmk",
  ".kwwsmmk.",
  "..kwwwwk.",
  "...kwwwk.",
  "....kkk..",
}

-- Crossed foils for the title (16x16): b blade, g guard, k ink.
art.FOILS = {
  "b..............b",
  ".b............b.",
  "..b..........b..",
  "...b........b...",
  "....b......b....",
  ".....b....b.....",
  "......b..b......",
  ".......bb.......",
  ".......bb.......",
  "......b..b......",
  "....gg....gg....",
  "...gggk..kggg...",
  "....kk....kk....",
  "...k........k...",
  "..k..........k..",
  ".k............k.",
}

local function setRect(img, x, y, w, h, c, a)
  local iw, ih = img:getDimensions()
  for yy = max(0, y), min(ih - 1, y + h - 1) do
    for xx = max(0, x), min(iw - 1, x + w - 1) do
      img:setPixel(xx, yy, c[1], c[2], c[3], a or 1)
    end
  end
end

local function shade(c, k)
  return { c[1] * k, c[2] * k, c[3] * k }
end

local SHIRTS = {
  "6c4a5e", "4a5a7c", "7a5c48", "3f6a5a", "8a7a5a", "5e4a82", "7c3f45", "4f6f8f", "9a8f7a", "3d4a5c",
  "a05a3a", "3a7a8a", "8a3a6a", "6a8a4a", "c0b090", "2f4f6f",
}
local SKINS = { "e1ae8c", "c08a6a", "8d5a40", "f0c8a8", "6a4230", "d49a78" }
local HAIRS = { "2a1d18", "4a3426", "8a6a3a", "1c1c22", "6a4a2a", "b0a090" }

-- The stands: tiers of spectators, darker towards the back, with light
-- shafts dithered over them. Returns two images: calm and cheering.
local function buildCrowd(w, h)
  local rng = love.math.newRandomGenerator(7)
  local frames = {}
  local people = {}
  local rows = 8
  for r = 0, rows - 1 do
    local base = h - 3 - r * 8
    local x = (r % 2) * 3 - 2
    while x < w do
      if rng:random() > 0.13 then
        people[#people + 1] = {
          x = x + rng:random(0, 1), y = base, r = r,
          shirt = core.hex(SHIRTS[rng:random(1, #SHIRTS)]),
          skin = core.hex(SKINS[rng:random(1, #SKINS)]),
          hair = core.hex(HAIRS[rng:random(1, #HAIRS)]),
          jump = rng:random() < 0.45, arms = rng:random() < 0.55,
          flag = rng:random() < 0.05 and (rng:random() < 0.5 and C.red or C.green) or nil,
        }
      end
      x = x + 6
    end
  end
  for fr = 1, 2 do
    local img = love.image.newImageData(w, h)
    -- wall gradient, dithered
    for y = 0, h - 1 do
      local t = y / h
      for x = 0, w - 1 do
        local c = (t + (bayer(x, y) - 0.5) * 0.25 > 0.45) and C.wall2 or C.wall
        img:setPixel(x, y, c[1], c[2], c[3], 1)
      end
    end
    -- seat rows
    for r = 0, rows - 1 do
      local base = h - 3 - r * 8
      setRect(img, 0, base, w, 2, shade(C.seat, 1 - r * 0.07))
      setRect(img, 0, base + 2, w, 1, shade(C.wall, 0.8))
    end
    for _, p in ipairs(people) do
      local k = 0.78 - p.r * 0.06
      local up = (fr == 2 and p.jump) and 1 or 0
      local y = p.y - up
      setRect(img, p.x, y - 4, 4, 4, shade(p.shirt, k))
      setRect(img, p.x + 1, y - 6, 2, 2, shade(p.skin, k))
      setRect(img, p.x + 1, y - 7, 2, 1, shade(p.hair, k))
      if fr == 2 and p.arms then
        setRect(img, p.x - 1, y - 8, 1, 3, shade(p.skin, k * 0.9))
        setRect(img, p.x + 4, y - 8, 1, 3, shade(p.skin, k * 0.9))
        if p.flag then setRect(img, p.x + 4, y - 11, 3, 2, p.flag) end
      end
    end
    -- light shafts from the roof
    local beams = { { x = 0.18 * w, s = 0.10 }, { x = 0.5 * w, s = 0.13 }, { x = 0.82 * w, s = 0.10 } }
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local I = 0
        for _, bm in ipairs(beams) do
          local spread = 10 + y * 0.9
          local d = abs(x - bm.x) / spread
          if d < 1 then I = I + (1 - d) * bm.s * (0.5 + y / h) end
        end
        if I > bayer(x, y) * 0.5 then
          local r, g, b = img:getPixel(x, y)
          img:setPixel(x, y, min(1, r + 0.07), min(1, g + 0.07), min(1, b + 0.09), 1)
        end
      end
    end
    local im = lg.newImage(img)
    im:setFilter("nearest", "nearest")
    frames[fr] = im
  end
  return frames
end

-- Barrier boards: dark LED panels with a scrolling-sign look.
local function buildBoards(w, h)
  local cv = lg.newCanvas(w, h)
  cv:setFilter("nearest", "nearest")
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, 0)
  core.color(C.ink)
  gfx.rect(0, 0, w, h)
  core.color(core.hex"222a44")
  gfx.rect(0, 1, w, h - 2)
  local x, k = 4, 0
  local words = { "RG FENCING", "·", "FOIL", "·", "ALLEZ !", "·", "EN GARDE", "·" }
  while x < w do
    local s = words[k % #words + 1]
    local col = (s == "·") and C.dim or ((k % 4 == 0) and C.lampW or core.hex"7fb8e8")
    gfx.text(s, x, 3, col)
    x = x + gfx.textWidth(s) + 8
    k = k + 1
  end
  -- LED grid: darken every other row
  core.color(C.ink, 0.35)
  for y = 1, h - 2, 2 do gfx.rect(0, y, w, 1) end
  core.color(C.edge)
  gfx.rect(0, 0, w, 1)
  lg.setCanvas()
  return cv
end

-- The arena floor in front of the barrier, lighter towards the piste.
local function buildFloor(w, h)
  local img = love.image.newImageData(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local c = C.floor
      if y <= 12 and (x + y) % 2 == 0 and bayer(x, y) < y / 14 then c = C.floor2 end
      img:setPixel(x, y, c[1], c[2], c[3], 1)
    end
  end
  local im = lg.newImage(img)
  im:setFilter("nearest", "nearest")
  return im
end

function art.init()
  art.floor = buildFloor(core.W, core.H - 104)
  local legend = {
    k = C.ink, w = C.white, s = C.rim, m = C.mesh, h = C.meshL,
  }
  art.mask = gfx.sprite(art.MASK, legend)
  art.foils = gfx.sprite(art.FOILS, { b = C.blade, g = C.guard, k = C.ink })
  art.crowdW, art.crowdH = 520, 76
  art.crowd = buildCrowd(art.crowdW, art.crowdH)
  art.boardsW = 640
  art.boards = buildBoards(art.boardsW, 12)
end

return art
