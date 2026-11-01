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

-- Scripted button timelines for the left fencer: { from, to, button }.
local FILMS = {
  advance = { dur = 2.2, { 0.1, 1.15, "right" }, { 1.45, 2.0, "left" } },
  lunge = { dur = 1.6, { 0.15, 0.75, "a" } },
  parry = { dur = 1.6, right = "lunge", { 0.42, 0.44, "b" }, { 0.70, 0.72, "x" }, { 0.72, 1.0, "x" } },
  fleche = { dur = 1.4, { 0.1, 0.12, "y" } },
  jump = { dur = 1.4, { 0.1, 0.12, "r1" }, { 0.7, 0.72, "l1" } },
  idle = { dur = 1.6 },
  walk = { dur = 2.6, walk = true },
  hit = { dur = 1.2, right = "lunge" },
  bout = { dur = 6, ai = true },
}

local function puppet(tl)
  local Ctl = require("src.controller")
  local p = { pad = Ctl.newPad(), t = 0 }
  function p:get(b, i, h)
    self.t = self.t + h
    for _, k in ipairs(Ctl.BUTTONS) do
      self.pad.pressed[k], self.pad.down[k] = false, false
    end
    for _, e in ipairs(tl) do
      if self.t >= e[1] and self.t < e[2] then
        self.pad.down[e[3]] = true
        if self.t - h < e[1] then self.pad.pressed[e[3]] = true end
      end
    end
    return self.pad
  end
  return p
end

-- Film: run a scripted action and capture the area around the left
-- fencer every few frames into a contact sheet and single frames.
local function film(app, shot, act)
  local tl = FILMS[act] or FILMS.idle
  local args = shot.args
  local right = nil
  if tl.right then
    right = puppet({ { 0.2, 0.8, "a" } })
  end
  local left = puppet(tl)
  if tl.ai then
    left, right = AI.new(4, "balanced"), AI.new(4, "counter")
  end
  local n1, n2 = tl.ai and "ROSSI" or "LEFT", tl.ai and "TANAKA" or "RIGHT"
  local b = Bout.new({
    left = { name = n1, nation = tl.ai and "ITA", ctl = left, spd = left.spd },
    right = { name = n2, nation = tl.ai and "JPN", ctl = right, spd = right and right.spd },
    skipIntro = true, silent = true, noClock = true, noHud = not tl.ai, endless = true,
  })
  b.f[1]:place(-1.1, "guard")
  b.f[2]:place(1.1, "guard")
  if act == "advance" or act == "fleche" or act == "jump" or act == "idle" then b.f[2]:place(3.2, "guard") end
  b.cam, b.lockCam, b.refX = 0, true, 6
  b:setPhase("fence")
  b.call = nil
  if tl.walk then
    b.f[1]:place(-0.6, "guard")
    b.f[1]:walkTo(core.ENGARDE * -1 - 0.4, "guard")
    b.phase = "reset"
  end
  local full = tl.ai or argValue(args, "--full") ~= nil
  if tl.ai then
    b.lockCam = false
    b:setPhase("engarde")
  end
  local frames, every, t = {}, tonumber(argValue(args, "--every")) or 4, 0
  local skip = math.floor((tonumber(argValue(args, "--start")) or 0) * 60)
  local scene = { b = b }
  function scene:update(dt)
    t = t + dt
    self.b:update(dt)
    self.b.call = nil
  end
  function scene:draw() self.b:draw() end
  local dur = tonumber(argValue(args, "--dur")) or tl.dur
  shot.frames = skip + math.floor(dur * 60) + 2
  local count = 0
  local S = core.S
  local fw, fh = full and core.CW or math.floor(112 * S), full and core.CH or math.floor(72 * S)
  shot.film = function(canvas)
    count = count + 1
    if count <= skip or (count - skip) % every ~= 1 then return end
    if full then
      frames[#frames + 1] = canvas:newImageData()
    else
      local x0 = math.floor((120 + math.floor((-1.1 - 1.0) * core.PPM) - 4) * S)
      frames[#frames + 1] = canvas:newImageData(nil, 1, math.max(0, x0), math.floor(64 * S), fw, fh)
    end
  end
  shot.filmDone = function()
    local cols = 6
    local rows = math.ceil(#frames / cols)
    local sheet = love.image.newImageData(cols * fw, rows * fh)
    for k, fr in ipairs(frames) do
      local cx, cy = ((k - 1) % cols) * fw, math.floor((k - 1) / cols) * fh
      sheet:paste(fr, cx, cy, 0, 0, fw, fh)
      fr:encode("png", string.format("%s_%03d.png", shot.name, k))
    end
    sheet:encode("png", shot.name .. ".png")
  end
  app.set(scene)
end

function S.start(app, shot)
  local args = shot.args
  local mode = shot.mode
  if argValue(args, "--side") then require("src.settings").data.side = tonumber(argValue(args, "--side")) end
  if mode == "film" then return film(app, shot, argValue(args, "--act") or "idle") end
  if mode == "bout" or mode == "demo" then
    local lvl = tonumber(argValue(args, "--level")) or 3
    local a1, a2 = AI.new(lvl, "balanced"), AI.new(lvl, "attacker")
    local play = Play.new(app, {
      left = { name = "ROSSI", nation = "ITA", ctl = a1, spd = a1.spd },
      right = { name = "DUBOIS", nation = "FRA", ctl = a2, spd = a2.spd },
      touches = tonumber(argValue(args, "--touches")) or 15, skipIntro = mode == "bout", silent = true,
    })
    if argValue(args, "--human") then
      play.bout.f[1].name, play.bout.f[1].nation = require("src.profile").fencer()
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
  elseif mode == "profile" then
    require("src.profiles_ui").screen(app)
  elseif mode == "welcome" then
    require("src.profiles_ui").firstRun(app, function() end)
  elseif mode == "keyboard" then
    local U = require("src.profiles_ui")
    local kb = U.keyboard(app, { name = "ȘTEFĂNESCU", onDone = function() end, onCancel = function() end })
    kb.page, kb.row, kb.col = 2, 5, 1
    app.set(kb)
  elseif mode == "nations" then
    app.set(require("src.profiles_ui").nations(app, { code = "ROU", onDone = function() end, onCancel = function() end }))
  elseif mode == "tactical" then
    -- --menu attack|defend|riposte|parried, or --exchange A,D,RESULT
    -- (staged, captured --time S later); --gap G between the fencers
    require("src.tactical").start(app)
    local p = app.current()
    local b, m = p.bout, p.match
    if argValue(args, "--intro") then return end
    for _ = 1, 900 do
      b:update(1 / 60)
      if b.phase == "fence" then break end
    end
    local gap = tonumber(argValue(args, "--gap")) or 2.1
    b.f[1]:place(-gap / 2 - 0.3, "guard")
    b.f[2]:place(gap / 2 - 0.3, "guard")
    b.cam = -0.3
    for _ = 1, 20 do b:update(1 / 60) end
    m.cool = 99
    local ex = argValue(args, "--exchange")
    if ex then
      local a, d, res = ex:match("^(%w+),(%w+),(%w+)$")
      local Tac = require("src.tactics")
      local ctx = m:attackCtx(1)
      local o = Tac.attackOdds(a, d, ctx)
      m.last = { stage = "attack", by = 1, act = { a, d }, chance = Tac.landChance(o), res = res }
      m:stageAttack(1, a, d, res, ctx)
      b.call = nil
    else
      p:shot(argValue(args, "--menu") or "attack")
      local sel = tonumber(argValue(args, "--sel"))
      if sel and p.menu2 then p.menu2.sel = sel end
    end
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
