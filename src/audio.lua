-- Procedural audio: every sound is synthesised at start-up, so the game
-- ships with no asset files.
--
--   clash/parry/beat  steel on steel: inharmonic partials with fast decays
--   buzz              the scoring box: a harsh two-tone square buzzer
--   step/stomp        feet on the metal piste
--   swish             the blade through the air
--   cheer/murmur      the crowd: band-passed noise "voices" plus claps

local A = { enabled = true, crowd = true, ok = false }

local RATE = 22050
local src = {}
local murmurVol = 0

local floor, sin, exp, abs, pi, min = math.floor, math.sin, math.exp, math.abs, math.pi, math.min

local function toSoundData(buf, n, gain)
  local peak = 1e-6
  for i = 0, n - 1 do
    local v = abs(buf[i]); if v > peak then peak = v end
  end
  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  local k = gain / peak
  for i = 0, n - 1 do sd:setSample(i, buf[i] * k) end
  return sd
end

local function render(seconds, fn, gain)
  local n = floor(seconds * RATE)
  local buf = {}
  for i = 0, n - 1 do buf[i] = fn(i / RATE, i) end
  return toSoundData(buf, n, gain or 0.8)
end

-- Steel ring: partials (Hz) with decay rates, plus a click of noise.
local function metal(seconds, partials, decays, click)
  local rnd = love.math.random
  local ph = {}
  for k = 1, #partials do ph[k] = rnd() * 2 * pi end
  return render(seconds, function(t)
    local v = 0
    for k = 1, #partials do
      v = v + sin(2 * pi * partials[k] * t + ph[k]) * exp(-t * decays[k]) / k ^ 0.4
    end
    if t < 0.006 then v = v + (rnd() * 2 - 1) * click * (1 - t / 0.006) end
    return v * min(1, t * 4000)
  end, 0.75)
end

-- Two-pole resonant band-pass, for crowd voices.
local function bandNoise(n, f, q, out, gain, env)
  local rnd = love.math.random
  local w = 2 * sin(pi * f / RATE)
  local low, band = 0, 0
  for i = 0, n - 1 do
    local x = rnd() * 2 - 1
    low = low + w * band
    local high = x - low - q * band
    band = band + w * high
    out[i] = out[i] + band * gain * env(i / RATE)
  end
end

local function crowd(seconds, swell)
  local rnd = love.math.random
  local n = floor(seconds * RATE)
  local buf = {}
  for i = 0, n - 1 do buf[i] = 0 end
  for _ = 1, 9 do
    local f = 300 + rnd() * 900
    local rate, phase = 1.5 + rnd() * 3, rnd() * 6
    local start = swell and rnd() * 0.15 or 0
    bandNoise(n, f, 0.35, buf, 0.25, function(t)
      local a = 0.6 + 0.4 * sin(t * rate + phase)
      if swell then
        local rise = min(1, (t - start) / 0.12)
        if rise < 0 then return 0 end
        return a * rise * exp(-t * 0.9)
      end
      return a
    end)
  end
  if swell then
    -- claps
    for _ = 1, 70 do
      local at = floor((0.1 + rnd() * (seconds - 0.4)) * RATE)
      local len = floor(0.012 * RATE)
      local g = 0.5 * exp(-(at / RATE) * 1.2)
      for i = 0, len - 1 do
        if at + i < n then buf[at + i] = buf[at + i] + (rnd() * 2 - 1) * g * (1 - i / len) end
      end
    end
  else
    -- seamless loop: crossfade the tail into the head
    local f = floor(0.3 * RATE)
    for i = 0, f - 1 do
      local t = i / f
      buf[i] = buf[i] * t + buf[n - f + i] * (1 - t)
    end
    n = n - f
  end
  return toSoundData(buf, n, swell and 0.85 or 0.6)
end

local function build()
  local rnd = love.math.random
  local sd = {}
  sd.clash = metal(0.35, { 2730, 4210, 5890, 7650 }, { 9, 12, 16, 20 }, 0.8)
  sd.parry = metal(0.55, { 1630, 2470, 3720, 5150, 6900 }, { 6, 8, 10, 13, 18 }, 1.0)
  sd.beat = metal(0.22, { 2210, 3480, 5120 }, { 18, 24, 30 }, 0.9)
  local lp1, lp2 = 0, 0
  sd.swish = render(0.18, function(t)
    local f = 0.05 + 0.5 * (t / 0.18)
    lp1 = lp1 + ((rnd() * 2 - 1) - lp1) * f
    lp2 = lp2 + (lp1 - lp2) * f
    return (lp1 - lp2) * sin(pi * t / 0.18) ^ 2
  end, 0.6)
  local lpS = 0
  sd.step = render(0.09, function(t)
    lpS = lpS + ((rnd() * 2 - 1) - lpS) * 0.15
    return (lpS * 1.5 + sin(2 * pi * 95 * t) * 0.6 + sin(2 * pi * 1900 * t) * 0.05) * exp(-t * 45)
  end, 0.7)
  local lpT = 0
  sd.stomp = render(0.18, function(t)
    lpT = lpT + ((rnd() * 2 - 1) - lpT) * 0.1
    return (lpT * 2 + sin(2 * pi * 70 * t) * 0.8 + sin(2 * pi * 1450 * t) * 0.08 * exp(-t * 30)) * exp(-t * 22)
  end, 0.85)
  sd.buzz = render(0.75, function(t)
    local a = (sin(2 * pi * 233 * t) > 0) and 1 or -1
    local b = (sin(2 * pi * 349 * t) > 0) and 1 or -1
    local env = min(1, t * 300) * min(1, (0.75 - t) * 40)
    return (a * 0.55 + b * 0.35) * env
  end, 0.5)
  sd.blip = render(0.04, function(t) return sin(2 * pi * 1500 * t) * (1 - t / 0.04) end, 0.5)
  sd.select = render(0.12, function(t)
    local f = t < 0.05 and 988 or 1319
    return sin(2 * pi * f * t) * (1 - t / 0.12)
  end, 0.55)
  sd.back = render(0.1, function(t) return sin(2 * pi * (700 - 2000 * t) * t) * (1 - t / 0.1) end, 0.5)
  sd.fanfare = render(1.3, function(t)
    local v = 0
    local notes = { 523.25, 659.25, 783.99, 1046.5 }
    for k, f in ipairs(notes) do
      local st = (k - 1) * 0.11
      if t >= st then
        local x = t - st
        v = v + (sin(2 * pi * f * x) + 0.3 * sin(4 * pi * f * x)) * exp(-x * 3.5)
      end
    end
    return v
  end, 0.6)
  sd.cheer = crowd(2.4, true)
  sd.murmur = crowd(4.0, false)
  return sd
end

function A.init(enabled, crowdOn)
  A.enabled = enabled ~= false
  A.crowd = crowdOn ~= false
  if not love.audio or not love.sound then return end
  local ok, sd = pcall(build)
  if not ok then
    print("audio disabled: " .. tostring(sd))
    return
  end
  for name, data in pairs(sd) do src[name] = love.audio.newSource(data, "static") end
  src.murmur:setLooping(true)
  A.ok = true
end

function A.setEnabled(on)
  A.enabled = on
  if not on and A.ok then love.audio.stop() end
end

function A.play(name, vol, pitch)
  if not (A.ok and A.enabled) then return end
  if (name == "cheer") and not A.crowd then return end
  local s = src[name]
  if not s then return end
  s:stop()
  s:setVolume(vol or 0.7)
  s:setPitch(pitch or 1)
  s:play()
end

-- Background crowd murmur, faded in during bouts.
function A.ambience(level, dt)
  if not A.ok then return end
  local target = (A.enabled and A.crowd) and level or 0
  murmurVol = murmurVol + (target - murmurVol) * min(1, dt * 2)
  local m = src.murmur
  if murmurVol > 0.003 then
    m:setVolume(murmurVol)
    if not m:isPlaying() then m:play() end
  elseif m:isPlaying() then
    m:pause()
  end
end

return A
