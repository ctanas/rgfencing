-- Headless checks of the tactical bout (src/tactics.lua):
--
--   1. every attack against every defence, for every outcome the model can
--      draw, is staged on the real engine: does the referee see what was
--      drawn? Same for every riposte against every answer.
--   2. CPU-vs-CPU tactical bouts: they finish, and the touches come from
--      a believable mix of actions.
--
--   love . --autotest tactics [N]

local Bout = require("src.bout")
local AI = require("src.ai")
local Tac = require("src.tactics")

local T = {}

local GAPS = { close = 1.55, lunge = 2.0, step = 2.45, long = 2.9 }
local function bandFor(a)
  if a == "step" then return "step" end
  if a == "fleche" then return "step" end
  return "lunge"
end

local function newBout()
  local b = Bout.new({
    left = { name = "L" }, right = { name = "R" },
    touches = 99, skipIntro = true, silent = true, noClock = true,
  })
  return b
end

local function freshMatch(b)
  local sides = {}
  for i = 1, 2 do
    local ai = AI.new(3, "balanced")
    sides[i] = { human = false, ratings = Tac.cpuRatings(3, "balanced"), brain = Tac.brain(3, "balanced"),
      style = "balanced", level = 3, live = Tac.footworkOnly(ai) }
  end
  return Tac.match(b, sides, function() error("no human here") end)
end

-- Run the bout until the director stops, the referee decides, or time runs out.
local function runUntil(b, m, maxT)
  local got
  m.afterParry = function(self, by) got = { ev = "parry", by = by } end
  m.afterShort = function(self, ai) got = { ev = "short", by = ai } end
  local t = 0
  while t < maxT do
    m:frame(1 / 60, function(dt) b:update(dt) end)
    t = t + 1 / 60
    if got then return got end
    if b.phase == "decision" then
      local d = b.decision
      return { ev = "decision", scorer = d.scorer, why = d.why, kind = d.kind, lights = d.lights }
    end
    if m.mode == "live" and b.phase == "fence" then return { ev = "live" } end
  end
  return { ev = "timeout" }
end

local function setup(gap, ai)
  local b = newBout()
  local m = freshMatch(b)
  -- through EN GARDE / PRÊTS / ALLEZ
  for _ = 1, 400 do
    b:update(1 / 60)
    if b.phase == "fence" then break end
  end
  b.f[1]:place(-gap / 2, "guard")
  b.f[2]:place(gap / 2, "guard")
  for _ = 1, 30 do b:update(1 / 60) end
  m.cool = 99          -- no CPU attacks of their own
  return b, m
end

local function attackMatches(res, r, ai)
  local di = 3 - ai
  if res == "hit" or res == "double" then return r.ev == "decision" and r.scorer == ai end
  if res == "off" then return r.ev == "decision" and not r.scorer and (r.why == "off" or r.why == "priorityoff") end
  if res == "parried" then return r.ev == "parry" and r.by == di end
  if res == "short" then
    return r.ev == "short" or (r.ev == "decision" and not r.scorer and (r.why == "pass" or r.why == "corps"))
  end
  if res == "counter" then return r.ev == "decision" and r.scorer == di end
  if res == "out" then return r.ev == "decision" and r.scorer == ai and r.why == "out" end
  if res == "corps" then return r.ev == "decision" and not r.scorer and (r.why == "corps" or r.why == "pass") end
  return false
end

local function describe(r)
  if r.ev == "decision" then
    return string.format("decision scorer=%s why=%s kind=%s lights=%s/%s", tostring(r.scorer), tostring(r.why),
      tostring(r.kind), tostring(r.lights[1]), tostring(r.lights[2]))
  end
  return r.ev .. (r.by and (" by " .. r.by) or "")
end

local function outcomes(o)
  local t = {}
  for k, p in pairs(o) do if p > 0.001 then t[#t + 1] = k end end
  table.sort(t)
  return t
end

local function stagingTest()
  local R = { A = Tac.cpuRatings(3, "balanced"), D = Tac.cpuRatings(3, "balanced") }
  local total, bad = 0, 0
  local fails = {}
  print("1. staging: attack x defence x outcome, both sides of the piste")
  for _, a in ipairs(Tac.MENU.attack) do
    for _, d in ipairs(Tac.MENU.defend) do
      for _, band in ipairs({ bandFor(a), "close" }) do
        local gap = GAPS[band]
        local o = Tac.attackOdds(a, d, { A = R.A, D = R.D, band = band, gap = gap, room = 5 })
        for _, res in ipairs(outcomes(o)) do
          if res ~= "out" then
            for ai = 1, 2 do
              local b, m = setup(gap, ai)
              local ctx = m:attackCtx(ai)
              m:stageAttack(ai, a, d, res, ctx)
              local r = runUntil(b, m, 6)
              total = total + 1
              if not attackMatches(res, r, ai) then
                bad = bad + 1
                fails[#fails + 1] = string.format("  %-9s v %-7s %-5s %-7s side %d -> %s", a, d, band, res, ai, describe(r))
              end
            end
          end
        end
      end
    end
  end
  -- the back line: a retreat with no room left
  for _, a in ipairs({ "direct", "step" }) do
    local b, m = setup(2.0, 1)
    b.f[1]:place(4.2, "guard")
    b.f[2]:place(6.2, "guard")
    for _ = 1, 10 do b:update(1 / 60) end
    local ctx = m:attackCtx(1)
    m:stageAttack(1, a, "retreat", "out", ctx)
    local r = runUntil(b, m, 6)
    total = total + 1
    if not attackMatches("out", r, 1) then
      bad = bad + 1
      fails[#fails + 1] = string.format("  %-9s v retreat out -> %s", a, describe(r))
    end
  end
  print(string.format("   %d staged, %d not as drawn", total, bad))
  for _, f in ipairs(fails) do print(f) end

  -- ripostes: parry an attack first, then stage the riposte
  print("2. staging: riposte x answer x outcome")
  local rt, rb = 0, 0
  fails = {}
  local function riposteMatches(res, r, ri)
    local pi = 3 - ri
    if res == "hit" then return r.ev == "decision" and r.scorer == ri end
    if res == "off" then return r.ev == "decision" and not r.scorer end
    if res == "parried" then return r.ev == "parry" and r.by == pi end
    if res == "short" then return r.ev == "live" end
    if res == "remise" then return r.ev == "decision" and r.scorer == pi end
    return false
  end
  for _, att in ipairs({ "direct", "fleche" }) do
    for _, rr in ipairs(Tac.MENU.riposte) do
      for _, c in ipairs(Tac.MENU.parried) do
        local ctx0 = { R = R.A, P = R.D, chain = 1, fleche = (att == "fleche") or nil }
        local o = Tac.riposteOdds(rr, c, ctx0)
        for _, res in ipairs(outcomes(o)) do
          for ai = 1, 2 do
            local b, m = setup(att == "fleche" and 2.45 or 2.0, ai)
            m:stageAttack(ai, att, "parry", "parried", m:attackCtx(ai))
            local r0 = runUntil(b, m, 4)
            rt = rt + 1
            if r0.ev ~= "parry" then
              rb = rb + 1
              fails[#fails + 1] = "  (the parry before the riposte did not happen: " .. describe(r0) .. ")"
            else
              local ri = 3 - ai
              local ctx = { ri = ri, pi = ai, chain = 1, R = R.A, P = R.D, fleche = b.f[ai].legs == "fleche" or nil }
              m.chain = 1
              m:stageRiposte(ri, rr, c, res, ctx)
              local r = runUntil(b, m, 5)
              if not riposteMatches(res, r, ri) then
                rb = rb + 1
                fails[#fails + 1] = string.format("  after %-6s %-9s v %-7s %-7s side %d -> %s", att, rr, c, res, ri, describe(r))
              end
            end
          end
        end
      end
    end
  end
  print(string.format("   %d staged, %d not as drawn", rt, rb))
  for _, f in ipairs(fails) do print(f) end
  return bad + rb
end

-- Whole bouts, CPU against CPU.
local function boutTest(n)
  print(string.format("3. CPU-vs-CPU tactical bouts to 5 (%d per pairing)", n))
  local styles = AI.STYLE_ORDER
  for _, lvl in ipairs({ 2, 4 }) do
    local kinds, why, total, halts, tsum, unfinished, bouts, exch = {}, {}, 0, 0, 0, 0, 0, 0
    local mism, nm = {}, 0
    local picks = {}
    for _, s1 in ipairs(styles) do
      for _, s2 in ipairs(styles) do
        for k = 1, n do
          love.math.setRandomSeed(1000 + bouts)
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
          local m = Tac.match(b, {
            { human = false, ratings = Tac.cpuRatings(lvl, s1), brain = Tac.brain(lvl, s1), style = s1, level = lvl, live = c1 },
            { human = false, ratings = Tac.cpuRatings(lvl, s2), brain = Tac.brain(lvl, s2), style = s2, level = lvl, live = c2 },
          }, function() error("no human") end)
          local t, lastDec, lastEx = 0, nil, nil
          while not b.over and t < 900 do
            if b.phase == "decision" or b.phase == "break" or b.phase == "priority" then
              b.skip = b.pt > 0.6
            end
            m:frame(1 / 60, function(dt) b:update(dt) end)
            t = t + 1 / 60
            if m.last and m.last ~= lastEx then
              lastEx = m.last
              exch = exch + 1
              for side, key in pairs(m.last.act) do picks[key] = (picks[key] or 0) + 1 end
            end
            if b.decision and b.decision ~= lastDec then
              lastDec = b.decision
              halts = halts + 1
              -- did the referee see what was drawn?
              local L = m.last
              if L and b.decision.why ~= "time" then
                local d = b.decision
                local ok
                if L.stage == "attack" then
                  ok = attackMatches(L.res, { ev = "decision", scorer = d.scorer, why = d.why }, L.by)
                else
                  local ri = L.by
                  ok = (L.res == "hit" and d.scorer == ri) or (L.res == "off" and not d.scorer)
                    or (L.res == "remise" and d.scorer == 3 - ri)
                end
                if not ok then
                  local key = string.format("%s %s/%s %s -> %s %s", L.stage, L.act[L.by], L.act[3 - L.by], L.res,
                    d.scorer == L.by and "by" or (d.scorer and "against" or "none"), d.why)
                  mism[key] = (mism[key] or 0) + 1
                  nm = nm + 1
                end
              end
              why[b.decision.why or "?"] = (why[b.decision.why or "?"] or 0) + 1
              if b.decision.scorer then
                total = total + 1
                kinds[b.decision.kind or "?"] = (kinds[b.decision.kind or "?"] or 0) + 1
              end
            end
          end
          tsum = tsum + t
          if not b.over then unfinished = unfinished + 1 end
        end
      end
    end
    print(string.format("   %s: %d bouts, %.0f s each, %d unfinished, %.1f exchanges per bout",
      AI.LEVELS[lvl].name, bouts, tsum / bouts, unfinished, exch / bouts))
    local function show(title, t, of)
      local keys = {}
      for k in pairs(t) do keys[#keys + 1] = k end
      table.sort(keys, function(x, y) return t[x] > t[y] end)
      io.write("     " .. title .. ":")
      for _, k in ipairs(keys) do io.write(string.format("  %s %d%%", k, math.floor(100 * t[k] / of + 0.5))) end
      io.write("\n")
    end
    show("touches", kinds, math.max(1, total))
    show("halts", why, math.max(1, halts))
    local pk = 0
    for _, v in pairs(picks) do pk = pk + v end
    show("choices", picks, math.max(1, pk))
    print(string.format("     decisions not as drawn: %d of %d", nm, halts))
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
  print(bad == 0 and "\nall exchanges staged as drawn" or string.format("\n%d exchanges not staged as drawn", bad))
end

return T
