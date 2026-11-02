-- How to play: the controls card and the rules, page by page.

local core = require("src.core")
local gfx = require("src.gfx")
local input = require("src.input")
local audio = require("src.audio")

local C = core.C
local W, H = core.W, core.H

local Help = {}

Help.CONTROLS = {
  { "←→", "ADVANCE / RETREAT" },
  { "↑↓", "HIGH / LOW LINE" },
  { "A", "LUNGE (HOLD: STAY IN IT)" },
  { "B", "PARRY IN YOUR LINE / BEAT" },
  { "X", "EXTEND (HOLD: POINT IN LINE)" },
  { "Y", "FLÈCHE" },
  { "R1", "BALESTRA (JUMP FORWARD)" },
  { "L1", "JUMP BACK" },
  { "START", "PAUSE" },
}

local function controlRows(x, y, rows)
  for k, c in ipairs(rows or Help.CONTROLS) do
    local yy = y + (k - 1) * 11
    if c[1] == "←→" or c[1] == "↑↓" then
      core.color(C.ink)
      gfx.rect(x, yy - 1, 15, 11)
      core.color(C.dim)
      gfx.rect(x + 1, yy, 13, 9)
      gfx.text(c[1], x + 8, yy + 1, C.ink, "center")
    else
      gfx.button(c[1], x, yy)
    end
    gfx.text(c[2], x + 34, yy + 1, C.text)
  end
end

function Help.drawControls(rows)
  core.color(C.ink, 0.7)
  gfx.rect(0, 0, W, H)
  gfx.panel(20, 14, W - 40, H - 28)
  gfx.text("CONTROLS", W / 2, 19, C.yellow, "center")
  controlRows(30, 31, rows)
  gfx.text("SELECT + START QUITS THE GAME", W / 2, H - 22, C.dim, "center")
end

Help.PAGES = {
  { title = "CONTROLS", controls = true },
  { title = "THE TARGET", text = {
    "In foil only the trunk counts: the metallic vest (the lamé) you can see on each fencer.",
    "A hit on the trunk lights your colour: RED on the left, GREEN on the right. A hit on the mask or the legs lights WHITE: the phrase stops and nobody scores.",
    "After the first hit the box gives the other fencer 0.3 s to land too. Then it locks out.",
  } },
  { title = "RIGHT OF WAY", text = {
    "One light: that touch counts, whoever made it.",
    "Two lights: the referee gives the touch to the fencer with PRIORITY.",
    "The first to start an attack has priority: arm extending, point threatening the target. Stepping forward is only preparation. Attack into it!",
    "Attacks started together are SIMULTANEOUS: no touch.",
  } },
  { title = "TAKING PRIORITY", text = {
    "PARRY the attack (B in the line it comes in) and the priority is yours: riposte at once with X, or A if they are far.",
    "An attack that falls short or is parried has lost priority. Holding the lunge (a remise) does not get it back.",
    "BEAT their blade (B when the blades cross) to take priority, then attack.",
    "POINT IN LINE: extend (hold X) before they attack. They must beat your blade first.",
  } },
  { title = "THE PISTE AND TIME", text = {
    "The piste is 14 m long. You start behind your en-garde line, 2 m from the centre. The last 2 m before each end line is the warning zone.",
    "Cross your own end line with both feet and you concede a touch. Body contact (corps-à-corps) halts the bout.",
    "Bouts to 5 last 3 minutes. Bouts to 15 have three periods, with a break at 8. A tie at time goes to a priority minute.",
  } },
  { title = "TACTICAL BOUT", text = {
    "You move live. Press A to attack: the bout stops and you choose how. When they attack, choose a defence; after a parry, the riposte and the answer.",
    "The choices beat each other like a wheel: the parry stops the direct attack, the disengage and the feint deceive the parry, the counterattack beats the feint, the direct attack and the beat beat the counterattack.",
    "Distance and ratings count too: training drills raise yours.",
  } },
  { title = "WHEEL BOUT", text = {
    "Press A to move first, or wait for them. The bout stops and you both pick one of five actions: theirs is already chosen.",
    "DIRECT beats FEINT and BEAT. FEINT beats PARRY and BEAT. PARRY beats DIRECT and LINE. LINE beats DIRECT and FEINT. BEAT beats LINE and PARRY.",
    "The same pick: no touch. Distance and ratings don't count.",
  } },
  { title = "TIPS", text = {
    "Keep just outside their lunge. The distance at the bottom turns yellow, then orange, when a lunge can reach.",
    "The orange arrow shows the line of an incoming attack. A parry in your own guard line lasts longer.",
    "Attack the line they don't guard. Switch line (up/down) during your lunge to slip past a parry.",
    "Retreat to make their lunge fall short, then attack as they recover.",
  } },
}

-- How-to-play scene.
function Help.scene(app, back)
  local s = { page = 1 }
  function s:update()
    if input.nav("right") or input.pressed.a then
      if self.page < #Help.PAGES then
        self.page = self.page + 1
        audio.play("blip", 0.4)
      elseif input.pressed.a then
        audio.play("back", 0.4); back()
      end
    elseif input.nav("left") and self.page > 1 then
      self.page = self.page - 1
      audio.play("blip", 0.4)
    elseif input.pressed.b or input.pressed.start then
      audio.play("back", 0.4)
      back()
    end
  end
  function s:draw()
    core.color(C.night)
    gfx.rect(0, 0, W, H)
    local p = Help.PAGES[self.page]
    gfx.panel(8, 6, W - 16, H - 12)
    gfx.text(p.title, W / 2, 11, C.yellow, "center")
    gfx.text(self.page .. "/" .. #Help.PAGES, W - 14, 11, C.dim, "right")
    if p.controls then
      controlRows(28, 26)
    else
      local y = 25
      for _, para in ipairs(p.text) do
        y = y + gfx.para(para, 16, y, W - 32, C.text, 9) + 4
      end
    end
    gfx.hints({ { "◄►", "PAGE" }, { "B", "BACK" } }, W / 2, H - 19, "center")
  end
  return s
end

return Help
