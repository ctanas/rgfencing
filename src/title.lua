-- Title screen: a live AI bout behind the logo, the main menu, quick bout
-- setup and options.

local core = require("src.core")
local gfx = require("src.gfx")
local art = require("src.art")
local input = require("src.input")
local audio = require("src.audio")
local settings = require("src.settings")
local Bout = require("src.bout")
local Play = require("src.play")
local AI = require("src.ai")
local Ctl = require("src.controller")
local Menu = require("src.menu")
local Names = require("src.names")
local Help = require("src.help")
local Profile = require("src.profile")
local Nations = require("src.nations")

local lg = love.graphics
local C = core.C
local W, H = core.W, core.H

local T = {}
T.__index = T

T.LEVEL_INFO = {
  "SLOW TO REACT, EASY TO FOOL",
  "A SOLID CLUB FENCER",
  "QUICK, AND HARD TO FEINT",
  "FAST, READS YOUR FEINTS",
}
T.STYLE_INFO = {
  "A STYLE PICKED AT RANDOM",
  "A BIT OF EVERYTHING",
  "PRESSES FORWARD, BEATS AND ATTACKS",
  "WAITS, THEN ATTACKS YOUR PREPARATION",
  "PARRIES AND RIPOSTES",
  "LOVES THE FLÈCHE FROM LONG DISTANCE",
}
T.TOUCHES = { 5, 10, 15 }

local function styleName(i)
  if i == 1 then return "RANDOM" end
  return AI.STYLE_NAME[AI.STYLE_ORDER[i - 1]]
end

function T.startQuick(app)
  local d = settings.data
  local touches = T.TOUCHES[d.qtouches]
  local function go()
    local style = d.qstyle == 1 and AI.STYLE_ORDER[love.math.random(1, #AI.STYLE_ORDER)] or AI.STYLE_ORDER[d.qstyle - 1]
    local ai = AI.new(d.qlevel, style)
    local nm = Names.random()
    local me, nation = Profile.fencer()
    app.set(Play.new(app, {
      left = { name = me, nation = nation, human = true, ctl = Ctl.human(input) },
      right = { name = nm.last, nation = nm.nation, ctl = ai, spd = ai.spd },
      touches = touches,
      title = "QUICK BOUT",
      restart = go,
      onFinish = function(b)
        Profile.recordBout(b.winner == 1, b.score[1], b.score[2])
        app.toTitle("quick")
      end,
    }))
  end
  go()
end

local function demoBout()
  local s1 = AI.STYLE_ORDER[love.math.random(1, #AI.STYLE_ORDER)]
  local s2 = AI.STYLE_ORDER[love.math.random(1, #AI.STYLE_ORDER)]
  local a1, a2 = AI.new(3 + love.math.random(), s1), AI.new(3 + love.math.random(), s2)
  return Bout.new({
    left = { name = "A", ctl = a1, spd = a1.spd },
    right = { name = "B", ctl = a2, spd = a2.spd },
    touches = 99, skipIntro = true, silent = true, endless = true, noClock = true, noHud = true,
  })
end

function T.new(app, sub)
  local t = setmetatable({}, T)
  t.app = app
  t.demo = demoBout()
  t.t = 0
  local d = settings.data
  local function onoff(v) return v and "ON" or "OFF" end

  t.main = Menu.new({
    { label = "QUICK BOUT", action = function() t.mode = "quick" end },
    { label = "CAREER", action = function() require("src.career").hub(app) end },
    { label = "TRAINING", action = function() require("src.training").menu(app) end },
    { label = "PROFILE", action = function() require("src.profiles_ui").screen(app) end },
    { label = "HOW TO PLAY", action = function()
      app.set(Help.scene(app, function() app.toTitle() end))
    end },
    { label = "OPTIONS", action = function() t.mode = "options" end },
    { label = "QUIT", action = function() love.event.quit() end },
  })

  local function cycle(key, n, dir)
    return function() d[key] = (d[key] - 1 + dir) % n + 1 end
  end
  t.quick = Menu.new({
    { label = "OPPONENT", value = function() return AI.LEVELS[d.qlevel].name end,
      left = cycle("qlevel", 4, -1), right = cycle("qlevel", 4, 1) },
    { label = "STYLE", value = function() return styleName(d.qstyle) end,
      left = cycle("qstyle", 6, -1), right = cycle("qstyle", 6, 1) },
    { label = "TOUCHES", value = function() return tostring(T.TOUCHES[d.qtouches]) end,
      left = cycle("qtouches", 3, -1), right = cycle("qtouches", 3, 1) },
    { label = "EN GARDE !", action = function()
      settings.save()
      T.startQuick(app)
    end },
    { label = "BACK", action = function() t.mode = "main" end },
  }, { back = function() t.mode = "main" end })

  local function toggle(key, after)
    return function()
      d[key] = not d[key]
      if after then after(d[key]) end
    end
  end
  t.options = Menu.new({
    { label = "SOUND", value = function() return onoff(d.sound) end,
      left = toggle("sound", audio.setEnabled), right = toggle("sound", audio.setEnabled) },
    { label = "CROWD", value = function() return onoff(d.crowd) end,
      left = toggle("crowd", function(v) audio.crowd = v end), right = toggle("crowd", function(v) audio.crowd = v end) },
    { label = "ASSISTS", value = function() return onoff(d.assist) end,
      left = toggle("assist"), right = toggle("assist") },
    { label = "SWAP A/B", value = function() return onoff(d.swapab) end,
      left = toggle("swapab", function(v) input.swapAB = v end), right = toggle("swapab", function(v) input.swapAB = v end) },
    { label = "SHOW FPS", value = function() return onoff(d.fps) end,
      left = toggle("fps"), right = toggle("fps") },
    { label = "BACK", action = function() settings.save(); t.mode = "main" end },
  }, { back = function() settings.save(); t.mode = "main" end })

  t.mode = sub or "main"
  if sub == "quick" then t.main.sel = 1 end
  return t
end

function T:update(dt)
  self.t = self.t + dt
  self.demo:update(dt)
  audio.ambience(0.05, dt)
  local m = self[self.mode]
  m:update()
end

local OPT_INFO = {
  "SOUND EFFECTS",
  "CROWD NOISE AND CHEERS",
  "PRIORITY MARKER, ATTACK LINE ARROW, DISTANCE COLOUR",
  "FOR PADS THAT LABEL A AND B THE OTHER WAY ROUND",
  "FRAMES PER SECOND IN THE CORNER",
  "",
}

function T:draw()
  self.demo:draw()
  core.color(C.ink, 0.38)
  gfx.rect(0, 0, W, H)
  core.color(C.ink, 0.5)
  gfx.rect(0, 0, W, 50)

  -- logo
  local lx = W / 2
  lg.setColor(1, 1, 1, 1)
  lg.draw(art.foils, lx - 100, 10, 0, 2, 2)
  lg.draw(art.foils, lx + 68, 10, 0, 2, 2)
  gfx.text("RG", lx, 7, C.yellow, "center", true)
  gfx.text("FENCING", lx + 1, 18, C.text, "center", true, 3)
  gfx.text("FOIL · RIGHT OF WAY", lx, 43, C.dim, "center", true)

  local m = self[self.mode]
  local rows = #m.items
  local w = self.mode == "main" and 104 or 176
  local x, y = math.floor((W - w) / 2), 56
  local title = (self.mode == "quick" and "QUICK BOUT") or (self.mode == "options" and "OPTIONS") or nil
  if title then
    gfx.panel(x - 4, y - 2, w + 8, rows * 12 + 16)
    gfx.text(title, W / 2, y + 1, C.yellow, "center")
    m:draw(x, y + 12, w)
  else
    gfx.panel(x - 4, y - 2, w + 8, rows * 12 + 5)
    m:draw(x, y + 1, w)
  end

  -- a line about the selected setting
  local info
  if self.mode == "quick" then
    local d = settings.data
    if m.sel == 1 then info = T.LEVEL_INFO[d.qlevel]
    elseif m.sel == 2 then info = T.STYLE_INFO[d.qstyle]
    elseif m.sel == 3 then info = d.qtouches == 3 and "THREE PERIODS OF 3 MIN, BREAK AT 8" or (T.TOUCHES[d.qtouches] == 10 and "TWO PERIODS OF 3 MIN" or "ONE PERIOD OF 3 MIN")
    end
  elseif self.mode == "options" then
    info = OPT_INFO[m.sel]
  end
  if info and info ~= "" then gfx.text(info, W / 2, H - 25, C.dim, "center", true) end

  -- the active fencer
  local p = Profile.current()
  if p then
    local nw = gfx.textWidth(p.name)
    Nations.drawFlag(p.nation, W - 4 - nw - 14, 3)
    gfx.text(p.name, W - 4, 4, C.text, "right", true)
  end
  if self.mode == "main" then
    gfx.text("V" .. core.VERSION, 3, H - 10, C.dark)
    gfx.hints({ { "A", "SELECT" } }, W - 3, H - 11, "right")
  else
    gfx.hints({ { "A", "SELECT" }, { "B", "BACK" } }, W - 3, H - 11, "right")
  end
end

function T:shot(mode)
  if mode == "options" or mode == "quick" then self.mode = mode end
end

return T
