-- Nations (FIE / IOC codes) and their 9x6 pixel flags.
--
-- Flag specs:
--   "v:c1,c2,c3"      vertical stripes (repeat a colour to widen it)
--   "h:c1,c2,..."     horizontal stripes
--   "nordic:bg,cross[,inner]"   Nordic cross
--   "plus:bg,fg"      a centred cross (Switzerland)
--   "cross:bg,fg"     a full-width cross (Georgia)
--   "disc:bg,fg"      a centred disc
--   "px:legend|row1|row2|..."   hand-pixelled; legend "rRRGGBB,wRRGGBB,..."
--   any spec + "+dot:RRGGBB"    a small emblem in the centre
-- Emblems and stars are simplified: at 9x6 a flag is its colours.

local N = {}

local R, W, B, G, Y, K = "ce1126", "ffffff", "0033a0", "009a44", "fcd116", "000000"

local LIST = {
  { "ALB", "ALBANIA", "h:e41e20+dot:000000" },
  { "ALG", "ALGERIA", "v:006633,ffffff+dot:d21034" },
  { "AND", "ANDORRA", "v:10069f,fedf00,d50032" },
  { "ANG", "ANGOLA", "h:cc092f,000000+dot:ffcb00" },
  { "ARG", "ARGENTINA", "h:74acdf,ffffff,74acdf+dot:f6b40e" },
  { "ARM", "ARMENIA", "h:d90012,0033a0,f2a800" },
  { "AUS", "AUSTRALIA", "px:r" .. "e4002b,w" .. W .. ",b012169|rwrbbbbbb|rrrbbbwbb|rwrbbbbbw|bbbbbbwbb|bwbbbbbbb|bbbbbbwbb" },
  { "AUT", "AUSTRIA", "h:ed2939,ffffff,ed2939" },
  { "AZE", "AZERBAIJAN", "h:0092bc,e4002b,00af66+dot:ffffff" },
  { "BAN", "BANGLADESH", "disc:006a4e,f42a41" },
  { "BEL", "BELGIUM", "v:000000,fdda24,ef3340" },
  { "BIH", "BOSNIA AND HERZEGOVINA", "h:002395+dot:fecb00" },
  { "BLR", "BELARUS", "h:c8313e,c8313e,4aa657" },
  { "BOL", "BOLIVIA", "h:d52b1e,f9e300,007934" },
  { "BRA", "BRAZIL", "px:g009c3b,yffdf00,b002776|ggggygggg|ggyybyygg|gybbbbbyg|gybbbbbyg|ggyybyygg|ggggygggg" },
  { "BUL", "BULGARIA", "h:ffffff,00966e,d62612" },
  { "CAN", "CANADA", "px:rd80621,w" .. W .. "|rrwwwwwrr|rrwwrwwrr|rrwrrrwrr|rrwwrwwrr|rrwwwwwrr|rrwwwwwrr" },
  { "CHI", "CHILE", "px:b0039a6,w" .. W .. ",rd52b1e|bbbwwwwww|bwbwwwwww|bbbwwwwww|rrrrrrrrr|rrrrrrrrr|rrrrrrrrr" },
  { "CHN", "CHINA", "px:rde2910,yffde00|rryrrrrrr|ryyyryrrr|rryrrryrr|rrrrryrrr|rrrrrrrrr|rrrrrrrrr" },
  { "CIV", "CÔTE D'IVOIRE", "v:f77f00,ffffff,009e60" },
  { "CMR", "CAMEROON", "v:007a5e,ce1126,fcd116" },
  { "COL", "COLOMBIA", "h:fcd116,fcd116,003893,ce1126" },
  { "CRC", "COSTA RICA", "h:002b7f,ffffff,ce1126,ce1126,ffffff,002b7f" },
  { "CRO", "CROATIA", "h:ff0000,ffffff,171796+dot:ff0000" },
  { "CUB", "CUBA", "px:b002a8f,w" .. W .. ",rcf142b|rbbbbbbbb|rrwwwwwww|rwrbbbbbb|rwrbbbbbb|rrwwwwwww|rbbbbbbbb" },
  { "CYP", "CYPRUS", "h:ffffff+dot:d57800" },
  { "CZE", "CZECHIA", "px:b11457e,w" .. W .. ",rd7141a|bwwwwwwww|bbwwwwwww|bbbwwwwww|bbbrrrrrr|bbrrrrrrr|brrrrrrrr" },
  { "DEN", "DENMARK", "nordic:c8102e,ffffff" },
  { "DOM", "DOMINICAN REPUBLIC", "px:b002d62,w" .. W .. ",rce1126|bbbbwrrrr|bbbbwrrrr|wwwwwwwww|rrrrwbbbb|rrrrwbbbb|rrrrwbbbb" },
  { "ECU", "ECUADOR", "h:ffd100,ffd100,0072ce,ef3340+dot:6b3a1e" },
  { "EGY", "EGYPT", "h:ce1126,ffffff,000000+dot:c09300" },
  { "ESA", "EL SALVADOR", "h:0047ab,ffffff,0047ab" },
  { "ESP", "SPAIN", "h:aa151b,f1bf00,f1bf00,aa151b" },
  { "EST", "ESTONIA", "h:0072ce,000000,ffffff" },
  { "FIN", "FINLAND", "nordic:ffffff,002f6c" },
  { "FRA", "FRANCE", "v:0055a4,ffffff,ef4135" },
  { "GBR", "GREAT BRITAIN", "px:b012169,w" .. W .. ",rc8102e|rwbwrwbwr|brwwrwwrb|rrrrrrrrr|rrrrrrrrr|brwwrwwrb|rwbwrwbwr" },
  { "GEO", "GEORGIA", "cross:ffffff,ff0000" },
  { "GER", "GERMANY", "h:000000,dd0000,ffce00" },
  { "GHA", "GHANA", "h:ce1126,fcd116,006b3f+dot:000000" },
  { "GRE", "GREECE", "px:b0d5eb6,w" .. W .. "|bwbbbbbbb|wwwwwwwww|bwbbbbbbb|wwwwwwwww|bbbbbbbbb|wwwwwwwww" },
  { "GUA", "GUATEMALA", "v:4997d0,ffffff,4997d0" },
  { "HKG", "HONG KONG, CHINA", "h:de2910+dot:ffffff" },
  { "HON", "HONDURAS", "h:0073cf,ffffff,0073cf" },
  { "HUN", "HUNGARY", "h:ce2939,ffffff,477050" },
  { "INA", "INDONESIA", "h:ff0000,ffffff" },
  { "IND", "INDIA", "h:ff9933,ffffff,138808+dot:000080" },
  { "IRI", "IRAN", "h:239f40,ffffff,da0000+dot:da0000" },
  { "IRL", "IRELAND", "v:169b62,ffffff,ff883e" },
  { "IRQ", "IRAQ", "h:ce1126,ffffff,000000+dot:007a3d" },
  { "ISL", "ICELAND", "nordic:02529c,ffffff,dc1e35" },
  { "ISR", "ISRAEL", "px:b0038b8,w" .. W .. "|wwwwwwwww|bbbbbbbbb|wwwwbwwww|wwwbwbwww|bbbbbbbbb|wwwwwwwww" },
  { "ITA", "ITALY", "v:009246,ffffff,ce2b37" },
  { "JAM", "JAMAICA", "px:yfed100,g009b3a,k" .. K .. "|ygggggggy|kyggggyyk|kkyyyyykk|kkyyyyykk|kyggggyyk|ygggggggy" },
  { "JOR", "JORDAN", "px:rce1126,k" .. K .. ",w" .. W .. ",g007a3d|rkkkkkkkk|rrkkkkkkk|rrrwwwwww|rrrwwwwww|rrggggggg|rgggggggg" },
  { "JPN", "JAPAN", "disc:ffffff,bc002d" },
  { "KAZ", "KAZAKHSTAN", "h:00afca+dot:fec50c" },
  { "KEN", "KENYA", "h:000000,bb0000,006600+dot:ffffff" },
  { "KGZ", "KYRGYZSTAN", "h:e8112d+dot:ffef00" },
  { "KOR", "KOREA", "px:w" .. W .. ",k" .. K .. ",rcd2e3a,b0047a0|kwwwwwwwk|wkwrrrwkw|wwrrrrrww|wwbbbbbww|wkwbbbwkw|kwwwwwwwk" },
  { "KSA", "SAUDI ARABIA", "h:006c35+dot:ffffff" },
  { "KUW", "KUWAIT", "px:k" .. K .. ",g007a3d,w" .. W .. ",rce1126|kkggggggg|kkggggggg|kkkwwwwww|kkkwwwwww|kkrrrrrrr|kkrrrrrrr" },
  { "LAT", "LATVIA", "h:9e3039,9e3039,ffffff,9e3039,9e3039" },
  { "LBN", "LEBANON", "h:ed1c24,ffffff,ffffff,ed1c24+dot:00a651" },
  { "LTU", "LITHUANIA", "h:fdb913,006a44,c1272d" },
  { "LUX", "LUXEMBOURG", "h:ed2939,ffffff,00a1de" },
  { "MAR", "MOROCCO", "h:c1272d+dot:006233" },
  { "MAS", "MALAYSIA", "px:b010066,yffcc00,rcc0001,w" .. W .. "|bbbbrrrrr|bybbwwwww|bbbbrrrrr|wwwwwwwww|rrrrrrrrr|wwwwwwwww" },
  { "MDA", "MOLDOVA", "v:0046ae,ffd200,cc092f+dot:8a5a2b" },
  { "MEX", "MEXICO", "v:006847,ffffff,ce1126+dot:8c6b3a" },
  { "MGL", "MONGOLIA", "v:c4272f,015197,c4272f" },
  { "MKD", "NORTH MACEDONIA", "h:d20000+dot:ffe600" },
  { "MLT", "MALTA", "v:ffffff,cf142b" },
  { "MON", "MONACO", "h:ce1126,ffffff" },
  { "NCA", "NICARAGUA", "h:0067c6,ffffff,0067c6" },
  { "NED", "NETHERLANDS", "h:ae1c28,ffffff,21468b" },
  { "NGR", "NIGERIA", "v:008751,ffffff,008751" },
  { "NOR", "NORWAY", "nordic:ba0c2f,ffffff,00205b" },
  { "NZL", "NEW ZEALAND", "px:r" .. "c8102e,w" .. W .. ",b012169|rwrbbbbbb|rrrbbbrbb|rwrbbbbbr|bbbbbbbbb|bbbbbbrbb|bbbbbbbbb" },
  { "PAN", "PANAMA", "px:w" .. W .. ",b005293,rd21034|wbwwrrrrr|wwwwrrrrr|wwwwrrrrr|bbbbwwwww|bbbbwwrww|bbbbwwwww" },
  { "PAR", "PARAGUAY", "h:d52b1e,ffffff,0038a8" },
  { "PER", "PERU", "v:d91023,ffffff,d91023" },
  { "PHI", "PHILIPPINES", "px:w" .. W .. ",yfcd116,b0038a8,rce1126|wbbbbbbbb|wwbbbbbbb|wywbbbbbb|wwwrrrrrr|wwrrrrrrr|wrrrrrrrr" },
  { "POL", "POLAND", "h:ffffff,dc143c" },
  { "POR", "PORTUGAL", "px:g006600,rff0000,yffcc00|ggggrrrrr|ggggrrrrr|gggyyrrrr|gggyyrrrr|ggggrrrrr|ggggrrrrr" },
  { "PUR", "PUERTO RICO", "px:b0050f0,w" .. W .. ",red0000|brrrrrrrr|bbwwwwwww|bwbrrrrrr|bwbrrrrrr|bbwwwwwww|brrrrrrrr" },
  { "QAT", "QATAR", "v:ffffff,8d1b3d,8d1b3d" },
  { "ROU", "ROMANIA", "v:002b7f,fcd116,ce1126" },
  { "RSA", "SOUTH AFRICA", "px:yffb81c,g007749,w" .. W .. ",re03c31,k" .. K .. ",b001489|ygwrrrrrr|kygwwwwww|kkygggggg|kkygggggg|kygwwwwww|ygwbbbbbb" },
  { "RUS", "RUSSIA", "h:ffffff,0039a6,d52b1e" },
  { "SEN", "SENEGAL", "v:00853f,fdef42,e31b23+dot:00853f" },
  { "SGP", "SINGAPORE", "h:ef3340,ffffff" },
  { "SLO", "SLOVENIA", "h:ffffff,0000ff,ff0000" },
  { "SMR", "SAN MARINO", "h:ffffff,5eb6e4" },
  { "SRB", "SERBIA", "h:c6363c,0c4076,ffffff" },
  { "SUI", "SWITZERLAND", "plus:da291c,ffffff" },
  { "SVK", "SLOVAKIA", "h:ffffff,0b4ea2,ee1c25+dot:ee1c25" },
  { "SWE", "SWEDEN", "nordic:006aa7,fecc00" },
  { "THA", "THAILAND", "h:a51931,f4f5f8,2d2a4a,2d2a4a,f4f5f8,a51931" },
  { "TJK", "TAJIKISTAN", "h:cc0000,ffffff,006600" },
  { "TKM", "TURKMENISTAN", "h:28ae66+dot:ffffff" },
  { "TPE", "CHINESE TAIPEI", "px:b000095,w" .. W .. ",rfe0000|bbbbrrrrr|bwwbrrrrr|bbbbrrrrr|rrrrrrrrr|rrrrrrrrr|rrrrrrrrr" },
  { "TTO", "TRINIDAD AND TOBAGO", "px:k" .. K .. ",w" .. W .. ",rda1a35|kwrrrrrrr|wkwrrrrrr|rwkwrrrrr|rrwkwrrrr|rrrwkwrrr|rrrrwkwrr" },
  { "TUN", "TUNISIA", "h:e70013+dot:ffffff" },
  { "TUR", "TÜRKIYE", "h:e30a17+dot:ffffff" },
  { "UAE", "UNITED ARAB EMIRATES", "px:rff0000,g00732f,w" .. W .. ",k" .. K .. "|rrggggggg|rrggggggg|rrwwwwwww|rrwwwwwww|rrkkkkkkk|rrkkkkkkk" },
  { "UKR", "UKRAINE", "h:0057b7,ffd700" },
  { "URU", "URUGUAY", "px:w" .. W .. ",yfcd116,b0038a8|wywwwwwww|yyybbbbbb|wywwwwwww|bbbbbbbbb|wwwwwwwww|bbbbbbbbb" },
  { "USA", "UNITED STATES", "px:b3c3b6e,w" .. W .. ",rb22234|bwbbrrrrr|bbwbwwwww|bwbbrrrrr|wwwwwwwww|rrrrrrrrr|wwwwwwwww" },
  { "UZB", "UZBEKISTAN", "h:0099b5,ffffff,1eb53a" },
  { "VEN", "VENEZUELA", "h:ffcc00,00247d,cf142b" },
  { "VIE", "VIETNAM", "h:da251d+dot:ffff00" },
}

N.LIST = {}
N.BY = {}
for _, e in ipairs(LIST) do
  local n = { code = e[1], name = e[2], spec = e[3] }
  N.LIST[#N.LIST + 1] = n
  N.BY[n.code] = n
end
table.sort(N.LIST, function(a, b) return a.name < b.name end)
for i, n in ipairs(N.LIST) do n.index = i end

function N.name(code)
  local n = code and N.BY[code]
  return n and n.name or ""
end

local function hex(s)
  return { tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255 }
end

local FW, FH = 9, 6

-- The flag as a 9x6 grid of colours.
local function grid(spec)
  local dot
  spec = spec:gsub("%+dot:(%x+)", function(c) dot = c; return "" end)
  local kind, body = spec:match("^(%a+):(.*)$")
  local g = {}
  for y = 1, FH do g[y] = {} end
  local function fill(c)
    for y = 1, FH do for x = 1, FW do g[y][x] = c end end
  end
  local cols = {}
  if kind ~= "px" then for c in body:gmatch("%x+") do cols[#cols + 1] = c end end
  if kind == "v" then
    for x = 1, FW do
      local k = math.min(#cols, math.floor((x - 1) * #cols / FW) + 1)
      for y = 1, FH do g[y][x] = cols[k] end
    end
  elseif kind == "h" then
    for y = 1, FH do
      local k = math.min(#cols, math.floor((y - 1) * #cols / FH) + 1)
      for x = 1, FW do g[y][x] = cols[k] end
    end
  elseif kind == "nordic" then
    fill(cols[1])
    local wide = cols[3] and 1 or 0
    for y = 1, FH do for x = 3, 4 + wide do g[y][x] = cols[2] end end
    for x = 1, FW do for y = 3, 4 + wide do g[y][x] = cols[2] end end
    if cols[3] then
      for y = 1, FH do g[y][4] = cols[3] end
      for x = 1, FW do g[4][x] = cols[3] end
    end
  elseif kind == "plus" then
    fill(cols[1])
    for y = 2, 5 do g[y][5] = cols[2] end
    for x = 3, 7 do g[3][x], g[4][x] = cols[2], cols[2] end
  elseif kind == "cross" then
    fill(cols[1])
    for y = 1, FH do g[y][5] = cols[2] end
    for x = 1, FW do g[3][x], g[4][x] = cols[2], cols[2] end
  elseif kind == "disc" then
    fill(cols[1])
    for _, p in ipairs({ { 5, 2 }, { 4, 3 }, { 5, 3 }, { 6, 3 }, { 4, 4 }, { 5, 4 }, { 6, 4 }, { 5, 5 } }) do
      g[p[2]][p[1]] = cols[2]
    end
  elseif kind == "px" then
    local parts = {}
    for part in body:gmatch("[^|]+") do parts[#parts + 1] = part end
    local legend = {}
    for item in parts[1]:gmatch("[^,]+") do legend[item:sub(1, 1)] = item:sub(2) end
    for y = 1, FH do
      local row = parts[y + 1] or ""
      for x = 1, FW do g[y][x] = legend[row:sub(x, x)] or "888888" end
    end
  else
    fill("888888")
  end
  if dot then g[3][5], g[4][5] = dot, dot end
  return g
end

local cache = {}

-- Flags are built for the current resolution: each flag pixel is 1, 2 or
-- 4 canvas pixels, inside a 1-pixel ink border (2 at 720x480).
local function cell()
  local S = require("src.core").S
  if S >= 3 then return 4, 2 elseif S > 1 then return 2, 1 end
  return 1, 1
end

function N.clearCache() cache = {} end

function N.flag(code)
  if cache[code] ~= nil then return cache[code] or nil end
  local n = N.BY[code]
  if not n or not love.graphics then cache[code] = false; return nil end
  local g = grid(n.spec)
  local c, b = cell()
  local w, h = FW * c + 2 * b, FH * c + 2 * b
  local img = love.image.newImageData(w, h)
  local ink = require("src.core").C.ink
  for y = 0, h - 1 do
    for x = 0, w - 1 do img:setPixel(x, y, ink[1], ink[2], ink[3], 1) end
  end
  for y = 1, FH do
    for x = 1, FW do
      local col = hex(g[y][x])
      for yy = 0, c - 1 do
        for xx = 0, c - 1 do
          img:setPixel(b + (x - 1) * c + xx, b + (y - 1) * c + yy, col[1], col[2], col[3], 1)
        end
      end
    end
  end
  local im = love.graphics.newImage(img)
  im:setFilter("nearest", "nearest")
  cache[code] = im
  return im
end

-- Draw a flag with its top-left at design (x, y), at a whole-number
-- scale; returns its width in design units (0 if none).
function N.drawFlag(code, x, y, scale)
  local im = code and N.flag(code)
  if not im then return 0 end
  local gfx = require("src.gfx")
  gfx.img(im, x, y, scale or 1)
  return im:getWidth() * (scale or 1) / gfx.S
end

-- A flag's width in design units.
function N.flagW()
  local c, b = cell()
  return (FW * c + 2 * b) / require("src.core").S
end

return N
