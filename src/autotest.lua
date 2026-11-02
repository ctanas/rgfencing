-- Headless self-test: AI-vs-AI bouts at every level and style, run at the
-- fixed 120 Hz step with nothing drawn. Reports who wins and how the
-- referee scored the touches, so changes to the rules or the AI can be
-- checked without playing.
--
--   love . --autotest N        N bouts per pairing

local Bout = require("src.bout")
local AI = require("src.ai")
local Fencer = require("src.fencer")

local T = {}

local function runBout(r1, s1, r2, s2, touches, seed)
  love.math.setRandomSeed(seed)
  local a1, a2 = AI.new(r1, s1), AI.new(r2, s2)
  local b = Bout.new({
    left = { name = "L", ctl = a1, spd = a1.spd },
    right = { name = "R", ctl = a2, spd = a2.spd },
    touches = touches, skipIntro = true, silent = true,
  })
  local decisions = {}
  local lastDec
  local t = 0
  while not b.over and t < 900 do
    b.skip = (b.phase == "decision" or b.phase == "break" or b.phase == "priority") and b.pt > 0.6
    b:step(Bout.DT, true)
    t = t + Bout.DT
    if b.decision and b.decision ~= lastDec then
      lastDec = b.decision
      if b.decision.why == "corps" then
        local k = b.f[1].legs .. "/" .. tostring(b.f[1].offFlavor) .. " v " .. b.f[2].legs .. "/" .. tostring(b.f[2].offFlavor)
        T.corps[k] = (T.corps[k] or 0) + 1
      end
      decisions[#decisions + 1] = b.decision
    end
  end
  return b, decisions, t
end

T.corps = {}

function T.run(n)
  if n == "drills" then return require("src.drilltest").run() end
  if n == "tactics" then return require("src.tactest").run(T.extra) end
  if n == "wheel" then return require("src.wheeltest").run(T.extra) end
  n = tonumber(n) or 10
  local R = Fencer.measure()
  print(string.format("reach (pelvis to tip): guard %.2f  extension %.2f  lunge %.2f  flèche %.2f m",
    R.guardTip, R.ext, R.lunge, R.fleche))

  -- 1. level ladder: each level against each other, balanced style
  print("\nlevel vs level (balanced, bouts to 5): wins of the row level")
  local names = { "NOV", "CLUB", "NAT", "ELITE" }
  io.write("        ")
  for j = 1, 4 do io.write(string.format("%7s", names[j])) end
  io.write("\n")
  local seed = 1
  for i = 1, 4 do
    io.write(string.format("%-8s", names[i]))
    for j = 1, 4 do
      local w = 0
      for k = 1, n do
        seed = seed + 1
        -- alternate sides so neither side has an edge
        local left = (k % 2 == 0)
        local b = left and runBout(i, "balanced", j, "balanced", 5, seed) or runBout(j, "balanced", i, "balanced", 5, seed)
        local mine = left and 1 or 2
        if b.winner == mine then w = w + 1 end
      end
      io.write(string.format("%6d%%", math.floor(100 * w / n + 0.5)))
    end
    io.write("\n")
  end

  -- 2. how touches are scored, across styles at club and elite level
  for _, lvl in ipairs({ 2, 4 }) do
    local why, kinds, total = {}, {}, 0
    local acts = {}
    local tsum, halts, timeouts = 0, 0, 0
    local styleWins = {}
    for _, s in ipairs(AI.STYLE_ORDER) do styleWins[s] = 0 end
    local bouts = 0
    for si, s1 in ipairs(AI.STYLE_ORDER) do
      for sj, s2 in ipairs(AI.STYLE_ORDER) do
        for k = 1, math.max(1, math.floor(n / 3)) do
          seed = seed + 1
          local b, decs, t = runBout(lvl, s1, lvl, s2, 5, seed)
          bouts = bouts + 1
          tsum = tsum + t
          if not b.over then timeouts = timeouts + 1 end
          if b.winner then styleWins[b.winner == 1 and s1 or s2] = styleWins[b.winner == 1 and s1 or s2] + 1 end
          for side = 1, 2 do
            for k2, v in pairs(b.stats[side]) do
              if type(v) == "number" then acts[k2] = (acts[k2] or 0) + v end
            end
          end
          for _, d in ipairs(decs) do
            halts = halts + 1
            why[d.why or "?"] = (why[d.why or "?"] or 0) + 1
            if d.scorer then
              total = total + 1
              local key = d.kind or "?"
              kinds[key] = (kinds[key] or 0) + 1
            end
          end
        end
      end
    end
    print(string.format("\n%s, all style pairings: %d bouts, %.0f s simulated each, %d unfinished",
      AI.LEVELS[lvl].name, bouts, tsum / bouts, timeouts))
    local function show(title, t, of)
      local keys = {}
      for k in pairs(t) do keys[#keys + 1] = k end
      table.sort(keys, function(a, b) return t[a] > t[b] end)
      io.write("  " .. title .. ":")
      for _, k in ipairs(keys) do io.write(string.format("  %s %d%%", k, math.floor(100 * t[k] / of + 0.5))) end
      io.write("\n")
    end
    show("touches by action", kinds, math.max(1, total))
    show("halts by decision", why, math.max(1, halts))
    io.write(string.format("  per bout: attacks %.1f  short %.1f  blade actions %.1f  parries %.1f  beats %.1f  off-target %.1f\n",
      (acts.attacks or 0) / bouts, (acts.short or 0) / bouts, (acts.blades or 0) / bouts,
      (acts.parries or 0) / bouts, (acts.beats or 0) / bouts, (acts.offTarget or 0) / bouts))
    local ck = {}
    for k, v in pairs(T.corps) do ck[#ck + 1] = { k, v } end
    table.sort(ck, function(a, b) return a[2] > b[2] end)
    io.write("  corps:")
    for q = 1, math.min(4, #ck) do io.write("  " .. ck[q][1] .. " " .. ck[q][2]) end
    io.write("\n")
    T.corps = {}
    io.write("  wins by style:")
    for _, s in ipairs(AI.STYLE_ORDER) do io.write(string.format("  %s %d", s, styleWins[s])) end
    io.write("\n")
  end
end

return T
