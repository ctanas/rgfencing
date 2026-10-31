-- RG Fencing: a pixel-art foil fencing game for small Linux handhelds.
--
-- Rendering: everything is drawn into a 240x160 canvas with nearest
-- filtering, then scaled x3 to fill the RG34XXSP's 720x480 panel (fitted
-- with the largest whole scale on other screens).
--
-- Developer flags:
--   --autotest N            headless: AI-vs-AI bouts, N per pairing
--   --shot NAME --mode M    render scene M after --time S seconds and save
--     [--time S] [--seed N]   NAME.png (720x480) to the save directory
--   --windowed / --fullscreen

local core = require("src.core")
local settings = require("src.settings")
local input = require("src.input")
local audio = require("src.audio")
local Profile = require("src.profile")

local lg = love.graphics
local gfx

local app = {}
local scene
local canvas
local shot

local function hasArg(args, name)
  for _, a in ipairs(args) do if a == name then return true end end
  return false
end

local function argValue(args, name)
  for i, a in ipairs(args) do if a == name then return args[i + 1] end end
  return nil
end

-- A "WxH" argument (passed by the muOS launcher) gives the screen size.
local function resolutionArg(args)
  for _, a in ipairs(args) do
    local w, h = tostring(a):match("^(%d+)x(%d+)$")
    if w then return tonumber(w), tonumber(h) end
  end
end

local function setupWindow(args)
  local device = os.getenv("RGFENCING_DEVICE") == "1" or hasArg(args, "--fullscreen")
  local dw, dh = love.window.getDesktopDimensions()
  if dw <= 1024 and dh <= 768 then device = true end
  local rw, rh = resolutionArg(args)
  if rw then device = true end
  if hasArg(args, "--windowed") or shot then device = false end
  core.device = device
  if device and rw then
    love.window.setMode(rw, rh, { vsync = 1 })
    love.mouse.setVisible(false)
  elseif device then
    love.window.setMode(0, 0, { fullscreen = true, fullscreentype = "desktop", vsync = 1 })
    love.mouse.setVisible(false)
  elseif shot then
    love.window.setMode(core.W * 3, core.H * 3, { vsync = 0 })
  else
    local s = math.max(1, math.floor(math.min((dw - 80) / core.W, (dh - 120) / core.H)))
    s = math.min(s, 4)
    love.window.setMode(core.W * s, core.H * s, { resizable = true, vsync = 1, minwidth = core.W, minheight = core.H })
  end
end

---------------------------------------------------------------------------
-- Scenes
---------------------------------------------------------------------------

function app.set(s)
  scene = s
  input.consume()
end

function app.current() return scene end

function app.toTitle(sub)
  if not Profile.current() then
    require("src.profiles_ui").firstRun(app, function() app.toTitle() end)
    return
  end
  app.set(require("src.title").new(app, sub))
end

function love.load(args)
  args = args or {}
  love.math.setRandomSeed(os.time())
  settings.load()
  settings.sanitize()

  if hasArg(args, "--autotest") then
    io.stdout:setvbuf("no")
    core.testMode = true
    require("src.autotest").run(argValue(args, "--autotest"))
    love.event.quit()
    return
  end

  if hasArg(args, "--smoke") then core.testMode = true end
  local shotName = argValue(args, "--shot")
  if shotName then
    core.testMode = true
    shot = {
      name = shotName,
      mode = argValue(args, "--mode") or "title",
      frames = math.floor((tonumber(argValue(args, "--time")) or 1) * 60),
      args = args,
    }
    love.math.setRandomSeed(tonumber(argValue(args, "--seed")) or 1)
    -- dev runs: report errors on the terminal and exit, never block on
    -- LÖVE's error screen
    love.errorhandler = function(msg)
      print("ERROR: " .. tostring(msg) .. "\n" .. debug.traceback())
      os.exit(1)
    end
  end

  if shot then
    Profile.useSample("ALEX", "FRA")
  else
    Profile.load()
  end
  setupWindow(args)
  lg.setDefaultFilter("nearest", "nearest")
  gfx = require("src.gfx")
  gfx.init()
  require("src.art").init()
  canvas = lg.newCanvas(core.W, core.H)
  canvas:setFilter("nearest", "nearest")
  input.init(settings.data.swapab)
  audio.init(settings.data.sound and not shot, settings.data.crowd)

  if shot then
    require("src.shots").start(app, shot)
  else
    app.toTitle()
  end
  if hasArg(args, "--smoke") then require("src.smoke").install(app) end
end

function love.update(dt)
  if shot then dt = 1 / 60 end
  dt = math.min(dt, 1 / 20)
  core.time = core.time + dt
  input.update(dt)
  if input.quitCombo() then
    love.event.quit()
    return
  end
  if scene then scene:update(dt) end
end

function love.draw()
  lg.setCanvas(canvas)
  lg.clear(core.C.night[1], core.C.night[2], core.C.night[3], 1)
  lg.setColor(1, 1, 1, 1)
  if scene then scene:draw() end
  if settings.data.fps then
    gfx.text(string.format("%d FPS", love.timer.getFPS()), core.W - 2, core.H - 9, core.C.yellow, "right", true)
  end
  lg.setCanvas()
  if shot and shot.film then shot.film(canvas) end
  lg.clear(0, 0, 0, 1)
  lg.setColor(1, 1, 1, 1)

  local ww, wh = lg.getDimensions()
  local s = math.min(ww / core.W, wh / core.H)
  -- whole-number scale when it fills most of the screen, else exact fit
  if math.floor(s) >= 1 and math.floor(s) / s > 0.85 then s = math.floor(s) end
  local ox, oy = math.floor((ww - core.W * s) / 2), math.floor((wh - core.H * s) / 2)
  lg.draw(canvas, ox, oy, 0, s, s)

  if shot then
    shot.frames = shot.frames - 1
    if shot.frames <= 0 then
      local file = shot.name .. ".png"
      if shot.filmDone then
        shot.filmDone()
        print("saved " .. love.filesystem.getSaveDirectory() .. "/" .. file)
        love.event.quit()
      else
        lg.captureScreenshot(function(img)
          img:encode("png", file)
          print("saved " .. love.filesystem.getSaveDirectory() .. "/" .. file)
          love.event.quit()
        end)
      end
      shot.frames = math.huge
    end
  end
end

function love.joystickadded() input.refresh() end
function love.joystickremoved() input.refresh() end

function love.quit()
  if not core.testMode then settings.save() end
end
