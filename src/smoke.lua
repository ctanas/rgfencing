-- UI smoke test: drives the real app with scripted button presses through
-- every screen, a quick bout, the pause menu, a career pool bout and a
-- drill. Any Lua error fails the run.
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
  { "quick bout" }, { press = "a" }, { wait = 5 }, { press = "right" }, { press = "down" }, { press = "down" },
  { press = "down" }, { press = "a" }, { wait = 150 },
  { hold = "right", frames = 50 }, { press = "a" }, { wait = 40 }, { hold = "up", frames = 2 },
  { press = "b" }, { wait = 30 }, { press = "x" }, { press = "y" }, { wait = 60 }, { press = "r1" }, { press = "l1" },
  { wait = 300 },
  { "pause" }, { press = "start" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 10 },
  { press = "b" }, { press = "down" }, { press = "a" }, { wait = 10 },
  { "career" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "a" }, { wait = 5 }, { press = "a" }, { wait = 200 }, { hold = "right", frames = 40 }, { wait = 200 },
  { press = "start" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "b" }, { wait = 5 }, { press = "b" }, { wait = 5 },
  { "training" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 }, { press = "a" },
  { wait = 400 }, { press = "b" }, { wait = 200 },
  { press = "start" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "b" }, { wait = 5 },
  { "profile" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "a" }, { wait = 5 }, { press = "a" }, { press = "a" }, { press = "start" }, { wait = 5 },
  { press = "up" }, { press = "a" }, { wait = 5 },
  { press = "a" }, { wait = 5 }, { press = "a" }, { wait = 5 },
  { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 }, { press = "right" }, { press = "a" }, { wait = 5 },
  { press = "b" }, { wait = 5 },
  { "how to play" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "right" }, { press = "right" }, { press = "right" }, { press = "right" }, { press = "right" },
  { press = "b" }, { wait = 5 },
  { "options" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "down" },
  { press = "a" }, { wait = 5 }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "right" },
  { press = "down" }, { press = "right" }, { wait = 5 },
  { press = "b" }, { wait = 10 },
  { "quick bout from the right" }, { press = "up" }, { press = "up" }, { press = "up" }, { press = "up" }, { press = "up" },
  { press = "a" }, { wait = 5 }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 150 },
  { hold = "left", frames = 50 }, { press = "a" }, { wait = 200 },
  { press = "start" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 10 },
  { "drill from the right" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 }, { press = "a" },
  { wait = 300 }, { press = "b" }, { wait = 100 },
  { press = "start" }, { press = "down" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "b" }, { wait = 5 },
  { "career bout from the right" }, { press = "down" }, { press = "a" }, { wait = 5 }, { press = "a" }, { wait = 5 },
  { press = "a" }, { wait = 200 }, { hold = "left", frames = 40 }, { wait = 150 },
  { press = "start" }, { press = "down" }, { press = "down" }, { press = "a" }, { wait = 5 },
  { press = "b" }, { wait = 5 }, { press = "b" }, { wait = 5 },
  { "done" },
}

function S.install(app)
  local step, wait, holdN, holdBtn = 1, 0, 0, nil
  input.nav = function(dir) return input.pressed[dir] end
  input.update = function()
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
    if c[1] then
      print("smoke: " .. c[1])
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
