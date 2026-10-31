-- Input: merges SDL gamepad (D-pad, buttons, left stick) with the keyboard,
-- and exposes per-frame "down"/"pressed" states plus menu auto-repeat.
--
-- On the handheld, PortMaster's gptokeyb also turns buttons into key
-- presses. When a real gamepad is visible to SDL there, the keyboard is
-- ignored so nothing is read twice.

local core = require("src.core")

local I = {}

I.ACTIONS = { "left", "right", "up", "down", "a", "b", "x", "y", "l1", "r1", "start", "select" }

local KEYS = {
  left = { "left" }, right = { "right" }, up = { "up" }, down = { "down" },
  a = { "z", "space" }, b = { "x", "lshift" }, x = { "c" }, y = { "v" },
  l1 = { "q", "pageup" }, r1 = { "e", "pagedown" },
  start = { "return", "p" }, select = { "escape", "backspace" },
}

local PAD = {
  left = "dpleft", right = "dpright", up = "dpup", down = "dpdown",
  a = "a", b = "b", x = "x", y = "y",
  l1 = "leftshoulder", r1 = "rightshoulder",
  start = "start", select = "back",
}

local DEAD = 0.45

I.down, I.pressed = {}, {}
I.swapAB = false
I.keyboard = true

local pads = {}
local raw = {}
local navDown, navRep, navTimer = {}, {}, {}

function I.refresh()
  pads = {}
  if love.joystick then
    for _, j in ipairs(love.joystick.getJoysticks()) do
      if j:isGamepad() then pads[#pads + 1] = j end
    end
  end
  I.keyboard = not (core.device and #pads > 0)
end

function I.init(swap)
  I.swapAB = swap and true or false
  I.refresh()
end

local function keyDown(list)
  for i = 1, #list do
    if love.keyboard.isDown(list[i]) then return true end
  end
  return false
end

function I.update(dt)
  for _, a in ipairs(I.ACTIONS) do
    local d = I.keyboard and keyDown(KEYS[a]) or false
    if not d then
      local btn = PAD[a]
      for _, j in ipairs(pads) do
        if j:isGamepadDown(btn) then d = true; break end
      end
    end
    raw[a] = d
  end
  -- The left stick (if any) doubles as the D-pad.
  for _, j in ipairs(pads) do
    local x, y = j:getGamepadAxis("leftx"), j:getGamepadAxis("lefty")
    if x < -DEAD then raw.left = true elseif x > DEAD then raw.right = true end
    if y < -DEAD then raw.up = true elseif y > DEAD then raw.down = true end
  end
  if I.swapAB then raw.a, raw.b = raw.b, raw.a end
  for _, a in ipairs(I.ACTIONS) do
    local d = raw[a]
    I.pressed[a] = d and not I.down[a]
    I.down[a] = d
  end

  -- Menu navigation with auto-repeat.
  for _, dir in ipairs({ "left", "right", "up", "down" }) do
    local d = I.down[dir]
    if d and not navDown[dir] then
      navRep[dir] = true
      navTimer[dir] = 0.32
    elseif d then
      navTimer[dir] = navTimer[dir] - dt
      if navTimer[dir] <= 0 then
        navRep[dir] = true
        navTimer[dir] = 0.08
      else
        navRep[dir] = false
      end
    else
      navRep[dir] = false
    end
    navDown[dir] = d
  end
end

function I.nav(dir) return navRep[dir] or false end

function I.anyPressed()
  for _, a in ipairs(I.ACTIONS) do
    if I.pressed[a] then return true end
  end
  return false
end

-- Clear "pressed" so a scene change doesn't re-use the same button press.
function I.consume()
  for _, a in ipairs(I.ACTIONS) do I.pressed[a] = false end
  for k in pairs(navRep) do navRep[k] = false end
end

function I.quitCombo() return I.down.start and I.down.select end

return I
