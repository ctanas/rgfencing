-- Tactical bout on screen: live footwork, and a menu at each exchange
-- (src/tactics.lua decides and stages the outcome).
--
--   ←/→ L1 R1   footwork, live
--   A           attack: the bout stops and you choose how
--   when they attack, after a parry, after a short attack: choose your answer

local core = require("src.core")
local gfx = require("src.gfx")
local input = require("src.input")
local audio = require("src.audio")
local settings = require("src.settings")
local Play = require("src.play")
local AI = require("src.ai")
local Ctl = require("src.controller")
local Names = require("src.names")
local Profile = require("src.profile")
local Tac = require("src.tactics")
local I = require("src.i18n")

local floor, max, min = math.floor, math.max, math.min
local C = core.C
local W, H = core.W, core.H

local TP = setmetatable({}, { __index = Play })
TP.__index = TP

TP.CONTROLS = {
  { "←→", "ADVANCE / RETREAT" },
  { "R1", "BALESTRA (JUMP FORWARD)" },
  { "L1", "JUMP BACK" },
  { "A", "ATTACK: CHOOSE HOW" },
  { "↑↓", "CHOOSE IN A MENU" },
  { "A", "CONFIRM" },
  { "B", "CANCEL AN ATTACK" },
  { "START", "PAUSE" },
}

-- An AI that only moves its feet: its blade actions come from the menus.
local function footworkAI(level, style)
  local ai = AI.new(level, style)
  local S = {}
  for k, v in pairs(ai.S) do S[k] = v end
  S.attack, S.fleche, S.beat, S.line, S.counter, S.remise = 0, 0, 0, 0, 0, 0
  ai.S = S
  return ai
end

function TP.start(app)
  local d = settings.data
  local function go()
    local level = d.tlevel
    local style = d.tstyle == 1 and AI.STYLE_ORDER[love.math.random(1, #AI.STYLE_ORDER)] or AI.STYLE_ORDER[d.tstyle - 1]
    local ai = footworkAI(level, style)
    local nm = (love.math.random() < 0.15) and Names.RIVALS[love.math.random(1, #Names.RIVALS)] or Names.random()
    local me, nation = Profile.fencer()
    local side = d.side
    local live = {
      [side] = Tac.footworkOnly(Ctl.human(input)),
      [3 - side] = Tac.footworkOnly(ai),
    }
    local player = { name = me, nation = nation, human = true, ctl = live[side] }
    local opp = { name = nm.last, nation = nm.nation, ctl = live[3 - side], spd = ai.spd }
    local p = Play.new(app, {
      left = (side == 1) and player or opp,
      right = (side == 1) and opp or player,
      touches = require("src.title").TOUCHES[d.ttouches],
      title = "TACTICAL BOUT",
      controls = TP.CONTROLS,
      restart = go,
      onFinish = function(b)
        Profile.recordBout(b.winner == side, b.score[side], b.score[3 - side])
        app.toTitle("tactical")
      end,
    })
    setmetatable(p, TP)
    p:init(side, level, style, live)
    app.set(p)
  end
  go()
end

function TP:init(side, level, style, live)
  local b = self.bout
  self.side = side
  local sides = {}
  sides[side] = { human = true, ratings = Tac.playerRatings(Profile.current()), live = live[side] }
  sides[3 - side] = {
    human = false, ratings = Tac.cpuRatings(level, style), brain = Tac.brain(level, style),
    style = style, level = level, live = live[3 - side],
  }
  self.match = Tac.match(b, sides, function(i, menu, info, done) self:openMenu(menu, info, done) end)
end

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------

function TP:update(dt)
  if self.help or self.paused or input.pressed.start or input.pressed.select then
    return Play.update(self, dt)
  end
  local b, m = self.bout, self.match
  if self.menu2 then
    self:updateMenu()
    audio.ambience(0.06, dt)
    return
  end
  if m.mode == "live" and not m.waiting then
    if b.phase == "fence" then
      if input.pressed.a and m:canAttack(self.side) then
        m:requestAttack(self.side)
        return
      end
    elseif input.pressed.a or input.pressed.b then
      b.skip = true
    end
  end
  m:frame(dt, function(d) b:update(d) end)
  audio.ambience(0.10, dt)
end

---------------------------------------------------------------------------
-- The menu
---------------------------------------------------------------------------

function TP:openMenu(menu, info, done)
  self.menu2 = { menu = menu, info = info, done = done, sel = 1, opts = Tac.MENU[menu], t = 0 }
  audio.play("blip", 0.5, 0.8)
end

local function grid(n)
  local cols = (n >= 4) and 2 or 1
  return cols, math.ceil(n / cols)
end

function TP:updateMenu()
  local g = self.menu2
  local n = #g.opts
  local cols, rows = grid(n)
  local c, r = floor((g.sel - 1) / rows), (g.sel - 1) % rows
  local moved = false
  if input.nav("up") then r = (r - 1) % rows; moved = true
  elseif input.nav("down") then r = (r + 1) % rows; moved = true
  elseif input.nav("left") and cols > 1 then c = (c - 1) % cols; moved = true
  elseif input.nav("right") and cols > 1 then c = (c + 1) % cols; moved = true
  end
  if moved then
    local s = c * rows + r + 1
    if s > n then s = n end
    g.sel = s
    audio.play("blip", 0.4)
  end
  if input.pressed.a then
    self.menu2 = nil
    audio.play("select", 0.5)
    g.done(g.opts[g.sel])
  elseif input.pressed.b and g.info.cancel then
    self.menu2 = nil
    audio.play("back", 0.5)
    g.done(nil)
  end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function other(self) return self.bout.f[3 - self.side] end

local function title(self, g)
  local foe = other(self).name
  local menu = g.menu
  local ctx = g.info.ctx or {}
  if menu == "attack" then
    return ctx.recov and "ATTACK THEIR RECOVERY" or "YOUR ATTACK"
  elseif menu == "defend" then
    return ctx.recov and I.f("%s ATTACKS YOUR RECOVERY", foe) or I.f("%s ATTACKS!", foe)
  elseif menu == "riposte" then
    return (ctx.chain or 1) > 1 and "COUNTER-PARRY! COUNTER-RIPOSTE" or "PARRIED! YOUR RIPOSTE"
  elseif menu == "parried" then
    return "PARRIED! YOUR ANSWER"
  else
    return "THE ATTACK FELL SHORT"
  end
end

-- What the opponent has chosen most, so far, in the menu facing this one.
local function scouting(self, g)
  local m = self.match
  local foe = 3 - self.side
  local facing = Tac.FACING[g.menu]
  local seen = facing and m.picks[foe][facing]
  if not seen then return facing and "SO FAR: NOTHING SEEN" or "" end
  local best, n, tot = nil, 0, 0
  for k, v in pairs(seen) do
    tot = tot + v
    if v > n then best, n = k, v end
  end
  return I.f("SO FAR: %s %d OF %d", I.tr(Tac.ACT[best].name), n, tot)
end

local BAND_COL = { close = "orange", lunge = "yellow", step = "text", long = "dim" }

function TP:drawMenu(g)
  local b = self.bout
  local ctx = g.info.ctx or {}
  local x, y, w = 4, 20, W - 8
  local n = #g.opts
  local cols, rows = grid(n)
  local ph = 15 + rows * 9 + 2
  core.color(C.ink, 0.6)
  gfx.rect(0, y - 1, W, ph + 2)
  gfx.panel(x, y, w, ph, C.panel, C.edge, 0.95)
  -- title, and the distance
  local tw = w - 10
  local dist
  if ctx.gap then
    local band, name = Tac.band(ctx.gap)
    dist = string.format("%.1f M · %s", ctx.gap, I.tr(name))
    local dw = gfx.textWidth(dist)
    gfx.text(dist, x + w - 5, y + 4, C[BAND_COL[band]] or C.text, "right")
    tw = tw - dw - 6
  end
  gfx.text(gfx.fit(title(self, g), tw), x + 5, y + 4, C.yellow)
  -- the choices
  local cw = floor((w - 8) / cols)
  for k, key in ipairs(g.opts) do
    local c, r = floor((k - 1) / rows), (k - 1) % rows
    local ox, oy = x + 4 + c * cw, y + 14 + r * 9
    local sel = (k == g.sel)
    if sel then
      core.color(C.panelL)
      gfx.rect(ox, oy - 1, cw - 2, 9)
      core.color(C.yellow)
      gfx.rect(ox, oy - 1, 1, 9)
    end
    gfx.text(Tac.ACT[key].name, ox + 5, oy + 1, sel and C.text or C.whiteS)
  end
  -- what the highlighted choice does, and what the opponent tends to do
  local by = 131
  core.color(C.ink)
  gfx.rect(0, by - 1, W, H - by + 1)
  gfx.panel(x, by, w, H - by - 1, C.panel, C.edge, 0.95)
  local key = g.opts[g.sel]
  gfx.para(Tac.ACT[key].desc, x + 5, by + 4, w - 10, C.text, 8)
  local hintW = 0
  if g.info.cancel then
    hintW = 40
    gfx.hints({ { "B", "BACK" } }, x + w - 5, by + 19, "right")
  end
  gfx.text(gfx.fit(scouting(self, g), w - 12 - hintW), x + 5, by + 21, C.dim)
end

-- The two choices of the exchange being fenced, over the fencers.
function TP:drawBanner()
  local b, m = self.bout, self.match
  local L = m.last
  if not L or b.call then return end
  local by = L.by
  local function label(i)
    local s = I.tr(Tac.ACT[L.act[i]].name)
    if i == by and settings.data.assist then s = s .. string.format(" %d%%", floor(L.chance * 100 + 0.5)) end
    return s
  end
  core.color(C.ink, 0.55)
  gfx.rect(0, 19, W, 11)
  gfx.text(label(1), 4, 21, C.redL, "left", true)
  gfx.text(label(2), W - 4, 21, C.greenL, "right", true)
end

-- Before the first touch: both fencers' ratings, side by side.
function TP:drawCard()
  local b, m = self.bout, self.match
  local x, y, w, h = 44, 104, W - 88, 52
  gfx.panel(x, y, w, h, C.panel, C.edge, 0.92)
  gfx.text("RATINGS", W / 2, y + 4, C.yellow, "center")
  local names = { "ATTACK", "DEFENCE", "TIMING", "FOOTWORK" }
  for k, key in ipairs(Tac.RATINGS) do
    local yy = y + 6 + k * 9
    gfx.text(names[k], W / 2, yy, C.dim, "center")
    for i = 1, 2 do
      local v = floor(m.sides[i].ratings[key] * 10 + 0.5)
      gfx.text(tostring(v), i == 1 and x + 8 or x + w - 8, yy, i == 1 and C.redL or C.greenL, i == 1 and "left" or "right")
    end
  end
end

function TP:drawExtra()
  local b, m = self.bout, self.match
  if (b.phase == "engarde" or b.phase == "intro") and b.score[1] + b.score[2] == 0 and b.period == 1 then
    self:drawCard()
  end
  if self.menu2 then
    self:drawMenu(self.menu2)
  elseif m.mode == "exchange" then
    self:drawBanner()
  elseif m.mode == "live" and b.phase == "fence" and not m.waiting and not self.paused then
    gfx.hints({ { "A", "ATTACK" } }, W - 4, 136, "right")
  end
end

-- For screenshots: open a menu as if that moment had come.
function TP:shot(menu)
  local m = self.match
  local b = self.bout
  local foe = 3 - self.side
  if menu == "attack" then
    m:startAttack(self.side)
  elseif menu == "defend" then
    m:startAttack(foe)
  elseif menu == "riposte" or menu == "parried" then
    local ri = (menu == "riposte") and self.side or foe
    m.picks[foe].parried = { remise = 2, cparry = 1 }
    m.picks[foe].riposte = { rdirect = 2 }
    m:afterParry(ri)
  end
end

return TP
