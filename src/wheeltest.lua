-- Headless checks of the wheel bout (src/wheel.lua):
--
--   1. every pairing of the five actions, at every distance the exchange
--      can start from and at different speeds, is staged on the real
--      engine: does the referee give the touch the wheel says?
--   2. CPU-vs-CPU wheel bouts: they finish, and every decision after an
--      exchange is the wheel's.
--
--   love . --autotest wheel [--n N]
--
-- WHEEL_DEBUG=1 prints, for each bout exchange not as the wheel says, the
-- distance and footwork it started from and where it ended.

local Bout = require("src.bout")
local AI = require("src.ai")
local Tac = require("src.tactics")
local Wh = require("src.wheel")

local T = {}

local GAPS = { 1.45, 1.7, 1.95, 2.2, 2.45, 2.7, 2.95, 3.1 }
local SPEEDS = { { 1, 1 }, { 0.82, 1 }, { 1, 0.82 } }

-- Ties that the referee halts (simultaneous attacks); the others go back
-- to the footwork without a halt.
local HALTED_TIE = { wdirect = true, wfeint = true }

local function setup(gap, spd)
  local b = Bout.new({
    left = { name = "L", spd = spd[1] }, right = { name = "R", spd = spd[2] },
    touches = 99, skipIntro = true, silent = true, noClock = true,
  })
  local sides = {}
  for i = 1, 2 do
    local ai = AI.new(3, "balanced")
    sides[i] = { human = false, brain = Wh.brain(3, "balanced"), style = "balanced", level = 3,
      live = Tac.footworkOnly(ai) }
  end
  local m = Wh.match(b, sides, function() error("no human here") end)
  for _ = 1, 400 do
    b:update(1 / 60)
    if b.phase == "fence" then break end
  end
  b.f[1]:place(-gap / 2, "guard")
  b.f[2]:place(gap / 2, "guard")
  for _ = 1, 30 do b:update(1 / 60) end
  m.cool = 99          -- no exchanges of their own
  return b, m
end

-- Run until the referee decides or the fencers are back to footwork.
local function runUntil(b, m, maxT)
  local t = 0
  while t < maxT do
    m:frame(1 / 60, function(dt) b:update(dt) end)
    t = t + 1 / 60
    if b.phase == "decision" then
      local d = b.decision
      return { ev = "decision", scorer = d.scorer, why = d.why, line1 = d.line1, line3 = d.line3 }
    end
    if m.mode == "live" and b.phase == "fence" then
      return { ev = "live", lights = (b.lights[1] or b.lights[2]) and true or false }
    end
  end
  return { ev = "timeout" }
end

local function expected(k1, k2, r)
  local res = Wh.result(k1, k2)
  if res ~= 0 then
    local w = res > 0 and 1 or 2
    return r.ev == "decision" and r.scorer == w
  end
  if HALTED_TIE[k1] then return r.ev == "decision" and not r.scorer and r.why == "simultaneous" end
  return r.ev == "live" and not r.lights
end

local function describe(r)
  if r.ev == "decision" then
    return string.format("decision scorer=%s why=%s (%s / %s)", tostring(r.scorer), tostring(r.why),
      tostring(r.line1), tostring(r.line3))
  end
  return r.ev .. (r.lights and " (lights)" or "")
end

local function stagingTest()
  print("1. staging: action x action x distance x speeds")
  local total, bad, fails, calls = 0, 0, {}, {}
  for _, k1 in ipairs(Wh.KEYS) do
    for _, k2 in ipairs(Wh.KEYS) do
      for _, gap in ipairs(GAPS) do
        for si, spd in ipairs(SPEEDS) do
          local b, m = setup(gap, spd)
          m:resolve(1, k1, k2)
          local r = runUntil(b, m, 8)
          total = total + 1
          if not expected(k1, k2, r) then
            bad = bad + 1
            fails[#fails + 1] = string.format("  %-7s v %-7s gap %.2f spd %.2f/%.2f -> %s", k1, k2, gap,
              spd[1], spd[2], describe(r))
          end
          -- what the referee says, from lunge distance at equal speeds
          if si == 1 and gap == 1.95 then
            calls[#calls + 1] = string.format("  %-7s v %-7s %s", k1, k2, describe(r))
          end
        end
      end
    end
  end
  print(string.format("   %d staged, %d not as the wheel says", total, bad))
  for _, f in ipairs(fails) do print(f) end
  print("   the referee's calls at 1.95 m:")
  for _, c in ipairs(calls) do print(c) end
  return bad
end

-- Whole bouts, CPU against CPU.
local function boutTest(n)
  print(string.format("2. CPU-vs-CPU wheel bouts to 5 (%d per pairing)", n))
  local styles = AI.STYLE_ORDER
  for _, lvl in ipairs({ 2, 4 }) do
    local why, kinds, picks = {}, {}, {}
    local bouts, unfinished, tsum, exch, checked, wrong = 0, 0, 0, 0, 0, 0
    local mism = {}
    for _, s1 in ipairs(styles) do
      for _, s2 in ipairs(styles) do
        for _ = 1, n do
          love.math.setRandomSeed(2000 + bouts)
          bouts = bouts + 1
          local a1, a2 = AI.new(lvl, s1), AI.new(lvl, s2)
          for _, ai in ipairs({ a1, a2 }) do
            local S = {}
            for key, v in pairs(ai.S) do S[key] = v end
            S.attack, S.fleche, S.beat, S.line, S.counter, S.remise = 0, 0, 0, 0, 0, 0
            ai.S = S
          end
          local c1, c2 = Tac.footworkOnly(a1), Tac.footworkOnly(a2)
          local b = Bout.new({
            left = { name = "L", ctl = c1, spd = a1.spd }, right = { name = "R", ctl = c2, spd = a2.spd },
            touches = 5, skipIntro = true, silent = true,
          })
          local m = Wh.match(b, {
            { human = false, brain = Wh.brain(lvl, s1), style = s1, level = lvl, live = c1 },
            { human = false, brain = Wh.brain(lvl, s2), style = s2, level = lvl, live = c2 },
          }, function() error("no human") end)
          local t, lastDec, lastEx, pending, wasEx = 0, nil, nil, nil, false
          local function miss(L, got)
            wrong = wrong + 1
            local key = string.format("%s v %s -> %s", L.act[1], L.act[2], got)
            if os.getenv("WHEEL_DEBUG") then
              local f1, f2 = b.f[1], b.f[2]
              print(string.format("MISS %s | start %s | now gap %.2f legs %s/%s lights %s/%s stats short %s/%s",
                key, L.dbg or "", f2.x - f1.x, f1.legs, f2.legs, tostring(b.lights[1]), tostring(b.lights[2]),
                tostring(b.stats[1].short), tostring(b.stats[2].short)))
            end
            mism[key] = (mism[key] or 0) + 1
          end
          while not b.over and t < 900 do
            if b.phase == "decision" or b.phase == "break" or b.phase == "priority" then
              b.skip = b.pt > 0.6
            end
            m:frame(1 / 60, function(dt) b:update(dt) end)
            t = t + 1 / 60
            if m.last and m.last ~= lastEx then
              lastEx = m.last
              pending = m.last
              if os.getenv("WHEEL_DEBUG") then
                local f1, f2 = b.f[1], b.f[2]
                pending.dbg = string.format("gap %.2f x %.2f/%.2f legs %s%s/%s%s spd %.2f/%.2f", f2.x - f1.x, f1.x, f2.x,
                  f1.legs, f1.legs == "step" and (f1.sdir > 0 and "+" or "-") or "", f2.legs,
                  f2.legs == "step" and (f2.sdir > 0 and "+" or "-") or "", f1.spd, f2.spd)
              end
              exch = exch + 1
              for _, key in ipairs(m.last.act) do picks[key] = (picks[key] or 0) + 1 end
            end
            -- an exchange over without a halt: only right for the quiet ties
            if wasEx and m.mode == "live" and b.phase == "fence" and pending then
              checked = checked + 1
              if pending.winner or HALTED_TIE[pending.act[1]] then miss(pending, "no halt") end
              pending = nil
            end
            wasEx = (m.mode == "exchange")
            if b.decision and b.decision ~= lastDec then
              lastDec = b.decision
              local d = b.decision
              why[d.why or "?"] = (why[d.why or "?"] or 0) + 1
              if d.scorer then kinds[d.kind or "?"] = (kinds[d.kind or "?"] or 0) + 1 end
              if pending and d.why ~= "time" then
                checked = checked + 1
                local ok
                if pending.winner then
                  ok = d.scorer == pending.winner
                else
                  ok = HALTED_TIE[pending.act[1]] and not d.scorer
                end
                if not ok then miss(pending, string.format("%s %s", tostring(d.scorer), tostring(d.why))) end
              end
              pending = nil
            end
          end
          tsum = tsum + t
          if not b.over then unfinished = unfinished + 1 end
        end
      end
    end
    print(string.format("   %s: %d bouts, %.0f s each, %d unfinished, %.1f exchanges per bout",
      AI.LEVELS[lvl].name, bouts, tsum / bouts, unfinished, exch / bouts))
    local function show(title, tab)
      local keys, of = {}, 0
      for k, v in pairs(tab) do keys[#keys + 1] = k; of = of + v end
      table.sort(keys, function(x, y) return tab[x] > tab[y] end)
      io.write("     " .. title .. ":")
      for _, k in ipairs(keys) do io.write(string.format("  %s %d%%", k, math.floor(100 * tab[k] / math.max(1, of) + 0.5))) end
      io.write("\n")
    end
    show("touches", kinds)
    show("halts", why)
    show("choices", picks)
    print(string.format("     exchanges not as the wheel says: %d of %d", wrong, checked))
    local mk = {}
    for k, v in pairs(mism) do mk[#mk + 1] = { k, v } end
    table.sort(mk, function(x, y) return x[2] > y[2] end)
    for q = 1, math.min(8, #mk) do print(string.format("       %3d  %s", mk[q][2], mk[q][1])) end
  end
end

function T.run(n)
  n = tonumber(n) or 2
  local bad = stagingTest()
  boutTest(n)
  print(bad == 0 and "\nevery pairing staged as the wheel says" or string.format("\n%d pairings not staged as the wheel says", bad))
end

return T
