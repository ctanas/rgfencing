-- The showcase reel for the README (screenshots/showcase.gif): the game's
-- own scenes, driven by scripted presses as a player would, captured at
-- 30 fps into NAME_0001.png, NAME_0002.png... in the save directory.
-- ./build.sh shots turns the frames into the GIF.
--
--   love . --shot showcase --mode reel [--res 2] [--seg N]
--
-- --seg N renders only the N-th segment, to work on one at a time. Every
-- segment starts from its own random seed, so each is the same on every
-- run whatever comes before it. In the tactical and wheel clips the CPU's
-- choice (and the tactical bout's draw) is set rather than drawn, so they
-- always show the same exchange.

local core = require("src.core")
local gfx = require("src.gfx")
local input = require("src.input")
local settings = require("src.settings")
local Bout = require("src.bout")
local Play = require("src.play")
local AI = require("src.ai")
local Tac = require("src.tactics")

local C = core.C
local W, H = core.W, core.H

local R = {}

R.EVERY = 2          -- capture every 2nd frame of the game's 60: 30 fps

---------------------------------------------------------------------------
-- Scenes
---------------------------------------------------------------------------

-- A still of the arena behind the title cards.
local backdrop
local function arena()
  if not backdrop then
    backdrop = Bout.new({ left = { name = "" }, right = { name = "" }, skipIntro = true, silent = true,
      noClock = true, noHud = true })
    backdrop.f[1]:place(-1.7, "guard")
    backdrop.f[2]:place(1.7, "guard")
    backdrop.cam, backdrop.refX, backdrop.call = 0, 0, nil
  end
  return backdrop
end

-- A title card between the clips: what the next one shows.
local function card(app, title, l1, l2)
  local s = {}
  function s:update() end
  function s:draw()
    arena():draw()
    core.color(C.ink, 0.82)
    gfx.rect(0, 0, W, H)
    gfx.text(title, W / 2, 50, C.yellow, "center", true, 2)
    core.color(C.edge)
    gfx.rect(W / 2 - 60, 73, 120, 1)
    gfx.text(l1, W / 2, 82, C.text, "center", true)
    if l2 then gfx.text(l2, W / 2, 94, C.text, "center", true) end
  end
  app.set(s)
end

-- A bout against the CPU in mode "tactical" or "wheel", fast-forwarded to
-- the fencing at gap metres, with the CPU standing still (so the distance
-- stays the one chosen) and its next choice set to cpuPick.
local function versus(app, mode, opp, gap, cpuPick)
  local TP = require("src.tactical")
  local p = TP.versus(app, {
    opp = opp, level = 3, style = "balanced", mode = mode, touches = 15, title = TP.TITLE[mode], skipIntro = true,
  })
  app.set(p)
  local b, m = p.bout, p.match
  for _ = 1, 600 do
    b:update(1 / 60)
    if b.phase == "fence" then break end
  end
  m.cool = 99          -- the CPU moves only when the reel says
  local still = Tac.script()
  m.sides[2].live, b.f[2].ctl = still, still
  m.sides[2].brain.choose = function() return cpuPick end
  b.f[1]:place(-gap / 2, "guard")
  b.f[2]:place(gap / 2, "guard")
  b.cam, b.refX, b.call = 0, 0, nil
  for _ = 1, 10 do b:update(1 / 60) end
  return p
end

---------------------------------------------------------------------------
-- The reel: { dur = s, seed, start(app), events = { { t, button } or
-- { t, function } } } -- t in seconds from the segment's start
---------------------------------------------------------------------------

local ROLL = Tac.roll
local scene              -- the segment's scene, for its events

R.SEGMENTS = {
  -- the title screen; the cursor goes down to the three ways to fence
  { dur = 2.2, seed = 7, start = function(app) app.toTitle() end,
    events = { { 0.8, "down" }, { 1.4, "down" } } },

  { dur = 1.2, start = function(app)
    card(app, "ARCADE", "EVERY LUNGE AND PARRY ON THE BUTTONS", "THE REFEREE CALLS RIGHT OF WAY")
  end },

  -- two Elite fencers: attack, parry, riposte, and the referee's call
  { dur = 6.0, seed = 59, start = function(app)
    local a1, a2 = AI.new(4, "balanced"), AI.new(4, "counter")
    app.set(Play.new(app, {
      left = { name = "ROSSI", nation = "ITA", ctl = a1, spd = a1.spd },
      right = { name = "TANAKA", nation = "JPN", ctl = a2, spd = a2.spd },
      touches = 15, skipIntro = true, silent = true,
    }))
  end },

  { dur = 1.2, start = function(app)
    card(app, "TACTICAL", "MOVE LIVE, CHOOSE THE BLADE WORK", "FROM A MENU WHEN SOMEONE ATTACKS")
  end },

  -- you attack: a feint-disengage, and their parry is deceived
  { dur = 5.4, seed = 3, start = function(app)
    scene = versus(app, "tactical", { name = "FERRARI", nation = "ITA" }, 2.0, "parry")
    Tac.roll = function() return "hit" end
  end,
    events = { { 0.3, "a" }, { 0.8, "right" }, { 1.2, "down" }, { 1.7, "a" } } },

  { dur = 1.2, start = function(app)
    card(app, "WHEEL", "ROCK-PAPER-SCISSORS IN FIVE ACTIONS", "BY THE RULES OF FOIL")
  end },

  -- they move first: the bout stops for your answer, and the line wins
  { dur = 5.8, seed = 5, start = function(app)
    scene = versus(app, "wheel", { name = "NAGY", nation = "HUN" }, 2.0, "wdirect")
  end,
    events = { { 0.3, function() scene.match:startAttack(2) end }, { 0.9, "right" }, { 1.6, "a" } } },

  { dur = 1.2, start = function(app)
    card(app, "CAREER", "SIX COMPETITIONS, CLUB OPEN TO WORLDS", "POOLS, THEN THE TABLE OF 8")
  end },

  { dur = 1.5, seed = 1, start = function(app) require("src.career").shot(app, "pool", {}) end },
  { dur = 1.5, seed = 1, start = function(app) require("src.career").shot(app, "bracket", {}) end },
}

function R.start(app, shot)
  local d = settings.data
  d.side, d.assist, d.fps = 1, true, false
  local segs = R.SEGMENTS
  local only
  for k, a in ipairs(shot.args) do
    if a == "--seg" then only = tonumber(shot.args[k + 1]) end
  end
  local list = {}
  for k, s in ipairs(segs) do
    if not only or k == only then list[#list + 1] = s end
  end
  local total = 0
  for _, s in ipairs(list) do total = total + s.dur end
  shot.frames = math.floor(total * 60 + 0.5)

  -- frames from an earlier run would be taken for this one's
  local prefix = shot.name .. "_"
  for _, f in ipairs(love.filesystem.getDirectoryItems("")) do
    if f:sub(1, #prefix) == prefix and f:match("_%d+%.png$") then love.filesystem.remove(f) end
  end

  -- scripted presses in place of the pad
  local k, t, dt = 0, 0, 1 / 60
  input.nav = function(dir) return input.pressed[dir] end
  input.update = function()
    for _, a in ipairs(input.ACTIONS) do
      input.pressed[a], input.down[a] = false, false
    end
    if k == 0 or (k <= #list and t >= list[k].dur - 1e-6) then
      k, t = k + 1, 0
      local s = list[k]
      if not s then return end
      if s.seed then love.math.setRandomSeed(s.seed) end
      Tac.roll = ROLL
      s.start(app)
    end
    local s = list[k]
    if not s then return end
    for _, e in ipairs(s.events or {}) do
      if e[1] >= t and e[1] < t + dt then
        if type(e[2]) == "function" then
          e[2](app)
        else
          input.pressed[e[2]], input.down[e[2]] = true, true
        end
      end
    end
    t = t + dt
  end

  local count, n = 0, 0
  shot.film = function(canvas)
    count = count + 1
    if (count - 1) % R.EVERY ~= 0 then return end
    n = n + 1
    canvas:newImageData():encode("png", string.format("%s%04d.png", prefix, n))
  end
  shot.filmDone = function()
    print(string.format("%d frames at %d fps (%.1f s)", n, 60 / R.EVERY, n * R.EVERY / 60))
  end
  app.set({ update = function() end, draw = function() end })
end

return R
