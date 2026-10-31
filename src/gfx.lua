-- Pixel drawing helpers: fonts, text, sprites from character grids,
-- Bresenham lines, panels and button icons.
--
-- The game draws into a canvas of 240x160, 360x240 or 720x480 (see
-- core.RES). Screens are laid out once, in 240x160 "design" units: these
-- helpers map design coordinates to whole canvas pixels (x1, x1.5 or x3)
-- and draw text with the font made for the resolution, so layouts stay put
-- and everything stays crisp. Hairlines and outlines stay 1 canvas pixel
-- (2 at 720x480) instead of rounding unevenly.
--
-- The arena and the fencers are drawn natively in canvas pixels by
-- src/view.lua, with the c* helpers below.

local core = require("src.core")
local fontlib = require("src.font")

local lg = love.graphics
local floor, max, abs = math.floor, math.max, math.abs
local C = core.C

local gfx = {}

local S = 1        -- canvas pixels per design pixel
local fs = 1       -- the font's draw scale
local cap = 2      -- font rows above the capitals
local ow = 1       -- outline / hairline width in canvas pixels

function gfx.init()
  gfx.font240 = fontlib.build()
  gfx.font360 = fontlib.build360()
  lg.setLineStyle("rough")
  lg.setLineWidth(1)
  lg.setPointSize(1)
  gfx.setScale(core.S)
end

function gfx.setScale(s)
  S = s
  gfx.S = s
  if s == 1 then
    gfx.font, fs, cap = gfx.font240, 1, fontlib.CAP
  else
    gfx.font, fs, cap = gfx.font360, (s >= 3) and 2 or 1, fontlib.CAP360
  end
  ow = (s >= 3) and 2 or 1
  gfx.ow = ow
  lg.setFont(gfx.font)
end

-- Design units to canvas pixels.
local function cp(v) return floor(v * S + 0.5) end
gfx.cp = cp

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

---------------------------------------------------------------------------
-- Design-unit drawing
---------------------------------------------------------------------------

-- A filled rectangle. A side of exactly 1 design unit is a hairline.
function gfx.rect(x, y, w, h)
  local x0, y0 = cp(x), cp(y)
  local cw = (w == 1) and ow or max(1, cp(x + w) - x0)
  local ch = (h == 1) and ow or max(1, cp(y + h) - y0)
  lg.rectangle("fill", x0, y0, cw, ch)
end

-- One design pixel.
function gfx.px(x, y)
  local x0, y0 = cp(x), cp(y)
  lg.rectangle("fill", x0, y0, max(1, cp(x + 1) - x0), max(1, cp(y + 1) - y0))
end

function gfx.circle(x, y, r)
  lg.circle("fill", x * S, y * S, r * S, 16)
end

-- An image at a design position, drawn at canvas scale k (a whole number).
function gfx.img(img, x, y, k, flip, ox, oy)
  k = k or 1
  lg.setColor(1, 1, 1, 1)
  lg.draw(img, cp(x), cp(y), 0, k * (flip or 1), k, ox or 0, oy or 0)
end

---------------------------------------------------------------------------
-- Canvas-pixel drawing (for the arena)
---------------------------------------------------------------------------

-- A line (Bresenham) in canvas pixels, th pixels thick.
local pts = {}
function gfx.cline(x1, y1, x2, y2, th)
  th = th or 1
  x1, y1, x2, y2 = floor(x1 + 0.5), floor(y1 + 0.5), floor(x2 + 0.5), floor(y2 + 0.5)
  local dx, dy = abs(x2 - x1), -abs(y2 - y1)
  local sx, sy = x1 < x2 and 1 or -1, y1 < y2 and 1 or -1
  local err = dx + dy
  if th > 1 then
    -- thick lines (720x480): one aliased GPU line instead of a square per
    -- pixel; at native resolution the difference doesn't show
    if x1 == x2 and y1 == y2 then
      lg.rectangle("fill", x1, y1, th, th)
    else
      lg.setLineWidth(th)
      lg.line(x1 + 0.5, y1 + 0.5, x2 + 0.5, y2 + 0.5)
      lg.setLineWidth(1)
    end
    return
  end
  local n = 0
  while true do
    pts[n + 1], pts[n + 2] = x1 + 0.5, y1 + 0.5
    n = n + 2
    if x1 == x2 and y1 == y2 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy; x1 = x1 + sx end
    if e2 <= dx then err = err + dx; y1 = y1 + sy end
    if n > 4000 then break end
  end
  for k = n + 1, #pts do pts[k] = nil end
  lg.points(pts)
end

-- A square of sz canvas pixels.
function gfx.cpx(x, y, sz)
  sz = sz or 1
  lg.rectangle("fill", floor(x), floor(y), sz, sz)
end

-- A line in design units (a hairline on canvas).
function gfx.line(x1, y1, x2, y2)
  gfx.cline(x1 * S, y1 * S, x2 * S, y2 * S, ow)
end

---------------------------------------------------------------------------
-- Text (design units)
---------------------------------------------------------------------------

-- UTF-8 characters of a string.
function gfx.chars(s)
  local t = {}
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do t[#t + 1] = ch end
  return t
end

function gfx.textWidth(s, scale)
  return gfx.font:getWidth(s) * fs * (scale or 1) / S
end

-- Shorten s (on character boundaries) to fit maxw design units, ending in ".".
function gfx.fit(s, maxw)
  if gfx.textWidth(s) <= maxw then return s end
  local t = gfx.chars(s)
  while #t > 1 and gfx.textWidth(table.concat(t) .. ".") > maxw do t[#t] = nil end
  return table.concat(t) .. "."
end

-- Text with y at the top of the capitals. align: "left" | "center" | "right".
-- outline: draw an ink border first (readable over anything).
function gfx.text(s, x, y, col, align, outline, scale)
  local k = fs * (scale or 1)
  local w = gfx.font:getWidth(s) * k
  local X = cp(x)
  if align == "center" then X = X - floor(w / 2) elseif align == "right" then X = X - w end
  local Y = cp(y) - cap * k
  if outline then
    core.color(type(outline) == "table" and outline or C.ink)
    for dy = -ow, ow do
      for dx = -ow, ow do
        if dx ~= 0 or dy ~= 0 then lg.print(s, X + dx, Y + dy, 0, k, k) end
      end
    end
  end
  core.color(col or C.text)
  lg.print(s, X, Y, 0, k, k)
  return w / S
end

-- Text with a drop shadow instead of a full outline.
function gfx.stext(s, x, y, col, align, scale)
  local k = fs * (scale or 1)
  local w = gfx.font:getWidth(s) * k
  local X = cp(x)
  if align == "center" then X = X - floor(w / 2) elseif align == "right" then X = X - w end
  local Y = cp(y) - cap * k
  core.color(C.ink)
  lg.print(s, X, Y + ow * (scale or 1), 0, k, k)
  core.color(col or C.text)
  lg.print(s, X, Y, 0, k, k)
  return w / S
end

-- Word-wrapped paragraph; returns the height used (design units).
function gfx.para(s, x, y, w, col, lineH)
  local _, lines = gfx.font:getWrap(s, w * S / fs)
  lineH = lineH or 10
  for k, l in ipairs(lines) do gfx.text(l, x, y + (k - 1) * lineH, col) end
  return #lines * lineH
end

-- Cap height of the current font, in canvas pixels.
function gfx.capH(scale)
  return ((S == 1) and 7 or 10) * fs * (scale or 1)
end

---------------------------------------------------------------------------
-- Panels and buttons
---------------------------------------------------------------------------

-- Framed panel.
function gfx.panel(x, y, w, h, fill, edge, alpha)
  local x0, y0, x1, y1 = cp(x), cp(y), cp(x + w), cp(y + h)
  local b = ow
  core.color(fill or C.panel, alpha or 0.94)
  lg.rectangle("fill", x0 + b, y0 + b, x1 - x0 - 2 * b, y1 - y0 - 2 * b)
  core.color(edge or C.edge)
  lg.rectangle("fill", x0 + b, y0, x1 - x0 - 2 * b, b)
  lg.rectangle("fill", x0 + b, y1 - b, x1 - x0 - 2 * b, b)
  lg.rectangle("fill", x0, y0 + b, b, y1 - y0 - 2 * b)
  lg.rectangle("fill", x1 - b, y0 + b, b, y1 - y0 - 2 * b)
end

-- A handheld button icon (A, B, X, Y, L1, R1, START...). Returns its
-- width in design units.
local BTNCOL = { A = C.red, B = C.yellow, X = C.blue, Y = C.green }
function gfx.button(label, x, y)
  local tw = gfx.textWidth(label)
  local w = max(9, tw + 4)
  local col = BTNCOL[label] or C.dim
  local x0, y0 = cp(x), cp(y)
  local cw, ch = cp(x + w) - x0, cp(y + 9) - y0
  local b = ow
  core.color(C.ink)
  lg.rectangle("fill", x0 + b, y0 - b, cw - 2 * b, ch + 2 * b)
  lg.rectangle("fill", x0, y0, cw, ch)
  core.color(col)
  lg.rectangle("fill", x0 + b, y0, cw - 2 * b, ch)
  core.color(C.ink, 0.35)
  lg.rectangle("fill", x0 + b, y0 + ch - b, cw - 2 * b, b)
  core.color(C.ink)
  local twc = gfx.font:getWidth(label) * fs
  lg.print(label, x0 + floor((cw - twc) / 2), y0 + floor((ch - gfx.capH()) / 2) - cap * fs, 0, fs, fs)
  return w
end

-- "[A] LUNGE  [B] PARRY" style hint line; items = { {"A", "LUNGE"}, ... }.
function gfx.hints(items, x, y, align)
  local total = 0
  for _, it in ipairs(items) do
    total = total + max(9, gfx.textWidth(it[1]) + 4) + 3 + gfx.textWidth(it[2]) + 8
  end
  total = total - 8
  if align == "center" then x = x - floor(total / 2) elseif align == "right" then x = x - total end
  for _, it in ipairs(items) do
    local w = gfx.button(it[1], x, y)
    x = x + w + 3
    gfx.stext(it[2], x, y + 1, C.text)
    x = x + gfx.textWidth(it[2]) + 8
  end
end

return gfx
