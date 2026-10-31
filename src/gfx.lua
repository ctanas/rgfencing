-- Pixel drawing helpers: font, text, sprites from character grids,
-- Bresenham lines, panels and button icons. Everything works in the
-- 240x160 canvas, in whole pixels.

local core = require("src.core")
local fontlib = require("src.font")

local lg = love.graphics
local floor = math.floor
local C = core.C

local gfx = {}

function gfx.init()
  gfx.font = fontlib.build()
  lg.setFont(gfx.font)
  lg.setLineStyle("rough")
  lg.setLineWidth(1)
  lg.setPointSize(1)
end

-- An image from rows of characters; legend maps characters to colours.
function gfx.sprite(rows, legend)
  local h, w = #rows, #rows[1]
  local img = love.image.newImageData(w, h)
  for y = 1, h do
    local row = rows[y]
    for x = 1, w do
      local c = legend[row:sub(x, x)]
      if c then img:setPixel(x - 1, y - 1, c[1], c[2], c[3], c[4] or 1) end
    end
  end
  local im = lg.newImage(img)
  im:setFilter("nearest", "nearest")
  return im
end

function gfx.rect(x, y, w, h)
  lg.rectangle("fill", floor(x), floor(y), w, h)
end

function gfx.px(x, y)
  lg.rectangle("fill", floor(x), floor(y), 1, 1)
end

-- 1-pixel line (Bresenham), in the current colour.
local pts = {}
function gfx.line(x1, y1, x2, y2)
  x1, y1, x2, y2 = floor(x1 + 0.5), floor(y1 + 0.5), floor(x2 + 0.5), floor(y2 + 0.5)
  local dx, dy = math.abs(x2 - x1), -math.abs(y2 - y1)
  local sx, sy = x1 < x2 and 1 or -1, y1 < y2 and 1 or -1
  local err = dx + dy
  local n = 0
  while true do
    pts[n + 1], pts[n + 2] = x1 + 0.5, y1 + 0.5
    n = n + 2
    if x1 == x2 and y1 == y2 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy; x1 = x1 + sx end
    if e2 <= dx then err = err + dx; y1 = y1 + sy end
    if n > 2000 then break end
  end
  for k = n + 1, #pts do pts[k] = nil end
  lg.points(pts)
end

-- UTF-8 characters of a string.
function gfx.chars(s)
  local t = {}
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do t[#t + 1] = ch end
  return t
end

-- Shorten s (on character boundaries) to fit maxw pixels, ending in ".".
function gfx.fit(s, maxw)
  if gfx.font:getWidth(s) <= maxw then return s end
  local t = gfx.chars(s)
  while #t > 1 and gfx.font:getWidth(table.concat(t) .. ".") > maxw do t[#t] = nil end
  return table.concat(t) .. "."
end

function gfx.textWidth(s, scale)
  return gfx.font:getWidth(s) * (scale or 1)
end

-- Text with y at the top of the capitals. align: "left" | "center" | "right".
-- outline: draw a 1-pixel ink border first (readable over anything).
function gfx.text(s, x, y, col, align, outline, scale)
  scale = scale or 1
  local w = gfx.font:getWidth(s) * scale
  if align == "center" then x = x - floor(w / 2) elseif align == "right" then x = x - w end
  x, y = floor(x), floor(y) - fontlib.CAP * scale
  if outline then
    core.color(type(outline) == "table" and outline or C.ink)
    for dy = -1, 1 do
      for dx = -1, 1 do
        if dx ~= 0 or dy ~= 0 then lg.print(s, x + dx, y + dy, 0, scale, scale) end
      end
    end
  end
  core.color(col or C.text)
  lg.print(s, x, y, 0, scale, scale)
  return w
end

-- Text with a drop shadow (1 px down) instead of a full outline.
function gfx.stext(s, x, y, col, align, scale)
  scale = scale or 1
  local w = gfx.font:getWidth(s) * scale
  if align == "center" then x = x - floor(w / 2) elseif align == "right" then x = x - w end
  x, y = floor(x), floor(y) - fontlib.CAP * scale
  core.color(C.ink)
  lg.print(s, x, y + scale, 0, scale, scale)
  core.color(col or C.text)
  lg.print(s, x, y, 0, scale, scale)
  return w
end

-- Word-wrapped paragraph; returns the height used.
function gfx.para(s, x, y, w, col, lineH)
  local _, lines = gfx.font:getWrap(s, w)
  lineH = lineH or 10
  for k, l in ipairs(lines) do gfx.text(l, x, y + (k - 1) * lineH, col) end
  return #lines * lineH
end

-- Framed panel.
function gfx.panel(x, y, w, h, fill, edge, alpha)
  core.color(fill or C.panel, alpha or 0.94)
  gfx.rect(x + 1, y + 1, w - 2, h - 2)
  core.color(edge or C.edge)
  gfx.rect(x + 1, y, w - 2, 1)
  gfx.rect(x + 1, y + h - 1, w - 2, 1)
  gfx.rect(x, y + 1, 1, h - 2)
  gfx.rect(x + w - 1, y + 1, 1, h - 2)
end

-- A handheld button icon (A, B, X, Y, L1, R1, START...). Returns width.
local BTNCOL = { A = C.red, B = C.yellow, X = C.blue, Y = C.green }
function gfx.button(label, x, y)
  local tw = gfx.font:getWidth(label)
  local w = math.max(9, tw + 4)
  local col = BTNCOL[label] or C.dim
  x, y = floor(x), floor(y)
  core.color(C.ink)
  gfx.rect(x + 1, y - 1, w - 2, 11)
  gfx.rect(x, y, w, 9)
  core.color(col)
  gfx.rect(x + 1, y, w - 2, 9)
  gfx.rect(x + 2, y - 1 + 1, w - 4, 1)
  core.color(C.ink, 0.35)
  gfx.rect(x + 1, y + 8, w - 2, 1)
  core.color(C.ink)
  lg.print(label, x + floor((w - tw) / 2), y + 1 - fontlib.CAP + 1)
  return w
end

-- "[A] LUNGE  [B] PARRY" style hint line; items = { {"A", "LUNGE"}, ... }.
function gfx.hints(items, x, y, align)
  local total = 0
  for _, it in ipairs(items) do
    total = total + math.max(9, gfx.font:getWidth(it[1]) + 4) + 3 + gfx.font:getWidth(it[2]) + 8
  end
  total = total - 8
  if align == "center" then x = x - floor(total / 2) elseif align == "right" then x = x - total end
  for _, it in ipairs(items) do
    local w = gfx.button(it[1], x, y)
    x = x + w + 3
    gfx.stext(it[2], x, y + 1, C.text)
    x = x + gfx.font:getWidth(it[2]) + 8
  end
end

return gfx
