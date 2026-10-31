-- RG Fencing - LÖVE configuration
-- Target: Anbernic RG34XXSP (720x480, Allwinner H700, Mali-G31), muOS or PortMaster.

function love.conf(t)
  t.identity = "rgfencing"
  t.version = "11.4"           -- runs on 11.4 and 11.5 (PortMaster ships 11.5)
  t.console = false
  t.accelerometerjoystick = false
  t.gammacorrect = false

  t.window.title = "RG Fencing"
  t.window.width = 720
  t.window.height = 480
  t.window.resizable = true
  t.window.minwidth = 240
  t.window.minheight = 160
  t.window.fullscreen = false
  t.window.vsync = 1
  t.window.msaa = 0            -- pixel art: no anti-aliasing anywhere
  t.window.highdpi = false

  t.modules.physics = false    -- all movement is hand-written
  t.modules.video = false
  t.modules.touch = false

  -- Headless AI-vs-AI self-test: `love . --autotest 20`
  local headless = false
  if type(arg) == "table" then
    for _, a in ipairs(arg) do
      if a == "--autotest" then headless = true end
    end
  end
  if headless then
    t.window = false
    t.modules.graphics = false
    t.modules.audio = false
  end
end
