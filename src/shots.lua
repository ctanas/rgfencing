-- Screenshot scenes for development and the README:
--
--   love . --shot NAME --mode M [--time S] [--seed N] [...]
--
--   title | options | quick | howto [--page N] | training | career
--   bout [--level L]      AI vs AI bout, captured after S seconds
--   pose --pose A,B [--gap G]   two fencers frozen in poses
--        poses: guard low lunge extend parry parrylow fleche salute stand victory
--   pool | bracket        career screens with a simulated event

local core = require("src.core")
local Bout = require("src.bout")
local Play = require("src.play")
local AI = require("src.ai")
local Fencer = require("src.fencer")

local S = {}

local function argValue(args, name)
  for i, a in ipairs(args) do if a == name then return args[i + 1] end end
  return nil
end

local function posed(app, pa, pb, gap)
  local b = Bout.new({
    left = { name = "LEFT" }, right = { name = "RIGHT" }, skipIntro = true, silent = true, noClock = true,
  })
  b.phase = "posed"
  local m = gap / 2
  local scene = { b = b }
  local names = { pa, pb }
  for i = 1, 2 do
    local f = b.f[i]
    f:place((i == 1 and -1 or 1) * m, "guard")
    local p = names[i]
    f.holdA, f.holdX = true, true
    if p == "low" then f.line = "low"
    elseif p == "lunge" then f:run("lunge", "high")
    elseif p == "lungelow" then f:run("lunge", "low")
    elseif p == "extend" then f:run("extend", "high")
    elseif p == "parry" then f:run("blade", "high")
    elseif p == "parrylow" then f:run("blade", "low")
    elseif p == "fleche" then f:run("fleche", "high")
    elseif p == "stand" then f:place(f.x, "stand")
    elseif p == "salute" then f:place(f.x, "stand"); f:setPose(Fencer.ARM.salute1, Fencer.BACK.stand)
    elseif p == "victory" then f:place(f.x, "stand"); f:setPose(Fencer.ARM.victory, Fencer.BACK.victory, "stand")
    end
    f.posing = p
  end
  b.cam = 0
  b.refX = 0
  b.call = nil
  function scene:update(dt)
    for i = 1, 2 do
      local f = self.b.f[i]
      local p = f.posing
      -- freeze actions at their most telling moment
      if p == "parry" or p == "parrylow" then
        if f.arm == "parry" and f.pphase == "active" then f.at = 0 end
      elseif p == "fleche" then
        if f.legs == "fleche" and f.fphase == "run" and f.lt > 0.12 then f.lt = 0.12 end
      end
      f:update(dt)
      f.events = {}
    end
  end
  function scene:draw() self.b:draw() end
  app.set(scene)
end

function S.start(app, shot)
  local args = shot.args
  local mode = shot.mode
  if mode == "bout" or mode == "demo" then
    local lvl = tonumber(argValue(args, "--level")) or 3
    local a1, a2 = AI.new(lvl, "balanced"), AI.new(lvl, "attacker")
    local play = Play.new(app, {
      left = { name = "ROSSI", nation = "ITA", ctl = a1, spd = a1.spd },
      right = { name = "DUBOIS", nation = "FRA", ctl = a2, spd = a2.spd },
      touches = tonumber(argValue(args, "--touches")) or 15, skipIntro = mode == "bout", silent = true,
    })
    if argValue(args, "--human") then
      play.bout.f[1].name = "YOU"
      play.bout.f[1].human = true
    end
    -- --until PHASE[:n]: run until the n-th time the bout enters PHASE, then freeze
    local untilArg = argValue(args, "--until")
    if untilArg then
      local phase, n = untilArg:match("^(%a+):?(%d*)$")
      n = tonumber(n) or 1
      local hold = tonumber(argValue(args, "--hold")) or 0.4
      local seen, last = 0, nil
      local frozen = false
      local upd = play.update
      function play:update(dt)
        if frozen then return end
        local b = self.bout
        for _ = 1, 600 do
          upd(self, dt)
          if b.phase ~= last then
            last = b.phase
            if b.phase == phase then seen = seen + 1 end
          end
          if seen >= n and b.phase == phase and b.pt >= hold then frozen = true; return end
          if seen < n or b.phase ~= phase then
            -- fast-forward
          else
            return
          end
        end
      end
    end
    app.set(play)
  elseif mode == "pose" then
    local p = argValue(args, "--pose") or "guard,guard"
    local pa, pb = p:match("^(%w+),(%w+)$")
    posed(app, pa or "guard", pb or "guard", tonumber(argValue(args, "--gap")) or 3.0)
  elseif mode == "howto" then
    local Help = require("src.help")
    local s = Help.scene(app, function() end)
    s.page = tonumber(argValue(args, "--page")) or 1
    app.set(s)
  elseif mode == "training" then
    require("src.training").menu(app)
  elseif mode == "drill" then
    require("src.training").start(app, tonumber(argValue(args, "--drill")) or 1, argValue(args, "--go") ~= nil)
  elseif mode == "career" or mode == "pool" or mode == "bracket" or mode == "event" then
    require("src.career").shot(app, mode, args)
  else
    app.toTitle()
    local t = app.current and app.current()
    if t and t.shot then t:shot(mode, args) end
  end
end

return S
