-- Career: a ladder of six competitions. Each one is run like a real foil
-- event: two pools of six (bouts to 5, FIE bout order), a ranking by
-- victories/matches, indicator (touches scored - received) and touches
-- scored, then a direct-elimination table of 8 (bouts to 10 or 15).
-- You fence your own bouts; the others are simulated from the fencers'
-- ratings. A medal (top 3) unlocks the next competition.

local core = require("src.core")
local gfx = require("src.gfx")
local input = require("src.input")
local audio = require("src.audio")
local settings = require("src.settings")
local Play = require("src.play")
local AI = require("src.ai")
local Ctl = require("src.controller")
local Menu = require("src.menu")
local Names = require("src.names")
local Profile = require("src.profile")
local Nations = require("src.nations")

local floor, max, min, abs, exp = math.floor, math.max, math.min, math.abs, math.exp
local C = core.C
local W, H = core.W, core.H

local CA = {}

CA.EVENTS = {
  { name = "CLUB OPEN", lo = 1.0, hi = 1.8, de = 10 },
  { name = "REGIONAL CIRCUIT", lo = 1.4, hi = 2.4, de = 10 },
  { name = "NATIONAL CHAMPIONSHIPS", lo = 1.9, hi = 2.9, de = 15 },
  { name = "SATELLITE CUP", lo = 2.4, hi = 3.4, de = 15 },
  { name = "WORLD CUP", lo = 2.9, hi = 3.9, de = 15 },
  { name = "WORLD CHAMPIONSHIPS", lo = 3.3, hi = 4.4, de = 15 },
}

-- FIE order of bouts for a pool of 6.
CA.ORDER6 = {
  { 1, 2 }, { 4, 5 }, { 2, 3 }, { 5, 6 }, { 3, 1 }, { 6, 4 }, { 2, 5 }, { 1, 4 },
  { 5, 3 }, { 1, 6 }, { 4, 2 }, { 3, 6 }, { 5, 1 }, { 3, 4 }, { 6, 2 },
}

local save

function CA.load()
  save = settings.readTable(Profile.careerFile())
  if save and save.v ~= 1 then save = nil end
  return save
end

function CA.write()
  if save then settings.writeTable(Profile.careerFile(), save) end
end

-- The active profile changed: forget the career in memory.
function CA.reset()
  save = nil
end

local function rnd() return love.math.random() end

---------------------------------------------------------------------------
-- Building and simulating an event
---------------------------------------------------------------------------

function CA.newEvent(idx)
  local E = CA.EVENTS[idx]
  local used = {}
  local me, nation = Profile.fencer()
  local field = { { first = "", last = me, nation = nation, rating = 0, you = true } }
  for _ = 1, 11 do
    local n = Names.random(save.gender, nil, used)
    n.rating = E.lo + (E.hi - E.lo) * rnd()
    n.style = AI.STYLE_ORDER[love.math.random(1, #AI.STYLE_ORDER)]
    field[#field + 1] = n
  end
  -- seed the AIs by rating into two pools (snake), the player into pool 1
  local others = {}
  for i = 2, 12 do others[#others + 1] = i end
  table.sort(others, function(a, b) return field[a].rating > field[b].rating end)
  -- snake seeding: pool 1 gets 5 of them and the player, pool 2 gets 6
  local SNAKE = { 1, 2, 2, 1, 1, 2, 2, 1, 1, 2, 2 }
  local pools = { {}, {} }
  for k, id in ipairs(others) do table.insert(pools[SNAKE[k]], id) end
  table.insert(pools[1], love.math.random(1, 6), 1)
  save.ev = {
    idx = idx, stage = "pool", field = field, pools = pools,
    res = {}, pos = { 1, 1 }, de = nil, place = nil,
  }
  CA.simPoolsUntilPlayer()
  CA.write()
end

local function key(a, b) return a .. "-" .. b end

-- Result of a simulated bout between field ids a and b.
function CA.sim(a, b, touches)
  local ev = save.ev
  local ra, rb = ev.field[a].rating, ev.field[b].rating
  local pa = 1 / (1 + exp(-(ra - rb) * 1.8))
  local aWins = rnd() < pa
  local close = 1 - abs(pa - 0.5) * 1.6
  local lose = floor(touches * (0.15 + 0.8 * rnd() * close) + 0.5)
  lose = core.clamp(lose, 0, touches - 1)
  if aWins then return touches, lose end
  return lose, touches
end

function CA.record(a, b, sa, sb)
  local ev = save.ev
  ev.res[key(a, b)] = { sa, sb }
  ev.res[key(b, a)] = { sb, sa }
end

function CA.result(a, b)
  local r = save.ev.res[key(a, b)]
  if r then return r[1], r[2] end
end

-- The next pool bout that involves the player, simulating the others.
function CA.simPoolsUntilPlayer()
  local ev = save.ev
  for p = 1, 2 do
    local pool = ev.pools[p]
    while ev.pos[p] <= #CA.ORDER6 do
      local o = CA.ORDER6[ev.pos[p]]
      local a, b = pool[o[1]], pool[o[2]]
      if a == 1 or b == 1 then break end
      local sa, sb = CA.sim(a, b, 5)
      CA.record(a, b, sa, sb)
      ev.pos[p] = ev.pos[p] + 1
    end
  end
end

function CA.nextPoolBout()
  local ev = save.ev
  local o = CA.ORDER6[ev.pos[1]]
  if not o then return nil end
  local a, b = ev.pools[1][o[1]], ev.pools[1][o[2]]
  return (a == 1) and b or a
end

function CA.poolStats(id)
  local ev = save.ev
  local s = { v = 0, m = 0, ts = 0, tr = 0 }
  for _, pool in ipairs(ev.pools) do
    local inPool = false
    for _, x in ipairs(pool) do if x == id then inPool = true end end
    if inPool then
      for _, o in ipairs(pool) do
        if o ~= id then
          local a, b = CA.result(id, o)
          if a then
            s.m = s.m + 1
            s.ts, s.tr = s.ts + a, s.tr + b
            if a > b then s.v = s.v + 1 end
          end
        end
      end
    end
  end
  s.ind = s.ts - s.tr
  s.vm = s.m > 0 and s.v / s.m or 0
  return s
end

function CA.ranking()
  local ev = save.ev
  local ids = {}
  for i = 1, #ev.field do ids[#ids + 1] = i end
  local st = {}
  for _, i in ipairs(ids) do st[i] = CA.poolStats(i) end
  table.sort(ids, function(a, b)
    local x, y = st[a], st[b]
    if x.vm ~= y.vm then return x.vm > y.vm end
    if x.ind ~= y.ind then return x.ind > y.ind end
    if x.ts ~= y.ts then return x.ts > y.ts end
    return a < b
  end)
  return ids, st
end

function CA.finishPools()
  local ev = save.ev
  local ids = CA.ranking()
  ev.seeds = ids
  ev.stage = "ranking"
  local rank
  for k, id in ipairs(ids) do if id == 1 then rank = k end end
  if rank > 8 then ev.place = rank end
  CA.write()
end

-- Table of 8: 1v8, 4v5, 3v6, 2v7.
function CA.startDE()
  local ev = save.ev
  local s = ev.seeds
  ev.de = {
    { { s[1], s[8] }, { s[4], s[5] }, { s[3], s[6] }, { s[2], s[7] } },
    {}, {},
  }
  ev.round = 1
  ev.stage = "de"
  CA.write()
end

function CA.playerMatch()
  local ev = save.ev
  for k, m in ipairs(ev.de[ev.round]) do
    if (m[1] == 1 or m[2] == 1) and not m.w then return m, k end
  end
end

function CA.finishRound()
  local ev = save.ev
  local T = CA.EVENTS[ev.idx].de
  local round = ev.de[ev.round]
  for _, m in ipairs(round) do
    if not m.w then
      local sa, sb = CA.sim(m[1], m[2], T)
      m.s = { sa, sb }
      m.w = sa > sb and m[1] or m[2]
    end
  end
  if ev.round < 3 then
    local nxt = {}
    for k = 1, #round, 2 do nxt[#nxt + 1] = { round[k].w, round[k + 1].w } end
    ev.de[ev.round + 1] = nxt
    ev.round = ev.round + 1
  end
end

function CA.recordDE(sa, sb)
  local ev = save.ev
  local m = CA.playerMatch()
  local me = (m[1] == 1) and 1 or 2
  m.s = me == 1 and { sa, sb } or { sb, sa }
  m.w = sa > sb and 1 or m[3 - me]
  local won = sa > sb
  local round = ev.round
  if not won then
    ev.place = ({ 5, 3, 2 })[round]
  elseif round == 3 then
    ev.place = 1
  end
  CA.finishRound()
  if ev.place then CA.endEvent() end
  CA.write()
end

function CA.endEvent()
  local ev = save.ev
  ev.stage = "done"
  local best = save.best[ev.idx]
  if not best or ev.place < best then save.best[ev.idx] = ev.place end
  if ev.place <= 3 then
    local k = ({ "gold", "silver", "bronze" })[ev.place]
    save.medals[k] = (save.medals[k] or 0) + 1
  end
  CA.write()
end

function CA.unlocked(i)
  if i == 1 then return true end
  local b = save.best[i - 1]
  return b ~= nil and b <= 3
end

local function placeName(p)
  if p == 1 then return "1ST" elseif p == 2 then return "2ND" elseif p == 3 then return "3RD" end
  return p .. "TH"
end
CA.placeName = placeName

-- A fencer's name and nation; the player's come from the active profile.
local function who(f)
  if f.you then return Profile.fencer() end
  return f.last, f.nation
end

local function short(f, n)
  return gfx.fit((who(f)), (n or 9) * 6)
end

---------------------------------------------------------------------------
-- Fencing a bout
---------------------------------------------------------------------------

function CA.fence(app, oppId, touches, onDone)
  local ev = save.ev
  local o = ev.field[oppId]
  local ai = AI.new(o.rating, o.style)
  local E = CA.EVENTS[ev.idx]
  local title = E.name
  local me, nation = Profile.fencer()
  app.set(Play.new(app, {
    left = { name = me, nation = nation, human = true, ctl = Ctl.human(input) },
    right = { name = o.last, nation = o.nation, ctl = ai, spd = ai.spd },
    touches = touches,
    title = title,
    quitLabel = "LEAVE (FENCE LATER)",
    onQuit = function() CA.eventScreen(app) end,
    onFinish = function(b)
      Profile.recordBout(b.score[1] > b.score[2], b.score[1], b.score[2])
      onDone(b.score[1], b.score[2])
    end,
  }))
end

---------------------------------------------------------------------------
-- Screens
---------------------------------------------------------------------------

local function medal(x, y, kind)
  local col = (kind == 1 and C.gold) or (kind == 2 and C.silver) or C.bronze
  core.color(C.red)
  gfx.line(x - 3, y - 7, x, y - 1)
  core.color(C.blue)
  gfx.line(x + 3, y - 7, x, y - 1)
  core.color(C.ink)
  love.graphics.circle("fill", x + 0.5, y + 2.5, 4.5, 12)
  core.color(col)
  love.graphics.circle("fill", x + 0.5, y + 2.5, 3.5, 12)
  core.color(C.lampW, 0.7)
  gfx.px(x - 1, y + 1)
end
CA.medal = medal

local function frame(title, sub)
  core.color(C.night)
  gfx.rect(0, 0, W, H)
  gfx.panel(2, 2, W - 4, H - 4)
  gfx.text(title, W / 2, 6, C.yellow, "center")
  if sub then gfx.text(sub, W / 2, 16, C.dim, "center") end
end

-- The pool sheet.
local function drawPool(p, top)
  local ev = save.ev
  local pool = ev.pools[p]
  local x0, cw = 104, 14
  local y0 = top
  gfx.text("POOL " .. p, 6, y0, C.dim)
  for k = 1, 6 do gfx.text(tostring(k), x0 + (k - 1) * cw + 7, y0, C.dim, "center") end
  gfx.text("V", 196, y0, C.dim, "center")
  gfx.text("IND", 222, y0, C.dim, "center")
  for r, id in ipairs(pool) do
    local f = ev.field[id]
    local y = y0 + r * 11
    local you = f.you
    if you then
      core.color(C.panelL)
      gfx.rect(4, y - 2, W - 8, 11)
    end
    gfx.text(tostring(r), 8, y, C.dim)
    gfx.text(short(f, 10), 18, y, you and C.yellow or C.text)
    local _, nat = who(f)
    Nations.drawFlag(nat, 84, y - 1)
    for c, oid in ipairs(pool) do
      local cx = x0 + (c - 1) * cw
      if oid == id then
        core.color(C.dark)
        gfx.rect(cx + 1, y - 1, cw - 2, 9)
      else
        local a, b = CA.result(id, oid)
        if a then
          local s = (a > b) and ("V" .. (a < 5 and a or "")) or tostring(a)
          gfx.text(s, cx + 7, y, a > b and C.greenL or C.dim, "center")
        else
          gfx.text("·", cx + 7, y, C.dark, "center")
        end
      end
    end
    local st = CA.poolStats(id)
    gfx.text(tostring(st.v), 196, y, C.text, "center")
    gfx.text((st.ind > 0 and "+" or "") .. st.ind, 222, y, st.ind >= 0 and C.text or C.redL, "center")
  end
end

local function drawRanking()
  local ev = save.ev
  local ids, st = CA.ranking()
  local top, rh = 25, 9
  gfx.text("V/M", 150, top, C.dim, "center")
  gfx.text("IND", 182, top, C.dim, "center")
  gfx.text("TS", 212, top, C.dim, "center")
  for k, id in ipairs(ids) do
    local f = ev.field[id]
    local y = top + k * rh
    local s = st[id]
    if f.you then
      core.color(C.panelL)
      gfx.rect(4, y - 1, W - 8, rh)
    end
    gfx.text(tostring(k), 17, y, k <= 8 and C.greenL or C.dark, "right")
    gfx.text(short(f, 12), 22, y, f.you and C.yellow or (k <= 8 and C.text or C.dim))
    local _, nat = who(f)
    if nat then
      Nations.drawFlag(nat, 98, y - 1)
      gfx.text(nat, 112, y, C.dim)
    end
    gfx.text(string.format("%d/%d", s.v, s.m), 150, y, C.text, "center")
    gfx.text((s.ind > 0 and "+" or "") .. s.ind, 182, y, C.text, "center")
    gfx.text(tostring(s.ts), 212, y, C.text, "center")
  end
  core.color(C.edge)
  gfx.rect(6, top + 9 * rh - 1, W - 12, 1)
end

local function drawBracket()
  local ev = save.ev
  local cols = { 6, 86, 164 }
  local function nameAt(id, x, y, win, score)
    if not id then
      gfx.text("·", x + 4, y, C.dark)
      return
    end
    local f = ev.field[id]
    local col = f.you and C.yellow or (win == false and C.dark or C.text)
    gfx.text(short(f, 8), x, y, col)
    if score then gfx.text(tostring(score), x + 70, y, win and C.greenL or C.dim, "right") end
  end
  local labels = { "QUARTER", "SEMI", "FINAL" }
  for r = 1, 3 do gfx.text(labels[r], cols[r], 27, C.edge) end
  local function ys(r)
    if r == 1 then return { 38, 47, 60, 69, 82, 91, 104, 113 } end
    if r == 2 then return { 42, 64, 86, 108 } end
    return { 53, 97 }
  end
  for r = 1, 3 do
    local round = ev.de and ev.de[r] or {}
    local y = ys(r)
    for k = 1, (r == 1 and 4 or (r == 2 and 2 or 1)) do
      local m = round[k]
      local ya, yb = y[2 * k - 1], y[2 * k]
      core.color(C.edge)
      gfx.rect(cols[r] + 72, ya + 3, 1, yb - ya)
      if m then
        nameAt(m[1], cols[r], ya, m.w and (m.w == m[1]) or nil, m.s and m.s[1])
        nameAt(m[2], cols[r], yb, m.w and (m.w == m[2]) or nil, m.s and m.s[2])
      else
        nameAt(nil, cols[r], ya); nameAt(nil, cols[r], yb)
      end
    end
  end
  -- champion
  local f = ev.de and ev.de[3] and ev.de[3][1]
  if f and f.w then
    medal(200, 70, 1)
    gfx.text(short(ev.field[f.w], 8), 200, 81, ev.field[f.w].you and C.yellow or C.gold, "center")
  end
end

function CA.eventScreen(app)
  local ev = save.ev
  local E = CA.EVENTS[ev.idx]
  local s = {}
  function s:update()
    if input.pressed.b then
      audio.play("back", 0.5)
      CA.hub(app)
      return
    end
    if not input.pressed.a then return end
    audio.play("select", 0.5)
    if ev.stage == "pool" then
      local opp = CA.nextPoolBout()
      if not opp then
        CA.finishPools()
        CA.eventScreen(app)
        return
      end
      CA.fence(app, opp, 5, function(sa, sb)
        CA.record(1, opp, sa, sb)
        ev.pos[1] = ev.pos[1] + 1
        CA.simPoolsUntilPlayer()
        if not CA.nextPoolBout() then
          -- finish the other pool too
          while ev.pos[2] <= #CA.ORDER6 do
            local o = CA.ORDER6[ev.pos[2]]
            local a, b = ev.pools[2][o[1]], ev.pools[2][o[2]]
            local x, y = CA.sim(a, b, 5)
            CA.record(a, b, x, y)
            ev.pos[2] = ev.pos[2] + 1
          end
        end
        CA.write()
        CA.eventScreen(app)
      end)
    elseif ev.stage == "ranking" then
      if ev.place then
        CA.endEvent()
      else
        CA.startDE()
      end
      CA.eventScreen(app)
    elseif ev.stage == "de" then
      local m = CA.playerMatch()
      if not m then return end
      local opp = (m[1] == 1) and m[2] or m[1]
      CA.fence(app, opp, E.de, function(sa, sb)
        CA.recordDE(sa, sb)
        CA.eventScreen(app)
      end)
    elseif ev.stage == "done" then
      save.ev = nil
      CA.write()
      CA.hub(app)
    end
  end
  function s:draw()
    if ev.stage == "pool" then
      frame(E.name, "POOLS · BOUTS TO 5")
      drawPool(1, 28)
      local opp = CA.nextPoolBout()
      local done = 0
      for _, o in ipairs(ev.pools[1]) do if o ~= 1 and CA.result(1, o) then done = done + 1 end end
      if opp then
        local o = ev.field[opp]
        gfx.text(string.format("BOUT %d OF 5", done + 1), 8, 112, C.dim)
        gfx.text("NEXT: " .. o.first .. " " .. o.last .. " " .. o.nation, 8, 123, C.text)
        gfx.text("STYLE: " .. AI.STYLE_NAME[o.style], 8, 133, C.dim)
      else
        gfx.text("YOUR POOL IS DONE", 8, 118, C.text)
      end
      gfx.hints({ { "A", opp and "FENCE" or "RANKING" }, { "B", "CAREER" } }, W - 6, H - 12, "right")
    elseif ev.stage == "ranking" then
      frame(E.name, "RANKING AFTER THE POOLS · TOP 8 GO ON")
      drawRanking()
      gfx.hints({ { "A", ev.place and "RESULT" or "TABLE OF 8" }, { "B", "CAREER" } }, W - 6, H - 12, "right")
    elseif ev.stage == "de" then
      frame(E.name, "DIRECT ELIMINATION · BOUTS TO " .. E.de)
      drawBracket()
      local m = CA.playerMatch()
      if m then
        local o = ev.field[(m[1] == 1) and m[2] or m[1]]
        gfx.text("NEXT: " .. o.last .. " " .. o.nation, 8, 125, C.text)
        gfx.text("STYLE: " .. AI.STYLE_NAME[o.style], 8, 135, C.dim)
      end
      gfx.hints({ { "A", "FENCE" }, { "B", "CAREER" } }, W - 6, H - 12, "right")
    elseif ev.stage == "done" then
      frame(E.name, "FINAL RESULT")
      local p = ev.place
      if p <= 3 then
        medal(W / 2, 40, p)
        gfx.text(({ "CHAMPION!", "SILVER MEDAL", "BRONZE MEDAL" })[p], W / 2, 58, ({ C.gold, C.silver, C.bronze })[p], "center", true, 2)
      else
        gfx.text(placeName(p) .. " PLACE", W / 2, 50, C.text, "center", true, 2)
      end
      gfx.text("YOU FINISHED " .. placeName(p) .. " OF 12", W / 2, 82, C.text, "center")
      local nxt = CA.EVENTS[ev.idx + 1]
      if p <= 3 and nxt then
        gfx.text("UNLOCKED: " .. nxt.name, W / 2, 96, C.greenL, "center")
      elseif nxt and not CA.unlocked(ev.idx + 1) then
        gfx.text("A MEDAL HERE UNLOCKS THE " .. nxt.name, W / 2, 96, C.dim, "center")
      end
      gfx.hints({ { "A", "CAREER" } }, W / 2, H - 14, "center")
    end
  end
  app.set(s)
end

function CA.hub(app)
  if not save then CA.load() end
  if not save then
    -- a new career: choose the event category
    local m = Menu.new({
      { label = "WOMEN'S FOIL", action = function() save = { v = 1, gender = "f", best = {}, medals = {} }; CA.write(); CA.hub(app) end },
      { label = "MEN'S FOIL", action = function() save = { v = 1, gender = "m", best = {}, medals = {} }; CA.write(); CA.hub(app) end },
      { label = "BACK", action = function() app.toTitle() end },
    }, { back = function() app.toTitle() end })
    local s = {}
    function s:update() m:update() end
    function s:draw()
      frame("NEW CAREER")
      gfx.para("Six competitions, from your club's open to the World Championships. Win a medal to move up.", 16, 28, W - 32, C.text)
      gfx.text("YOUR CATEGORY", W / 2, 70, C.dim, "center")
      m:draw(W / 2 - 60, 82, 120)
    end
    app.set(s)
    return
  end
  local items = {}
  if save.ev then
    local E = CA.EVENTS[save.ev.idx]
    items[#items + 1] = { label = "CONTINUE: " .. E.name, action = function() CA.eventScreen(app) end, hint = "EVENT IN PROGRESS" }
  end
  for i, E in ipairs(CA.EVENTS) do
    items[#items + 1] = {
      label = E.name,
      value = function()
        local b = save.best[i]
        if not CA.unlocked(i) then return "LOCKED" end
        return b and ("BEST " .. placeName(b)) or ""
      end,
      disabled = function() return save.ev ~= nil or not CA.unlocked(i) end,
      action = function() CA.newEvent(i); CA.eventScreen(app) end,
      hint = string.format("DE BOUTS TO %d · OPPONENTS %s TO %s", E.de,
        AI.params(E.lo).name, AI.params(E.hi).name),
    }
  end
  items[#items + 1] = { label = "BACK", action = function() app.toTitle() end }
  local m = Menu.new(items, { back = function() app.toTitle() end })
  local s = {}
  function s:update() m:update() end
  function s:draw()
    frame("CAREER", save.gender == "f" and "WOMEN'S FOIL" or "MEN'S FOIL")
    local hint = m:draw(8, 28, W - 16)
    for i = 1, #CA.EVENTS do
      local b = save.best[i]
      if b and b <= 3 then medal(W - 18 - 52, 28 + (i - 1 + (save.ev and 1 or 0)) * 12 + 2, b) end
    end
    local md = save.medals
    gfx.text(string.format("MEDALS  %d GOLD · %d SILVER · %d BRONZE", md.gold or 0, md.silver or 0, md.bronze or 0),
      W / 2, H - 25, C.dim, "center")
    if hint then gfx.text(hint, W / 2, H - 14, C.dim, "center") end
  end
  app.set(s)
end

-- For tests: get/set the save in memory.
function CA._save() return save end
function CA._setSave(s) save = s end

-- Screenshots of the career screens with a simulated event.
function CA.shot(app, mode, args)
  save = { v = 1, gender = "f", best = { 1, 3 }, medals = { gold = 1, bronze = 1 } }
  core.testMode = true
  if mode == "career" then
    CA.hub(app)
    return
  end
  CA.newEvent(3)
  local ev = save.ev
  -- play the player's pool bouts out by simulation
  while CA.nextPoolBout() do
    local opp = CA.nextPoolBout()
    local sa, sb = CA.sim(1, opp, 5)
    if rnd() < 0.7 then sa, sb = 5, floor(rnd() * 4) end
    CA.record(1, opp, sa, sb)
    ev.pos[1] = ev.pos[1] + 1
    CA.simPoolsUntilPlayer()
    if mode == "pool" and ev.pos[1] > 9 then break end
  end
  if mode == "pool" then CA.eventScreen(app) return end
  while ev.pos[2] <= #CA.ORDER6 do
    local o = CA.ORDER6[ev.pos[2]]
    local a, b = ev.pools[2][o[1]], ev.pools[2][o[2]]
    local x, y = CA.sim(a, b, 5)
    CA.record(a, b, x, y)
    ev.pos[2] = ev.pos[2] + 1
  end
  CA.finishPools()
  if mode == "bracket" then
    if not ev.place then
      CA.startDE()
      CA.recordDE(15, 11)
    end
  end
  CA.eventScreen(app)
end

return CA
