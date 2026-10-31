-- Controller: turns a pad (real or virtual) into fencer commands.
--
-- A pad is { down = {...}, pressed = {...} } over the button names of
-- src/input.lua. The human's pad comes from the input module; the AI and
-- the training coaches fill a virtual pad with the same buttons, so every
-- fencer is driven through exactly the same code.
--
--   ←/→   footwork (towards the opponent = advance)
--   ↑/↓   high / low line (while the arm goes out: change the attack line)
--   A     lunge (hold to stay in the lunge: remise)
--   B     parry in the line (beat, if their blade is still)
--   X     extend the arm (hold: point in line)
--   Y     flèche
--   R1/L1 balestra (jump forward) / jump back

local C = {}

C.BUTTONS = { "left", "right", "up", "down", "a", "b", "x", "y", "l1", "r1" }

function C.newPad()
  return { down = {}, pressed = {} }
end

function C.apply(f, pad)
  local d, p = pad.down, pad.pressed
  local fwdK = f.face > 0 and "right" or "left"
  local backK = f.face > 0 and "left" or "right"
  local fwd, back = d[fwdK], d[backK]
  f.wantDir = (fwd and not back) and 1 or (back and not fwd) and -1 or 0
  if p[fwdK] and f.legs == "lunge" then f.fwdAfterLunge = true end
  f.holdA = d.a and true or false
  f.holdX = d.x and true or false

  if p.up then f:lineInput("high") elseif p.down then f:lineInput("low") end
  local line = d.up and "high" or d.down and "low" or f.line

  if p.a then f:queue("lunge", line)
  elseif p.x then f:queue("extend", line)
  elseif p.b then f:queue("blade", line)
  elseif p.y then f:queue("fleche", line)
  elseif p.r1 then f:queue("jump", 1)
  elseif p.l1 then f:queue("jump", -1)
  end
end

-- Out of play: nobody is pressing anything.
function C.idle(f)
  f.wantDir = 0
  f.holdA = false
  f.holdX = false
  f.cmd = nil
end

-- The human player's pad, read from src/input.lua. "pressed" is only
-- reported on the first simulation sub-step of a frame.
function C.human(input)
  local h = { pad = C.newPad() }
  function h:get(_, _, _, first)
    local pad = self.pad
    for _, b in ipairs(C.BUTTONS) do
      pad.down[b] = input.down[b]
      pad.pressed[b] = first and input.pressed[b] or false
    end
    return pad
  end
  return h
end

return C
