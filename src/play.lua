-- Play: a bout on screen, with the pause menu and the end-of-bout panel.
--
-- opts are passed to Bout.new, plus:
--   title       shown in the pause menu
--   onFinish(b) when the bout is over and the player has seen the result
--   onQuit()    when the player leaves from the pause menu
--   restart()   if given, the pause menu offers RESTART

local core = require("src.core")
local gfx = require("src.gfx")
local input = require("src.input")
local audio = require("src.audio")
local Bout = require("src.bout")
local Menu = require("src.menu")
local Help = require("src.help")
local I = require("src.i18n")

local lg = love.graphics
local C = core.C
local W, H = core.W, core.H

local P = {}
P.__index = P

function P.new(app, opts)
  local p = setmetatable({}, P)
  p.app = app
  p.opts = opts
  opts.onFinish = opts.onFinish or function() app.toTitle() end
  p.bout = Bout.new(opts)
  local items = {
    { label = "RESUME", action = function() p.paused = false end },
  }
  if opts.restart then
    items[#items + 1] = { label = "RESTART", action = function() opts.restart() end }
  end
  items[#items + 1] = { label = "CONTROLS", action = function() p.help = true end }
  items[#items + 1] = { label = opts.quitLabel or "QUIT BOUT", action = function()
    if opts.onQuit then opts.onQuit() else app.toTitle() end
  end }
  p.menu = Menu.new(items, { back = function() p.paused = false end })
  return p
end

function P:update(dt)
  if self.help then
    if input.pressed.b or input.pressed.a or input.pressed.start then self.help = false end
    return
  end
  if self.paused then
    if input.pressed.start then
      self.paused = false
      return
    end
    self.menu:update()
    audio.ambience(0.04, dt)
    return
  end
  if input.pressed.start or input.pressed.select then
    self.paused = true
    self.menu.sel = 1
    audio.play("back", 0.4)
    return
  end
  local b = self.bout
  if input.pressed.a or input.pressed.b then b.skip = true end
  b:update(dt)
  audio.ambience(0.10, dt)
end

function P:draw()
  self.bout:draw()
  if self.drawExtra then self:drawExtra() end
  local b = self.bout
  if b.phase == "over" then self:drawResult() end
  if self.paused then
    core.color(C.ink, 0.6)
    gfx.rect(0, 0, W, H)
    local w, h = 120, 20 + #self.menu.items * 12
    local x, y = (W - w) / 2, 40
    gfx.panel(x, y, w, h)
    gfx.text(self.opts.title or "PAUSED", W / 2, y + 5, C.yellow, "center")
    self.menu:draw(x + 4, y + 16, w - 8)
  end
  if self.help then Help.drawControls(self.opts.controls) end
end

function P:drawResult()
  local b = self.bout
  if b.pt < 0.6 then return end
  local w = b.winner
  local wf = b.f[w]
  local x, y, pw, ph = 30, 22, W - 60, 104
  if b.o.drill then
    local d = b.o.drill
    gfx.panel(x, 40, pw, 56)
    gfx.text("DRILL COMPLETE", W / 2, 47, C.gold, "center", true, 2)
    gfx.text(d.def.name, W / 2, 68, C.text, "center")
    if b.pt > 0.8 and math.floor(core.time * 2) % 2 == 0 then
      gfx.hints({ { "A", "CONTINUE" } }, W / 2, 82, "center")
    end
    return
  end
  gfx.panel(x, y, pw, ph)
  local human = wf.human
  local anyHuman = b.f[1].human or b.f[2].human
  local title = anyHuman and (human and "VICTORY" or "DEFEAT") or I.f("%s WINS", wf.name)
  gfx.text(title, W / 2, y + 6, human and C.gold or (anyHuman and C.redL or C.text), "center", true, 2)
  gfx.text(string.format("%d - %d", b.score[1], b.score[2]), W / 2, y + 25, C.text, "center")
  -- a few numbers for each fencer
  local rows = {
    { "TOUCHES", function(s) return s.touches end },
    { "PARRIES", function(s) return s.parries end },
    { "BEATS", function(s) return s.beats end },
    { "OFF TARGET", function(s) return s.offTarget end },
  }
  local cy = y + 37
  gfx.text(b.f[1].name, x + 8, cy, C.redL)
  gfx.text(b.f[2].name, x + pw - 8, cy, C.greenL, "right")
  for k, r in ipairs(rows) do
    local yy = cy + k * 9
    gfx.text(r[1], W / 2, yy, C.dim, "center")
    gfx.text(tostring(r[2](b.stats[1])), x + 8, yy, C.text)
    gfx.text(tostring(r[2](b.stats[2])), x + pw - 8, yy, C.text, "right")
  end
  if b.pt > 0.8 and math.floor(core.time * 2) % 2 == 0 then
    gfx.hints({ { "A", "CONTINUE" } }, W / 2, y + ph - 13, "center")
  end
end

return P
