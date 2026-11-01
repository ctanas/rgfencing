-- UI smoke test: drives the real app with scripted button presses through
-- every screen, a quick bout, the pause menu (and its arcade/tactical
-- switch, both ways), a tactical career pool bout and a drill. Any Lua
-- error fails the run.
--
--   love . --smoke

local input = require("src.input")

local S = {}

-- { "label" } | { wait = frames } | { press = btn } | { hold = btn, frames = n }
local SCRIPT = {
  { "first run" }, { wait = 20 }, { press = "a" }, { wait = 5 },
  { press = "a" }, { press = "right" }, { press = "a" }, { press = "y" }, { press = "a" }, { press = "b" },
  { press = "start" }, { wait = 5 }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { "title" }, { wait = 30 },
  { "tactical bout" }, { press = "down" }, { press = "a" }, { wait = 5 }, { press = "down" }, { press = "down" },
  { press = "down" }, { press = "a" }, { wait = 240 },
  { hold = "right", frames = 40 }, { press = "a" }, { wait = 10 }, { press = "down" }, { press = "right" },
  { press = "a" }, { wait = 150 }, { press = "a" }, { wait = 60 }, { press = "down" }, { press = "a" }, { wait = 150 },
  { press = "a" }, { wait = 60 }, { press = "a" }, { wait = 150 }, { press = "b" }, { wait = 30 }, { press = "a" },
  { wait = 200 }, { press = "a" }, { wait = 100 },
  { "tactical bout switched to arcade" }, { press = "start" }, { press = "down" }, { press = "a" }, { press = "start" },
  { wait = 60 }, { hold = "right", frames = 30 }, { press = "a" }, { wait = 40 }, { press = "x" }, { wait = 60 },
  { "and back to tactical" }, { press = "start" }, { press = "down" }, { press = "a" }, { press = "start" },
  { wait = 60 }, { hold = "right", frames = 30 }, { press = "a" }, { wait = 10 }, { press = "a" }, { wait = 150 },
  { press = "start" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 10 },
  { press = "b" }, { wait = 5 }, { press = "down" }, { press = "a" }, { wait = 10 },
  { "quick bout" }, { press = "a" }, { wait = 5 }, { press = "right" }, { press = "down" }, { press = "down" },
  { press = "down" }, { press = "a" }, { wait = 150 },
  { hold = "right", frames = 50 }, { press = "a" }, { wait = 40 }, { hold = "up", frames = 2 },
  { press = "b" }, { wait = 30 }, { press = "x" }, { press = "y" }, { wait = 60 }, { press = "r1" }, { press = "l1" },
  { wait = 300 },
  { "quick bout switched to tactical" }, { press = "start" }, { press = "down" }, { press = "right" }, { press = "start" },
  { wait = 60 }, { hold = "right", frames = 30 }, { press = "a" }, { wait = 10 }, { press = "a" }, { wait = 150 },
  { "pause" }, { press = "start" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 10 },
  { press = "b" }, { press = "down" }, { press = "a" }, { wait = 10 },
  { "career" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "a" }, { wait = 5 },
  { "career: tactical mode" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "a" }, { wait = 200 }, { hold = "right", frames = 40 }, { press = "a" }, { wait = 10 }, { press = "a" },
  { wait = 200 },
  { press = "start" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "b" }, { wait = 5 }, { press = "b" }, { wait = 5 },
  { "training" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 }, { press = "a" },
  { wait = 400 }, { press = "b" }, { wait = 200 },
  { press = "start" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "b" }, { wait = 5 },
  { "profile" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "a" }, { wait = 5 }, { press = "a" }, { press = "a" }, { press = "start" }, { wait = 5 },
  { press = "up" }, { press = "a" }, { wait = 5 },
  { press = "a" }, { wait = 5 }, { press = "a" }, { wait = 5 },
  -- a second profile now exists, so SWITCH PROFILE heads the menu
  { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 }, { press = "right" },
  { press = "a" }, { wait = 5 },
  { press = "b" }, { wait = 5 },
  { "how to play" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "down" },
  { press = "a" }, { wait = 5 }, { press = "right" },
  { press = "right" }, { press = "right" }, { press = "right" }, { press = "right" }, { press = "right" },
  { press = "b" }, { wait = 5 },
  { "options" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "down" },
  { press = "down" }, { press = "a" }, { wait = 5 }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "right" },
  { press = "down" }, { press = "right" }, { wait = 5 },
  { press = "b" }, { wait = 10 },
  { "quick bout from the right" }, { press = "up" }, { press = "up" }, { press = "up" }, { press = "up" }, { press = "up" },
  { press = "up" },
  { press = "a" }, { wait = 5 }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 150 },
  { hold = "left", frames = 50 }, { press = "a" }, { wait = 200 },
  { press = "start" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" },
  { wait = 10 },
  { "drill from the right" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 }, { press = "a" },
  { wait = 300 }, { press = "b" }, { wait = 100 },
  { press = "start" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "b" }, { wait = 5 },
  -- the second profile's career: a new competition, so the mode picker (ARCADE)
  { "career bout from the right" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 }, { press = "a" }, { wait = 5 },
  { press = "a" }, { wait = 5 }, { press = "a" }, { wait = 200 }, { hold = "left", frames = 40 }, { wait = 150 },
  { press = "start" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "b" }, { wait = 5 }, { press = "b" }, { wait = 5 },
  { "done" },
}

function S.install(app)
  local step, wait, holdN, holdBtn = 1, 0, 0, nil
  -- a frame that takes more than 5 s is a hang: fail with where it is
  local frameStart = os.clock()
  debug.sethook(function()
    if os.clock() - frameStart > 5 then
      debug.sethook()
      print("SMOKE FAILED: a frame has taken over 5 s\n" .. debug.traceback())
      os.exit(1)
    end
  end, "", 100000)
  input.nav = function(dir) return input.pressed[dir] end
  input.update = function()
    frameStart = os.clock()
    for _, a in ipairs(input.ACTIONS) do
      input.pressed[a] = false
      input.down[a] = false
    end
    if holdN > 0 then
      input.down[holdBtn] = true
      holdN = holdN - 1
      return
    end
    if wait > 0 then wait = wait - 1; return end
    local c = SCRIPT[step]
    if not c then
      print("SMOKE OK")
      love.event.quit()
      return
    end
    step = step + 1
    if os.getenv("SMOKE_TRACE") then
      local sc = app.current and app.current()
      local d = ""
      for k, v in pairs(c) do d = d .. tostring(k) .. "=" .. tostring(v) .. " " end
      local nm = sc and (sc.mode or (sc.bout and ("bout:" .. sc.bout.phase .. (sc.match and (" " .. sc.match.mode
        .. (sc.menu2 and (" MENU " .. sc.menu2.menu) or "")) or ""))) or "?") or "-"
      print(string.format("  %3d %-28s scene=%s sel=%s", step - 1, d, tostring(nm), tostring(sc and (sc.sel or (sc[sc.mode or ""] and sc[sc.mode].sel)))))
    end
    if c[1] then
      -- where the script has got to: the screen and its selection
      local sc = app.current and app.current()
      local where = ""
      if sc then
        if sc.mode and sc[sc.mode] and sc[sc.mode].sel then where = sc.mode .. " #" .. sc[sc.mode].sel end
        if sc.bout then where = where .. " bout:" .. tostring(sc.bout.phase) end
      end
      print("smoke: " .. c[1] .. "   [" .. where .. "]")
    elseif c.wait then
      wait = c.wait
    elseif c.press then
      input.pressed[c.press] = true
      input.down[c.press] = true
      wait = 2
    elseif c.hold then
      input.pressed[c.hold] = true
      input.down[c.hold] = true
      holdBtn, holdN = c.hold, c.frames
    end
  end
  love.errorhandler = function(msg)
    print("SMOKE FAILED: " .. tostring(msg))
    print(debug.traceback())
    os.exit(1)
  end
end

return S
