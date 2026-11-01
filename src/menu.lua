-- A vertical menu: up/down to choose, left/right to change a value,
-- A to activate, B to go back.

local core = require("src.core")
local gfx = require("src.gfx")
local input = require("src.input")
local audio = require("src.audio")

local floor = math.floor
local C = core.C

local M = {}
M.__index = M

-- items: { label = "...", value = fn -> string, left = fn, right = fn,
--          action = fn, disabled = bool | fn, hint = "..." }
function M.new(items, o)
  local m = setmetatable({}, M)
  m.items = items
  m.sel = 1
  m.o = o or {}
  m.rowH = m.o.rowH or 12
  m:fix(1)
  return m
end

local function disabled(it)
  if type(it.disabled) == "function" then return it.disabled() end
  return it.disabled
end

function M:fix(dir)
  local n = #self.items
  for _ = 1, n do
    local it = self.items[self.sel]
    if it and not disabled(it) and not it.header then return end
    self.sel = (self.sel - 1 + dir) % n + 1
  end
end

function M:update()
  local n = #self.items
  if input.nav("up") then
    self.sel = (self.sel - 2) % n + 1
    self:fix(-1)
    audio.play("blip", 0.4)
  elseif input.nav("down") then
    self.sel = self.sel % n + 1
    self:fix(1)
    audio.play("blip", 0.4)
  end
  local it = self.items[self.sel]
  if not it then return end
  if input.nav("left") and it.left then
    it.left()
    audio.play("blip", 0.4, 0.9)
  elseif input.nav("right") and it.right then
    it.right()
    audio.play("blip", 0.4, 1.1)
  elseif input.pressed.a and (it.action or it.right) then
    audio.play("select", 0.5)
    if it.action then it.action() else it.right() end
  elseif input.pressed.b and self.o.back then
    audio.play("back", 0.5)
    self.o.back()
  end
end

function M:draw(x, y, w)
  local rh = self.rowH
  for k, it in ipairs(self.items) do
    local yy = y + (k - 1) * rh
    if it.header then
      gfx.text(it.label, x + 2, yy + 2, C.dim)
    else
      local sel = (k == self.sel)
      local off = disabled(it)
      if sel then
        core.color(C.panelL)
        gfx.rect(x, yy, w, rh - 1)
        core.color(C.yellow)
        gfx.rect(x, yy, 1, rh - 1)
      end
      local col = off and C.dark or (sel and C.text or C.whiteS)
      local lx = x + 6
      if it.flag then
        lx = lx + require("src.nations").drawFlag(it.flag, lx, yy + 1) + 4
      end
      local ty = (rh <= 9) and 1 or 2
      gfx.text(it.label, lx, yy + ty, col)
      if it.value then
        local v = it.value()
        local vx = x + w - 4
        if sel and (it.left or it.right) then
          gfx.text("►", vx, yy + ty, C.yellow, "right")
          vx = vx - 8
          local vw = gfx.textWidth(v)
          gfx.text(v, vx, yy + ty, C.yellow, "right")
          gfx.text("◄", vx - vw - 3, yy + ty, C.yellow, "right")
        else
          gfx.text(v, vx, yy + ty, sel and C.yellow or C.dim, "right")
        end
      end
    end
  end
  local it = self.items[self.sel]
  return it and it.hint
end

return M
