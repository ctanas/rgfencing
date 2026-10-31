-- Fictional fencers: one name each (as on a fencing scoreboard), common
-- in their country, with the country's FIE code.

local N = {}

local DATA = {
  ITA = "ROSSI FERRARI BIANCHI ROMANO COLOMBO RICCI MARINO GRECO CONTI GALLO",
  FRA = "MARTIN BERNARD DUBOIS THOMAS ROBERT PETIT DURAND LEROY MOREAU GIRARD",
  USA = "SMITH JOHNSON MILLER DAVIS GARCIA WILSON MOORE TAYLOR CLARK LEWIS",
  HUN = "NAGY KOVACS TOTH SZABO HORVATH VARGA KISS MOLNAR NEMETH FARKAS",
  JPN = "SATO SUZUKI TAKAHASHI TANAKA WATANABE ITO YAMAMOTO NAKAMURA KOBAYASHI KATO",
  KOR = "KIM LEE PARK CHOI JUNG KANG CHO YOON JANG LIM",
  CHN = "WANG LI ZHANG LIU CHEN YANG HUANG ZHAO WU ZHOU",
  GER = "MULLER SCHMIDT SCHNEIDER FISCHER WEBER MEYER WAGNER BECKER HOFFMANN SCHULZ",
  POL = "NOWAK KOWALSKI WOJCIK KOWALCZYK KAMINSKI ZIELINSKI SZYMANSKI WOZNIAK MAZUR KRAWCZYK",
  GBR = "JONES WILLIAMS BROWN EVANS WALKER WRIGHT ROBINSON THOMPSON HUGHES EDWARDS",
  EGY = "HASSAN MOHAMED ALI IBRAHIM MAHMOUD SAYED FATHY ADEL SAMIR NASSER",
  CAN = "TREMBLAY GAGNON ROY COTE BOUCHARD GAUTHIER MORIN LAVOIE FORTIN GAGNE",
  BRA = "SILVA SANTOS OLIVEIRA SOUZA RODRIGUES FERREIRA ALVES PEREIRA LIMA GOMES",
  ROU = "POPESCU IONESCU POPA RADU DUMITRU STAN STOICA GHEORGHE MATEI CIOBANU DĂRĂBAN",
  ESP = "GARCIA RODRIGUEZ GONZALEZ FERNANDEZ LOPEZ MARTINEZ SANCHEZ PEREZ GOMEZ RUIZ",
  UKR = "MELNYK SHEVCHENKO KOVALENKO BONDARENKO TKACHENKO KRAVCHENKO OLIINYK SHEVCHUK LYSENKO MOROZ",
}

local function words(s)
  local t = {}
  for w in s:gmatch("%S+") do t[#t + 1] = w end
  return t
end

N.CODES = {}
local LISTS = {}
for code, names in pairs(DATA) do
  N.CODES[#N.CODES + 1] = code
  LISTS[code] = words(names)
end
table.sort(N.CODES)

-- Named rivals who turn up again and again: the top seed of every career
-- competition, and now and then a quick-bout opponent.
N.RIVALS = {
  { last = "DĂRĂBAN", nation = "ROU", style = "balanced" },
}

-- A random fencer: { last = name, nation = code }. `used` (optional) is a
-- set of names to avoid; rng (optional) a love RandomGenerator.
function N.random(_, rng, used)
  local function rand(a, b)
    if rng then return rng:random(a, b) end
    return love.math.random(a, b)
  end
  for _ = 1, 30 do
    local code = N.CODES[rand(1, #N.CODES)]
    local L = LISTS[code]
    local name = L[rand(1, #L)]
    if not used or not used[name] then
      if used then used[name] = true end
      return { last = name, nation = code }
    end
  end
  return { last = "DOE", nation = "USA" }
end

return N
