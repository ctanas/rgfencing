-- Languages: English (the text in the code) and Romanian.
--
-- Every string drawn through src/gfx.lua is looked up in the language's
-- table (src/lang_ro.lua), keyed by the English text, so static text needs
-- nothing more. Text built at run time goes through I.f with a template
-- ("%s ATTACKS!"), and the parts that are words go through I.tr first.

local I = { lang = 1 }

I.NAMES = { "ENGLISH", "ROMÂNĂ" }

local RO

function I.set(n)
  I.lang = (n == 2) and 2 or 1
  if I.lang == 2 and not RO then RO = require("src.lang_ro") end
end

function I.tr(s)
  if I.lang == 2 and s then return RO[s] or s end
  return s
end

function I.f(fmt, ...)
  return string.format(I.tr(fmt), ...)
end

-- A finishing place: 1ST, 2ND... / LOCUL 1, LOCUL 2...
function I.place(p)
  if I.lang == 2 then return "LOCUL " .. p end
  if p == 1 then return "1ST" elseif p == 2 then return "2ND" elseif p == 3 then return "3RD" end
  return p .. "TH"
end

-- Sort key for alphabetical lists, with the language's accented letters
-- right after their base letter (Romanian: A Ă Â ... I Î ... S Ș T Ț).
local FOLD = {
  ["Ă"] = "A~", ["Â"] = "A~~", ["Î"] = "I~", ["Ș"] = "S~", ["Ş"] = "S~", ["Ț"] = "T~", ["Ţ"] = "T~",
  ["É"] = "E", ["È"] = "E", ["Ô"] = "O", ["Ü"] = "U", ["Ö"] = "O", ["Ç"] = "C",
}
function I.sortKey(s)
  return (s:gsub("[\192-\244][\128-\191]*", function(ch) return FOLD[ch] or ch end))
end

return I
