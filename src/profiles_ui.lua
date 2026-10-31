-- Profile screens: the name keyboard, the nation picker, the profile card
-- (switch, rename, change nation, delete) and the first-run welcome.

local core = require("src.core")
local gfx = require("src.gfx")
local input = require("src.input")
local audio = require("src.audio")
local settings = require("src.settings")
local Menu = require("src.menu")
local Profile = require("src.profile")
local Nations = require("src.nations")

local floor, max, min = math.floor, math.max, math.min
local C = core.C
local W, H = core.W, core.H

local U = {}

local function chars(s)
  local t = {}
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do t[#t + 1] = ch end
  return t
end
U.chars = chars

local function frame(title)
  core.color(C.night)
  gfx.rect(0, 0, W, H)
  gfx.panel(4, 4, W - 8, H - 8)
  if title then gfx.text(title, W / 2, 9, C.yellow, "center") end
end

---------------------------------------------------------------------------
-- Name keyboard
---------------------------------------------------------------------------

local PAGES = {
  { "ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZ-'. " },
  { "ÀÁÂÄÅĂÃÇÈÉ", "ÊËÌÍÎÏÑÒÓÔ", "ÖÕØŐÙÚÛÜŰŮ", "ÝŠŚŽŹČĆŘĎŤ", "ȘȚŞŁŃŇĚ   " },
}
local ACTIONS = { "SPACE", "DELETE", "ÀÉÎ", "OK" }

-- opts: title, name, onDone(name), onCancel()
function U.keyboard(app, opts)
  local s = { page = 1, row = 1, col = 1, name = chars(opts.name or "") }
  local function grid() return PAGES[s.page] end
  local function rows() return #grid() + 1 end
  local function rowChars(r) return chars(grid()[r]) end
  local function finish()
    local name = table.concat(s.name):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
      s.warn = "TYPE A NAME FIRST"
      audio.play("back", 0.4)
      return
    end
    audio.play("select", 0.5)
    opts.onDone(name)
  end
  local function type(ch)
    if #s.name >= Profile.MAXNAME then
      s.warn = "UP TO " .. Profile.MAXNAME .. " LETTERS"
      return
    end
    if ch == " " and (#s.name == 0 or s.name[#s.name] == " ") then return end
    s.name[#s.name + 1] = ch
    s.warn = nil
    audio.play("blip", 0.4, 1.2)
  end
  local function del()
    if #s.name > 0 then
      s.name[#s.name] = nil
      audio.play("blip", 0.4, 0.8)
    else
      audio.play("back", 0.4)
      opts.onCancel()
    end
  end
  local function togglePage()
    s.page = 3 - s.page
    s.row = min(s.row, rows())
    audio.play("blip", 0.4)
  end
  function s:update()
    local nr = rows()
    if input.nav("up") then s.row = (s.row - 2) % nr + 1
    elseif input.nav("down") then s.row = s.row % nr + 1
    elseif input.nav("left") then s.col = s.col - 1
    elseif input.nav("right") then s.col = s.col + 1 end
    local ncol = (s.row == nr) and #ACTIONS or 10
    if s.col < 1 then s.col = ncol elseif s.col > ncol then s.col = 1 end
    if input.pressed.a then
      if s.row == nr then
        local a = ACTIONS[s.col]
        if a == "SPACE" then type(" ")
        elseif a == "DELETE" then del()
        elseif a == "OK" then finish()
        else togglePage() end
      else
        local ch = rowChars(s.row)[s.col]
        if ch and ch ~= " " then type(ch)
        elseif ch == " " and s.page == 1 then type(" ") end
      end
    elseif input.pressed.b then del()
    elseif input.pressed.x then type(" ")
    elseif input.pressed.y then togglePage()
    elseif input.pressed.start then finish()
    end
  end
  function s:draw()
    frame(opts.title or "YOUR NAME")
    -- the name being typed
    local name = table.concat(s.name)
    local nx = W / 2 - floor(gfx.textWidth(name .. "_", 2) / 2)
    core.color(C.ink)
    gfx.rect(30, 20, W - 60, 22)
    gfx.text(name, nx, 24, C.text, "left", false, 2)
    if floor(core.time * 2.5) % 2 == 0 then
      gfx.text("_", nx + gfx.textWidth(name, 2), 24, C.yellow, "left", false, 2)
    end
    gfx.text(string.format("%d/%d", #s.name, Profile.MAXNAME), W - 34, 44, C.dark, "right")
    -- keys
    local g = grid()
    local cw, ch = 16, 12
    local x0 = floor((W - 10 * cw) / 2)
    local y0 = 52
    for r = 1, #g do
      for c, k in ipairs(chars(g[r])) do
        local x, y = x0 + (c - 1) * cw, y0 + (r - 1) * ch
        local sel = (s.row == r and s.col == c)
        if sel then
          core.color(C.yellow)
          gfx.rect(x + 1, y, cw - 2, ch - 1)
        end
        local label = (k == " ") and ((s.page == 1 and c == 10) and "␣" or "") or k
        if label == "␣" then
          core.color(sel and C.ink or C.dim)
          gfx.rect(x + 5, y + 7, 6, 1)
        else
          gfx.text(label, x + cw / 2, y + 2, sel and C.ink or C.text, "center")
        end
      end
    end
    local ay = y0 + #g * ch + 4
    local aw = 40
    local ax0 = floor((W - #ACTIONS * (aw + 4)) / 2)
    for c, a in ipairs(ACTIONS) do
      local x = ax0 + (c - 1) * (aw + 4)
      local sel = (s.row == rows() and s.col == c)
      local label = (a == "ÀÉÎ" and s.page == 2) and "ABC" or a
      core.color(sel and C.yellow or C.panelL)
      gfx.rect(x, ay, aw, 11)
      gfx.text(label, x + aw / 2, ay + 2, sel and C.ink or C.text, "center")
    end
    if s.warn then gfx.text(s.warn, W / 2, H - 30, C.orange, "center") end
    gfx.hints({ { "B", "DELETE" }, { "Y", "ÀÉÎ" }, { "START", "OK" } }, W / 2, H - 18, "center")
  end
  return s
end

---------------------------------------------------------------------------
-- Nation picker
---------------------------------------------------------------------------

-- opts: title, code, onDone(code), onCancel()
function U.nations(app, opts)
  local list = Nations.LIST
  local s = { sel = 1, top = 1 }
  if opts.code and Nations.BY[opts.code] then s.sel = Nations.BY[opts.code].index end
  local ROWS = 10
  local function clampTop()
    if s.sel < s.top then s.top = s.sel end
    if s.sel > s.top + ROWS - 1 then s.top = s.sel - ROWS + 1 end
    s.top = max(1, min(s.top, #list - ROWS + 1))
  end
  clampTop()
  s.top = max(1, min(s.sel - 4, #list - ROWS + 1))
  local function jumpLetter(dir)
    local first = list[s.sel].name:sub(1, 1)
    local i = s.sel
    repeat
      i = (i - 1 + dir) % #list + 1
    until list[i].name:sub(1, 1) ~= first or i == s.sel
    if dir < 0 then
      -- to the first nation of that letter
      local l = list[i].name:sub(1, 1)
      while i > 1 and list[i - 1].name:sub(1, 1) == l do i = i - 1 end
    end
    s.sel = i
  end
  function s:update()
    local n = #list
    if input.nav("up") then s.sel = (s.sel - 2) % n + 1; audio.play("blip", 0.3)
    elseif input.nav("down") then s.sel = s.sel % n + 1; audio.play("blip", 0.3)
    elseif input.nav("left") then jumpLetter(-1); audio.play("blip", 0.3, 0.9)
    elseif input.nav("right") then jumpLetter(1); audio.play("blip", 0.3, 1.1)
    elseif input.pressed.l1 then s.sel = max(1, s.sel - ROWS)
    elseif input.pressed.r1 then s.sel = min(n, s.sel + ROWS)
    elseif input.pressed.a or input.pressed.start then
      audio.play("select", 0.5)
      opts.onDone(list[s.sel].code)
      return
    elseif input.pressed.b then
      audio.play("back", 0.5)
      opts.onCancel()
      return
    end
    clampTop()
  end
  function s:draw()
    frame(opts.title or "NATIONALITY")
    local y0 = 22
    for r = 0, ROWS - 1 do
      local i = s.top + r
      local e = list[i]
      if e then
        local y = y0 + r * 11
        local sel = (i == s.sel)
        if sel then
          core.color(C.panelL)
          gfx.rect(10, y - 2, W - 20, 11)
          core.color(C.yellow)
          gfx.rect(10, y - 2, 1, 11)
        end
        Nations.drawFlag(e.code, 16, y - 1)
        gfx.text(e.code, 32, y, sel and C.yellow or C.dim)
        gfx.text(e.name, 56, y, sel and C.text or C.whiteS)
      end
    end
    -- scroll bar
    local n = #list
    core.color(C.dark)
    gfx.rect(W - 12, y0 - 2, 2, ROWS * 11)
    core.color(C.yellow)
    gfx.rect(W - 12, y0 - 2 + floor((s.top - 1) / n * ROWS * 11), 2, max(3, floor(ROWS / n * ROWS * 11)))
    gfx.hints({ { "◄►", "LETTER" }, { "A", "CHOOSE" }, { "B", "BACK" } }, W / 2, H - 18, "center")
  end
  return s
end

---------------------------------------------------------------------------
-- Creating a profile: name, then nation
---------------------------------------------------------------------------

function U.create(app, done, cancel, title)
  app.set(U.keyboard(app, {
    title = title or "NEW PROFILE · NAME",
    onCancel = cancel,
    onDone = function(name)
      app.set(U.nations(app, {
        title = name .. " · NATIONALITY",
        onCancel = function() U.create(app, done, cancel, title) end,
        onDone = function(code)
          Profile.create(name, code)
          done()
        end,
      }))
    end,
  }))
end

function U.firstRun(app, done)
  local s = {}
  function s:update()
    if input.pressed.a or input.pressed.start then
      audio.play("select", 0.5)
      U.create(app, done, function() U.firstRun(app, done) end, "YOUR NAME")
    end
  end
  function s:draw()
    frame()
    gfx.text("WELCOME TO", W / 2, 22, C.dim, "center")
    gfx.text("RG FENCING", W / 2, 34, C.text, "center", true, 2)
    gfx.para("Create your profile: a name for the scoreboard and the nation you fence for. "
      .. "Your career and training progress are kept in it, and more fencers can each have their own.",
      18, 62, W - 36, C.text)
    if floor(core.time * 2) % 2 == 0 then
      gfx.hints({ { "A", "CREATE YOUR PROFILE" } }, W / 2, H - 22, "center")
    end
  end
  app.set(s)
end

---------------------------------------------------------------------------
-- The profile card
---------------------------------------------------------------------------

local function careerBest(p)
  local t = settings.readTable(Profile.careerFile(p))
  if not t or not t.best then return nil end
  local CA = require("src.career")
  local bestI, bestP
  for i = #CA.EVENTS, 1, -1 do
    local b = t.best[i]
    if b and (not bestP or b <= 3) then bestI, bestP = i, b; break end
  end
  if bestI then return CA.placeName(bestP) .. " AT THE " .. CA.EVENTS[bestI].name end
end

local function confirm(app, text, yes, no)
  local s = {}
  function s:update()
    if input.pressed.a then audio.play("select", 0.5); yes()
    elseif input.pressed.b then audio.play("back", 0.5); no() end
  end
  function s:draw()
    frame("ARE YOU SURE?")
    gfx.para(text, 24, 50, W - 48, C.text)
    gfx.hints({ { "A", "YES" }, { "B", "NO" } }, W / 2, H - 22, "center")
  end
  app.set(s)
end

local function switcher(app, back)
  local items = {}
  for _, p in ipairs(Profile.list()) do
    items[#items + 1] = {
      label = p.name, flag = p.nation,
      value = function() return (Profile.current() == p) and "ACTIVE" or "" end,
      action = function() Profile.setActive(p.id); back() end,
    }
  end
  items[#items + 1] = { label = "BACK", action = back }
  local m = Menu.new(items, { back = back })
  local s = {}
  function s:update() m:update() end
  function s:draw()
    frame("SWITCH PROFILE")
    m:draw(30, 24, W - 60)
  end
  app.set(s)
end

function U.screen(app)
  local p = Profile.current()
  if not p then
    U.firstRun(app, function() U.screen(app) end)
    return
  end
  local function again() U.screen(app) end
  local items = {}
  if #Profile.list() > 1 then
    items[#items + 1] = { label = "SWITCH PROFILE", action = function() switcher(app, again) end }
  end
  items[#items + 1] = { label = "NEW PROFILE", action = function() U.create(app, again, again) end }
  items[#items + 1] = { label = "CHANGE NAME", action = function()
    app.set(U.keyboard(app, { title = "CHANGE NAME", name = p.name, onCancel = again,
      onDone = function(name) Profile.update(p, name); again() end }))
  end }
  items[#items + 1] = { label = "CHANGE NATIONALITY", action = function()
    app.set(U.nations(app, { title = "NATIONALITY", code = p.nation, onCancel = again,
      onDone = function(code) Profile.update(p, nil, code); again() end }))
  end }
  items[#items + 1] = { label = "DELETE PROFILE", action = function()
    confirm(app, "Delete " .. p.name .. "? Their career and training progress will be lost.", function()
      Profile.delete(p.id)
      if Profile.current() then again() else U.firstRun(app, function() app.toTitle() end) end
    end, again)
  end }
  items[#items + 1] = { label = "BACK", action = function() app.toTitle() end }
  local m = Menu.new(items, { back = function() app.toTitle() end, rowH = 10 })
  local best = careerBest(p)
  local s = {}
  function s:update() m:update() end
  function s:draw()
    frame("PROFILE")
    -- the card
    local nx = 14 + Nations.drawFlag(p.nation, 14, 20, 2) + 5
    gfx.text(gfx.fit(p.name, (W - nx - 12) / 2), nx, 21, C.text, "left", false, 2)
    gfx.text(Nations.name(p.nation), nx, 38, C.dim)
    local st = p.stats
    local pct = st.bouts > 0 and floor(100 * st.wins / st.bouts + 0.5) or 0
    gfx.text(string.format("BOUTS %d · WON %d (%d%%)", st.bouts, st.wins, pct), 14, 50, C.text)
    gfx.text(string.format("TOUCHES SCORED %d · RECEIVED %d", st.ts, st.tr), 14, 59, C.text)
    local d = 0
    for _ in pairs(p.drills) do d = d + 1 end
    gfx.text(string.format("TRAINING DRILLS %d/%d", d, #require("src.training").DRILLS), 14, 68, C.text)
    gfx.text(gfx.fit(best and ("CAREER BEST: " .. best) or "CAREER: NOT STARTED", W - 28), 14, 77, C.dim)
    m:draw(10, 89, W - 20)
  end
  app.set(s)
end

return U
