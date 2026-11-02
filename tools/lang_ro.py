# Builds src/lang_ro.lua: Romanian for every English string the game draws.
#   python3 tools/lang_ro.py
# Keys are the English text exactly as in the code; templates keep their %s/%d.
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

RO = {
  # title, menus, options
  "SLOW TO REACT, EASY TO FOOL": "REACȚIONEAZĂ GREU, SE LASĂ PĂCĂLIT",
  "A SOLID CLUB FENCER": "UN SCRIMER SOLID DE CLUB",
  "QUICK, AND HARD TO FEINT": "RAPID, GREU DE PĂCĂLIT CU FENTE",
  "FAST, READS YOUR FEINTS": "FOARTE RAPID, ÎȚI CITEȘTE FENTELE",
  "A STYLE PICKED AT RANDOM": "UN STIL ALES LA ÎNTÂMPLARE",
  "A BIT OF EVERYTHING": "CÂTE PUȚIN DIN TOATE",
  "PRESSES FORWARD, BEATS AND ATTACKS": "PRESEAZĂ, BATE LAMA ȘI ATACĂ",
  "WAITS, THEN ATTACKS YOUR PREPARATION": "AȘTEAPTĂ ȘI ATACĂ PE PREGĂTIRE",
  "PARRIES AND RIPOSTES": "PAREAZĂ ȘI RIPOSTEAZĂ",
  "LOVES THE FLÈCHE FROM LONG DISTANCE": "IUBEȘTE FLEȘA DE LA DISTANȚĂ",
  "RANDOM": "ALEATORIU",
  "QUICK BOUT": "ASALT RAPID",
  "TACTICAL BOUT": "ASALT TACTIC",
  "ON": "DA", "OFF": "NU", "YES": "DA", "NO": "NU",
  "CAREER": "CARIERĂ",
  "TRAINING": "ANTRENAMENT",
  "PROFILE": "PROFIL",
  "HOW TO PLAY": "CUM SE JOACĂ",
  "OPTIONS": "OPȚIUNI",
  "QUIT": "IEȘIRE",
  "OPPONENT": "ADVERSAR",
  "STYLE": "STIL",
  "TOUCHES": "TUȘE",
  "BACK": "ÎNAPOI",
  "LANGUAGE": "LIMBA",
  "SOUND": "SUNET",
  "CROWD": "PUBLIC",
  "ASSISTS": "AJUTOARE",
  "PISTE SIDE": "POZIȚIE",
  "LEFT · RED": "STÂNGA · ROȘU",
  "RIGHT · GREEN": "DREAPTA · VERDE",
  "RESOLUTION": "REZOLUȚIE",
  "SWAP A/B": "INVERSEAZĂ A/B",
  "SHOW FPS": "ARATĂ FPS",
  "ENGLISH OR ROMANIAN": "ENGLEZĂ SAU ROMÂNĂ",
  "SOUND EFFECTS": "EFECTE SONORE",
  "CROWD NOISE AND CHEERS": "ZGOMOTUL ȘI APLAUZELE PUBLICULUI",
  "PRIORITY MARKER, ATTACK LINE ARROW, DISTANCE COLOUR": "PRIORITATEA, LINIA ATACULUI, DISTANȚA",
  "THE END OF THE PISTE YOU FENCE FROM": "CAPĂTUL PLANȘEI DE PE CARE TRAGI",
  "CHUNKY 240×160 PIXELS, FINER 360×240, OR FULL 720×480": "PIXELI MARI 240×160, FINI 360×240 SAU 720×480",
  "FOR PADS THAT LABEL A AND B THE OTHER WAY ROUND": "PENTRU CONSOLE CU A ȘI B INVERSATE",
  "FRAMES PER SECOND IN THE CORNER": "CADRE PE SECUNDĂ, ÎN COLȚ",
  "FOIL · RIGHT OF WAY": "FLORETĂ · PRIORITATE",
  "THREE PERIODS OF 3 MIN, BREAK AT 8": "TREI REPRIZE DE 3 MIN, PAUZĂ LA 8",
  "TWO PERIODS OF 3 MIN": "DOUĂ REPRIZE DE 3 MIN",
  "ONE PERIOD OF 3 MIN": "O REPRIZĂ DE 3 MIN",
  "MOVE LIVE, CHOOSE EACH EXCHANGE FROM A MENU": "MIȘCARE LIBERĂ, FAZELE ALESE DIN MENIU",
  "YOU: %s": "TU: %s",
  "YOU": "TU",
  "SELECT": "ALEGE",
  # bout screen
  "RESUME": "CONTINUĂ",
  "RESTART": "DE LA CAPĂT",
  "CONTROLS": "CONTROALE",
  "QUIT BOUT": "IEȘI DIN ASALT",
  "PAUSED": "PAUZĂ",
  "DRILL COMPLETE": "EXERCIȚIU REUȘIT",
  "CONTINUE": "CONTINUĂ",
  "VICTORY": "VICTORIE",
  "DEFEAT": "ÎNFRÂNGERE",
  "%s WINS": "%s CÂȘTIGĂ",
  "PARRIES": "PARADE",
  "BEATS": "BĂTĂI",
  "OFF TARGET": "NEVALABILE",
  "ATTACK": "ATAC",
  "RIPOSTE": "RIPOSTĂ",
  "BEAT": "BĂTAIE",
  "LINE": "LINIE",
  "PRIORITY": "PRIORITATE",
  "PRIORITY MINUTE": "MINUTUL DE PRIORITATE",
  "PRIORITY: %s (%s)": "PRIORITATE: %s (%s)",
  "FIRST TOUCH WINS. NO TOUCH: PRIORITY WINS": "PRIMA TUȘĂ CÂȘTIGĂ. FĂRĂ TUȘĂ: PRIORITATEA",
  "ONE MINUTE BREAK": "PAUZĂ DE UN MINUT",
  # the referee (the calls themselves stay in French, as on a real piste)
  "BEAT-ATTACK": "ATAC CU BĂTAIE",
  "PARRY-RIPOSTE": "PARADĂ-RIPOSTĂ",
  "COUNTER-RIPOSTE": "CONTRARIPOSTĂ",
  "COUNTERATTACK": "CONTRAATAC",
  "REMISE": "REMIZĂ",
  "POINT IN LINE": "BRAȚ ÎN LINIE",
  "LEFT": "STÂNGA",
  "RIGHT": "DREAPTA",
  "BREAK": "PAUZĂ",
  "FLÈCHE ATTACK": "ATAC CU FLEȘĂ",
  "SIMULTANEOUS ATTACKS": "ATACURI SIMULTANE",
  "SIMULTANEOUS ACTIONS": "ACȚIUNI SIMULTANE",
  "BOTH ATTACKED TOGETHER": "AMÂNDOI AU ATACAT DEODATĂ",
  "NEITHER HAD PRIORITY": "NICIUNUL NU AVEA PRIORITATE",
  "%s FROM THE LEFT": "%s DIN STÂNGA",
  "%s FROM THE RIGHT": "%s DIN DREAPTA",
  "ATTACK INTO THE POINT IN LINE": "ATAC ÎN BRAȚUL ÎN LINIE",
  "COUNTERATTACK NOT IN TIME": "CONTRAATACUL NU A FOST ÎN TIMP",
  "THE RIPOSTE BEATS THE REMISE": "RIPOSTA BATE REMIZA",
  "THE REMISE HAS NO PRIORITY": "REMIZA NU ARE PRIORITATE",
  "PRIORITY TO THE LEFT": "PRIORITATE PENTRU STÂNGA",
  "PRIORITY TO THE RIGHT": "PRIORITATE PENTRU DREAPTA",
  "%s OFF TARGET": "%s ÎN AFARA ȚINTEI",
  "THE PRIORITY HIT WAS OFF TARGET": "TUȘA CU PRIORITATE A FOST NEVALABILĂ",
  "COUNTERATTACK IN TIME": "CONTRAATAC ÎN TIMP",
  "ONLY THE TRUNK IS VALID IN FOIL": "LA FLORETĂ E VALABIL DOAR TRUNCHIUL",
  "BACK LINE CROSSED": "LINIA DE FUND DEPĂȘITĂ",
  "LEFT LEFT THE PISTE": "CEL DIN STÂNGA A IEȘIT DIN PLANȘĂ",
  "RIGHT LEFT THE PISTE": "CEL DIN DREAPTA A IEȘIT DIN PLANȘĂ",
  "FLÈCHE: NO HIT": "FLEȘĂ: FĂRĂ TUȘĂ",
  "HALT AS THE FENCERS PASS": "OPRIRE LA TRECEREA PE LÂNGĂ ADVERSAR",
  "CORPS-À-CORPS": "CORP LA CORP",
  "BODY CONTACT STOPS THE BOUT": "CONTACTUL CORPORAL OPREȘTE ASALTUL",
  "TIME": "TIMPUL",
  "TOUCH LEFT": "TUȘĂ STÂNGA",
  "TOUCH RIGHT": "TUȘĂ DREAPTA",
  "NO TOUCH": "FĂRĂ TUȘĂ",
  # opponents
  "NOVICE": "ÎNCEPĂTOR",
  "NATIONAL": "NAȚIONAL",
  "ELITE": "ELITĂ",
  "LEGEND": "LEGENDĂ",
  "ALL-ROUNDER": "COMPLET",
  "ATTACKER": "ATACANT",
  "COUNTER-PUNCHER": "CONTRAATACANT",
  "DEFENDER": "DEFENSIV",
  "FLÈCHEUR": "AMATOR DE FLEȘĂ",
  # profiles
  "SPACE": "SPAȚIU",
  "DELETE": "ȘTERGE",
  "TYPE A NAME FIRST": "SCRIE ÎNTÂI UN NUME",
  "UP TO %d LETTERS": "CEL MULT %d LITERE",
  "YOUR NAME": "NUMELE TĂU",
  "NATIONALITY": "NAȚIONALITATE",
  "LETTER": "LITERĂ",
  "CHOOSE": "ALEGE",
  "NEW PROFILE · NAME": "PROFIL NOU · NUME",
  "%s · NATIONALITY": "%s · NAȚIONALITATE",
  "WELCOME TO": "BINE AI VENIT LA",
  "Create your profile: a name for the scoreboard and the nation you fence for. Your career and training progress are kept in it, and more fencers can each have their own.":
    "Creează-ți profilul: un nume pentru tabela de marcaj și țara pentru care tragi. În el se păstrează cariera și progresul la antrenament; mai mulți scrimeri pot avea fiecare profilul lui.",
  "CREATE YOUR PROFILE": "CREEAZĂ-ȚI PROFILUL",
  "%s AT THE %s": "%s LA %s",
  "ARE YOU SURE?": "EȘTI SIGUR?",
  "ACTIVE": "ACTIV",
  "SWITCH PROFILE": "SCHIMBĂ PROFILUL",
  "NEW PROFILE": "PROFIL NOU",
  "CHANGE NAME": "SCHIMBĂ NUMELE",
  "CHANGE NATIONALITY": "SCHIMBĂ NAȚIONALITATEA",
  "DELETE PROFILE": "ȘTERGE PROFILUL",
  "Delete %s? Their career and training progress will be lost.":
    "Ștergi profilul %s? Cariera și progresul la antrenament se vor pierde.",
  "BOUTS %d · WON %d (%d%%)": "ASALTURI %d · CÂȘTIGATE %d (%d%%)",
  "TOUCHES SCORED %d · RECEIVED %d": "TUȘE DATE %d · PRIMITE %d",
  "TRAINING DRILLS %d/%d": "EXERCIȚII DE ANTRENAMENT %d/%d",
  "CAREER BEST: %s": "CEL MAI BUN REZULTAT: %s",
  "CAREER: NOT STARTED": "CARIERĂ: NEÎNCEPUTĂ",
  # tactical bout
  "ADVANCE / RETREAT": "PAS ÎNAINTE / ÎNAPOI",
  "BALESTRA (JUMP FORWARD)": "BALESTRĂ (SALT ÎNAINTE)",
  "JUMP BACK": "SALT ÎNAPOI",
  "ATTACK: CHOOSE HOW": "ATAC: ALEGI CUM",
  "CHOOSE IN A MENU": "ALEGERE ÎN MENIU",
  "CONFIRM": "CONFIRMĂ",
  "CANCEL AN ATTACK": "RENUNȚĂ LA ATAC",
  "PAUSE": "PAUZĂ",
  "ATTACK THEIR RECOVERY": "ATACĂ PE REVENIRE",
  "YOUR ATTACK": "ATACUL TĂU",
  "%s ATTACKS YOUR RECOVERY": "%s ATACĂ PE REVENIREA TA",
  "%s ATTACKS!": "%s ATACĂ!",
  "COUNTER-PARRY! COUNTER-RIPOSTE": "AI CONTRAPARAT!",
  "PARRIED! YOUR RIPOSTE": "AI PARAT! RIPOSTA",
  "PARRIED! YOUR ANSWER": "AI FOST PARAT!",
  "THE ATTACK FELL SHORT": "ATAC SCURT!",
  "SO FAR: NOTHING SEEN": "DEOCAMDATĂ: NIMIC",
  "SO FAR: %s %d OF %d": "PÂNĂ ACUM: %s %d DIN %d",
  "RATINGS": "ATRIBUTE",
  "DEFENCE": "APĂRARE",
  "TIMING": "SIMȚUL TIMPULUI",
  "FOOTWORK": "DEPLASARE",
  "ATK": "ATC", "DEF": "APR", "TIM": "TMP", "FTW": "DPL",
  "DIRECT LUNGE": "FANDARE DIRECTĂ",
  "One fast tempo. A counterattack has no priority on it; a parry or a retreat stops it.":
    "Un singur timp, rapid. Contraatacul nu are prioritate; parada sau retragerea îl opresc.",
  "DISENGAGE": "DEGAJAMENT",
  "Lunge round their blade: deceives a simple parry. A circular parry catches it.":
    "Fandare ocolind lama: înșală parada simplă. Parada circulară îl prinde.",
  "STEP-LUNGE": "PAS-FANDARE",
  "Advance, then lunge: catches a retreat. The step is a preparation they can hit into.":
    "Pas înainte și fandare: prinde retragerea. Pasul e o pregătire în care te pot ataca.",
  "BEAT-LUNGE": "BĂTAIE-FANDARE",
  "Knock their blade aside, then lunge: spoils a stop-hit and a simple parry.":
    "Bate lama adversă, apoi fandează: strică lovitura de oprire și parada simplă.",
  "FEINT-DISENGAGE": "FENTĂ-DEGAJAMENT",
  "Feint, draw the parry, deceive it. Two tempi: a counterattack lands first.":
    "Fentă, provoci parada, o înșeli. Doi timpi: contraatacul ajunge primul.",
  "FLÈCHE": "FLEȘĂ",
  "A running attack from further out. Parried, there is no way back from it.":
    "Atac în fugă, de mai departe. Odată parată, nu mai ai cale de întoarcere.",
  "SIMPLE PARRY": "PARADĂ SIMPLĂ",
  "Block the blade and take the priority to riposte. A disengage or a feint deceives it.":
    "Blochează lama și ia prioritatea pentru ripostă. Degajamentul sau fenta o înșală.",
  "CIRCULAR PARRY": "PARADĂ CIRCULARĂ",
  "Sweep a full circle: catches a disengage. A little slower against a direct attack.":
    "Un cerc complet: prinde degajamentul. Puțin mai lentă contra atacului direct.",
  "RETREAT": "RETRAGERE",
  "Break the distance: a lunge falls short. A step-lunge or a flèche can still reach you.":
    "Rupi distanța: fandarea rămâne scurtă. Pas-fandarea sau fleșa te pot ajunge.",
  "Hit into the attack. Only scores a tempo ahead: against a feint or a preparation.":
    "Lovești în atac. Contează doar cu un timp înainte: contra fentei sau a pregătirii.",
  "DIRECT RIPOSTE": "RIPOSTĂ DIRECTĂ",
  "Straight back at once: it beats a remise. A counter-parry can stop it.":
    "Imediat și direct: bate remiza. O contraparadă o poate opri.",
  "INDIRECT RIPOSTE": "RIPOSTĂ INDIRECTĂ",
  "Goes round the counter-parry, but gives them time to recover.":
    "Riposta ocolește lama: înșală contraparada, dar îi lasă timp să revină.",
  "DELAYED RIPOSTE": "RIPOSTĂ ÎNTÂRZIATĂ",
  "Let their counter-parry go by, then hit. A remise or a quick recovery beats it.":
    "Lași contraparada să treacă, apoi lovești. Remiza sau revenirea rapidă o bat.",
  "COUNTER-PARRY": "CONTRAPARADĂ",
  "Parry the riposte and hit back. An indirect or delayed riposte evades it.":
    "Parezi riposta și lovești înapoi. Riposta indirectă sau întârziată o evită.",
  "Stay in the lunge and put the point back. It only scores against a slow riposte.":
    "Rămâi în fandare și repui vârful. Contează doar contra unei riposte lente.",
  "RECOVER BACK": "REVENIRE ÎNAPOI",
  "Spring back out of distance. Escapes a slow riposte, rarely a direct one.":
    "Revii în gardă, din distanță. Scapi de riposta lentă, rar de cea directă.",
  "ATTACK ON RECOVERY": "ATAC PE REVENIRE",
  "Attack while they recover from the lunge: they are late to defend.":
    "Ataci cât timp revine din fandare: întârzie cu apărarea.",
  "BACK ON GUARD": "ÎNAPOI ÎN GARDĂ",
  "Let them recover, and start the phrase again.": "Îl lași să revină și reluați fraza.",
  "CLOSE": "APROAPE",
  "LUNGE": "FANDARE",
  "TOO FAR": "PREA DEPARTE",
  # career
  "CLUB OPEN": "OPEN DE CLUB",
  "REGIONAL CIRCUIT": "CIRCUITUL REGIONAL",
  "NATIONAL CHAMPIONSHIPS": "CAMPIONATUL NAȚIONAL",
  "SATELLITE CUP": "CUPA SATELIT",
  "WORLD CUP": "CUPA MONDIALĂ",
  "WORLD CHAMPIONSHIPS": "CAMPIONATUL MONDIAL",
  "LEAVE (FENCE LATER)": "IEȘI (TRAGI MAI TÂRZIU)",
  "POOL %d": "GRUPA %d",
  "TS": "TD",
  "QUARTER": "SFERTURI",
  "SEMI": "SEMIFINALE",
  "FINAL": "FINALA",
  "POOLS · BOUTS TO 5": "GRUPE · ASALTURI LA 5",
  "BOUT %d OF 5": "ASALTUL %d DIN 5",
  "NEXT: %s %s": "URMEAZĂ: %s %s",
  "STYLE: %s": "STIL: %s",
  "YOUR POOL IS DONE": "GRUPA TA S-A ÎNCHEIAT",
  "FENCE": "TRAGE",
  "RANKING": "CLASAMENT",
  "RANKING AFTER THE POOLS · TOP 8 GO ON": "DUPĂ GRUPE · PRIMII 8 SE CALIFICĂ",
  "RESULT": "REZULTAT",
  "TABLE OF 8": "TABLOUL DE 8",
  "DIRECT ELIMINATION · BOUTS TO %d": "ELIMINARE DIRECTĂ · ASALTURI LA %d",
  "FINAL RESULT": "REZULTAT FINAL",
  "CHAMPION!": "CAMPION!",
  "SILVER MEDAL": "MEDALIE DE ARGINT",
  "BRONZE MEDAL": "MEDALIE DE BRONZ",
  "%s PLACE": "%s",
  "YOU FINISHED %s OF 12": "AI TERMINAT PE %s DIN 12",
  "UNLOCKED: %s": "DEBLOCAT: %s",
  "A MEDAL HERE UNLOCKS THE %s": "O MEDALIE AICI DEBLOCHEAZĂ %s",
  "CONTINUE: %s": "CONTINUĂ: %s",
  "EVENT IN PROGRESS · %s": "ÎN DESFĂȘURARE · %s",
  "HOW WILL YOU FENCE?": "CUM VREI SĂ TRAGI?",
  "TACTICAL": "TACTIC",
  "MODE": "MOD",
  "MODE: %s": "MOD: %s",
  "SWITCH ANY TIME FROM THE PAUSE MENU": "SE POATE SCHIMBA ORICÂND DIN PAUZĂ",
  "ONLY FENCERS FROM %s": "DOAR SCRIMERI DIN %s",
  "Move live with ←/→, L1 and R1. Whoever moves first stops the bout: you both pick one of five actions, each beating two.":
    "Te miști liber cu ←/→, L1 și R1. Cine acționează primul oprește asaltul: alegeți una din cinci acțiuni, fiecare bate două.",
  "Fence every action yourself, in real time: lunges, parries, feints and flèches on the buttons.":
    "Faci singur fiecare acțiune, în timp real: fandări, parade, fente și fleșe, din butoane.",
  "Move live with ←/→, L1 and R1. When someone attacks, the bout stops and you choose the blade work from a menu.":
    "Te miști liber cu ←/→, L1 și R1. Când cineva atacă, asaltul se oprește și alegi acțiunile cu arma dintr-un meniu.",
  "LOCKED": "BLOCAT",
  "BEST %s": "%s",
  "DE BOUTS TO %d · OPPONENTS %s TO %s": "ED LA %d · ADVERSARI %s-%s",
  "A MEDAL UNLOCKS THE NEXT COMPETITION": "O MEDALIE DESCHIDE COMPETIȚIA URMĂTOARE",
  "MEDALS  %d GOLD · %d SILVER · %d BRONZE": "MEDALII  %d AUR · %d ARGINT · %d BRONZ",
  # the wheel bout
  "WHEEL BOUT": "ASALT PE ROATĂ",
  "WHEEL": "ROATĂ",
  "MOVE LIVE, PICK EACH EXCHANGE ON THE WHEEL": "MIȘCARE LIBERĂ, FIECARE FAZĂ PE ROATĂ",
  "FIVE ACTIONS: EACH BEATS TWO, LOSES TO TWO": "CINCI ACȚIUNI: FIECARE BATE DOUĂ, PIERDE LA DOUĂ",
  "MOVE FIRST: PICK ON THE WHEEL": "ACȚIONEZI PRIMUL: ALEGI PE ROATĂ",
  "CANCEL YOUR MOVE": "RENUNȚĂ LA ACȚIUNE",
  "MOVE FIRST": "ACȚIONEAZĂ PRIMUL",
  "YOU MOVE FIRST": "ACȚIONEZI PRIMUL",
  "%s MOVES FIRST!": "%s ACȚIONEAZĂ PRIMUL!",
  "DIRECT ATTACK": "ATAC DIRECT",
  "FEINT ATTACK": "ATAC CU FENTĂ",
  "BEAT ATTACK": "ATAC CU BĂTAIE",
  "DIRECT": "DIRECT",
  "FEINT": "FENTĂ",
  "WINS AGAINST: %s": "CÂȘTIGĂ CONTRA: %s",
  "LOSES TO: %s": "PIERDE CONTRA: %s",
  "ONE TEMPO BEATS TWO": "UN TIMP BATE DOI TIMPI",
  "ATTACK INTO THE PREPARATION": "ATAC PE PREGĂTIRE",
  "THE FEINT DECEIVES THE PARRY": "FENTA ÎNȘALĂ PARADA",
  "THE BLADE EVADES THE BEAT": "LAMA SCAPĂ DE BĂTAIE",
  "PARRY, THEN RIPOSTE": "PARADĂ, APOI RIPOSTĂ",
  "THE PARRY FINDS THE BLADE IN LINE": "PARADA GĂSEȘTE LAMA ÎN LINIE",
  "THE POINT IN LINE HAS PRIORITY": "BRAȚUL ÎN LINIE ARE PRIORITATE",
  "THE FEINT RUNS ONTO THE POINT": "FENTA SE ÎNFIGE ÎN VÂRF",
  "THE BEAT REMOVES THE LINE": "BĂTAIA SCOATE BRAȚUL DIN LINIE",
  "THE BEAT OPENS THE LINE": "BĂTAIA DESCHIDE LINIA",
  "BOTH WAIT: NOBODY ATTACKS": "AMÂNDOI AȘTEAPTĂ: NIMENI NU ATACĂ",
  "BOTH IN LINE: NOBODY ATTACKS": "AMÂNDOI ÎN LINIE: NIMENI NU ATACĂ",
  "THE BLADES CLASH": "LAMELE SE CIOCNESC",
  "Press A to move first, or wait for them. The bout stops and you both pick one of five actions: theirs is already chosen.":
    "Apeși A ca să acționezi primul, sau aștepți. Asaltul se oprește și alegeți amândoi una din cinci acțiuni: a lui e deja aleasă.",
  "DIRECT beats FEINT and BEAT. FEINT beats PARRY and BEAT. PARRY beats DIRECT and LINE. LINE beats DIRECT and FEINT. BEAT beats LINE and PARRY.":
    "DIRECTUL bate FENTA și BĂTAIA. FENTA bate PARADA și BĂTAIA. PARADA bate DIRECTUL și LINIA. LINIA bate DIRECTUL și FENTA. BĂTAIA bate LINIA și PARADA.",
  "The same pick: no touch. Distance and ratings don't count.":
    "Aceeași alegere: fără tușă. Distanța și atributele nu contează.",
  # how to play
  "HIGH / LOW LINE": "LINIE SUS / JOS",
  "LUNGE (HOLD: STAY IN IT)": "FANDARE (ȚINUT: RĂMÂI ÎN EA)",
  "PARRY IN YOUR LINE / BEAT": "PARADĂ ÎN LINIA TA / BĂTAIE",
  "EXTEND (HOLD: POINT IN LINE)": "ÎNTINDE BRAȚUL (ȚINUT: ÎN LINIE)",
  "SELECT + START QUITS THE GAME": "SELECT + START ÎNCHIDE JOCUL",
  "THE TARGET": "ȚINTA",
  "In foil only the trunk counts: the metallic vest (the lamé) you can see on each fencer.":
    "La floretă contează doar trunchiul: vesta metalică (lamé) pe care o vezi la fiecare scrimer.",
  "A hit on the trunk lights your colour: RED on the left, GREEN on the right. A hit on the mask or the legs lights WHITE: the phrase stops and nobody scores.":
    "O tușă pe trunchi aprinde culoarea ta: ROȘU în stânga, VERDE în dreapta. Pe mască sau pe picioare se aprinde ALB: fraza se oprește și nu punctează nimeni.",
  "After the first hit the box gives the other fencer 0.3 s to land too. Then it locks out.":
    "După prima tușă, aparatul îi mai dă celuilalt 0,3 s să lovească și el. Apoi se blochează.",
  "RIGHT OF WAY": "PRIORITATEA",
  "One light: that touch counts, whoever made it.": "O lumină: tușa contează, oricine ar fi dat-o.",
  "Two lights: the referee gives the touch to the fencer with PRIORITY.":
    "Două lumini: arbitrul dă tușa celui care are PRIORITATE.",
  "The first to start an attack has priority: arm extending, point threatening the target. Stepping forward is only preparation. Attack into it!":
    "Primul care începe atacul are prioritate: brațul se întinde, vârful amenință ținta. Pasul înainte e doar pregătire. Atacă în ea!",
  "Attacks started together are SIMULTANEOUS: no touch.": "Atacurile pornite deodată sunt SIMULTANE: nicio tușă.",
  "TAKING PRIORITY": "CUM IEI PRIORITATEA",
  "PARRY the attack (B in the line it comes in) and the priority is yours: riposte at once with X, or A if they are far.":
    "PAREAZĂ atacul (B în linia lui) și prioritatea e a ta: ripostează imediat cu X, sau cu A dacă e departe.",
  "An attack that falls short or is parried has lost priority. Holding the lunge (a remise) does not get it back.":
    "Atacul scurt sau parat își pierde prioritatea. Remiza (rămâi în fandare) nu o readuce.",
  "BEAT their blade (B when the blades cross) to take priority, then attack.":
    "BATE-I lama (B când lamele se ating) ca să iei prioritatea, apoi atacă.",
  "POINT IN LINE: extend (hold X) before they attack. They must beat your blade first.":
    "BRAȚ ÎN LINIE: ține X înainte să atace. Adversarul trebuie întâi să-ți bată lama.",
  "THE PISTE AND TIME": "PLANȘA ȘI TIMPUL",
  "The piste is 14 m long. You start behind your en-garde line, 2 m from the centre. The last 2 m before each end line is the warning zone.":
    "Planșa are 14 m. Începi în spatele liniei de gardă, la 2 m de centru. Ultimii 2 m dinaintea fiecărei linii de fund sunt zona de avertizare.",
  "Cross your own end line with both feet and you concede a touch. Body contact (corps-à-corps) halts the bout.":
    "Dacă treci cu ambele picioare de linia ta de fund, primești o tușă. Contactul corporal (corp la corp) oprește asaltul.",
  "Bouts to 5 last 3 minutes. Bouts to 15 have three periods, with a break at 8. A tie at time goes to a priority minute.":
    "Asalturile la 5 durează 3 minute. Cele la 15 au trei reprize, cu pauză la 8. La egalitate se trage un minut de prioritate.",
  "You move live. Press A to attack: the bout stops and you choose how. When they attack, choose a defence; after a parry, the riposte and the answer.":
    "Între faze te miști liber (←→, L1, R1). Cu A ataci: asaltul se oprește și alegi cum. Când atacă adversarul alegi apărarea; după paradă, riposta și răspunsul.",
  "The choices beat each other like a wheel: the parry stops the direct attack, the disengage and the feint deceive the parry, the counterattack beats the feint, the direct attack and the beat beat the counterattack.":
    "Alegerile se bat ca o roată: parada oprește atacul direct, degajamentul și fenta înșală parada, contraatacul bate fenta, atacul direct și bătaia bat contraatacul.",
  "Distance and ratings count too: training drills raise yours.":
    "Contează și distanța, și atributele: exercițiile ți le cresc.",
  "TIPS": "SFATURI",
  "Keep just outside their lunge. The distance at the bottom turns yellow, then orange, when a lunge can reach.":
    "Stai chiar în afara fandării lui. Distanța de jos se face galbenă, apoi portocalie, când fandarea ajunge.",
  "The orange arrow shows the line of an incoming attack. A parry in your own guard line lasts longer.":
    "Săgeata portocalie arată linia atacului. Parada în linia ta de gardă ține mai mult.",
  "Attack the line they don't guard. Switch line (up/down) during your lunge to slip past a parry.":
    "Atacă linia neacoperită. Schimbă linia (sus/jos) în fandare ca să ocolești parada.",
  "Retreat to make their lunge fall short, then attack as they recover.":
    "Retrage-te ca fandarea lui să fie scurtă, apoi atacă-l cât revine.",
  "PAGE": "PAGINA",
  # training
  "ADVANCE, RETREAT AND JUMP": "PAS ÎNAINTE, ÎNAPOI ȘI SALT",
  "Fencing is distance. Move with ← and → (towards the coach is an advance). R1 is a quick jump forward (balestra), L1 a jump back.":
    "Scrima înseamnă distanță. Te miști cu ← și → (spre antrenor e pas înainte). R1 e un salt rapid înainte (balestră), L1 un salt înapoi.",
  "Put your FRONT FOOT in the green zone and stop there.": "Pune PICIORUL DIN FAȚĂ în zona verde și oprește-te acolo.",
  "STEP": "PAS",
  "JUMP FWD": "SALT ÎNAINTE",
  "GOOD": "BINE",
  "THE LUNGE": "FANDAREA",
  "HIT FROM THE RIGHT DISTANCE": "LOVEȘTE DE LA DISTANȚA POTRIVITĂ",
  "Close in until the distance at the bottom turns orange, then lunge with A. The front foot shoots forward and the arm extends first.":
    "Apropie-te până când distanța de jos se face portocalie, apoi fandează cu A. Piciorul din față țâșnește înainte, iar brațul se întinde primul.",
  "Too far and the lunge falls short. Too close and you crowd yourself. The coach moves now and then.":
    "Prea departe și fandarea rămâne scurtă. Prea aproape și te înghesui. Antrenorul se mai mișcă din când în când.",
  "DISTANCE": "DISTANȚA",
  "TOUCH!": "TUȘĂ!",
  "TOO FAR: THE LUNGE FELL SHORT": "PREA DEPARTE: FANDARE SCURTĂ",
  "HIGH AND LOW": "SUS ȘI JOS",
  "ATTACK THE OPEN LINE": "ATACĂ LINIA DESCHISĂ",
  "The coach guards one line and parries anything that comes into it. The flashing mark shows the open line.":
    "Antrenorul acoperă o linie și parează tot ce vine în ea. Semnul care clipește arată linia deschisă.",
  "Hold ↑ or ↓ as you press A to lunge into it: high is the chest, low the flank.":
    "Ține ↑ sau ↓ când apeși A ca să fandezi în ea: sus e pieptul, jos flancul.",
  "INTO THE OPEN LINE!": "ÎN LINIA DESCHISĂ!",
  "PARRIED: GO FOR THE OPEN LINE": "PARAT: ATACĂ LINIA DESCHISĂ",
  "TAKE THE PRIORITY WITH A PARRY": "IA PRIORITATEA CU O PARADĂ",
  "The coach will lunge, high or low. Parry with B, holding ↑ or ↓ for the line the attack comes in (watch the orange arrow).":
    "Antrenorul va fanda, sus sau jos. Parează cu B, ținând ↑ sau ↓ pentru linia în care vine atacul (urmărește săgeata portocalie).",
  "A parry takes the priority: riposte at once with X.": "Parada ia prioritatea: ripostează imediat cu X.",
  "PARRY": "PARADĂ",
  "PARRY-RIPOSTE!": "PARADĂ-RIPOSTĂ!",
  "PARRY IN THE LINE OF THE ATTACK": "PAREAZĂ ÎN LINIA ATACULUI",
  "PARRY FIRST, THEN RIPOSTE": "ÎNTÂI PARADA, APOI RIPOSTA",
  "ATTACK FIRST": "ATACĂ PRIMUL",
  "PRIORITY GOES TO WHOEVER STARTS": "PRIORITATEA E A CELUI CARE ÎNCEPE",
  "The coach steps forward (preparation) and lunges as soon as it is in distance. If you wait and both lamps light, its attack has the priority.":
    "Antrenorul face un pas înainte (pregătire) și fandează imediat ce ajunge în distanță. Dacă aștepți și se aprind ambele lămpi, atacul lui are prioritate.",
  "Lunge while it is still stepping in: your attack starts first, so it is yours.":
    "Fandează cât încă face pasul: atacul tău începe primul, deci tușa e a ta.",
  "YOUR ATTACK HAD PRIORITY!": "ATACUL TĂU AVEA PRIORITATE!",
  "ITS ATTACK STARTED FIRST": "ATACUL LUI A ÎNCEPUT PRIMUL",
  "BEAT THE BLADE, THEN ATTACK": "BATE LAMA, APOI ATACĂ",
  "The coach holds its arm straight with the point at you: a point in line. It has the priority, so attacking straight into it loses.":
    "Antrenorul ține brațul întins cu vârful spre tine: braț în linie. Are prioritate, deci un atac direct în el pierde.",
  "When the blades cross, beat its blade with B, then lunge at once with A.":
    "Când lamele se încrucișează, bate-i lama cu B, apoi fandează imediat cu A.",
  "BEAT-ATTACK!": "ATAC CU BĂTAIE!",
  "BEAT THE BLADE FIRST (B)": "ÎNTÂI BATE LAMA (B)",
  "GOOD, BUT BEAT THE BLADE FIRST": "BINE, DAR ÎNTÂI BATE LAMA",
  "CHANGE LINE DURING THE LUNGE": "SCHIMBĂ LINIA ÎN FANDARE",
  "This coach parries the line your attack STARTS in.": "Acest antrenor parează linia în care ÎNCEPE atacul tău.",
  "Lunge in one line, then press the other direction (↑ or ↓) while your arm is going out: the blade slips round the parry.":
    "Fandează într-o linie, apoi apasă direcția cealaltă (↑ sau ↓) cât brațul se întinde: lama ocolește parada.",
  "SWITCH": "SCHIMBĂ",
  "AROUND THE PARRY!": "PE LÂNGĂ PARADĂ!",
  "PARRIED: SWITCH LINE MID-LUNGE": "PARAT: SCHIMBĂ LINIA ÎN FANDARE",
  "SCORE FROM LONG DISTANCE": "TUȘĂ DE LA DISTANȚĂ MARE",
  "This coach steps back whenever you step in. Close the gap in one explosive move:":
    "Acest antrenor se retrage de fiecare dată când avansezi. Închide distanța dintr-o mișcare explozivă:",
  "Y is a flèche, a running attack. Or jump forward with R1 and lunge with A as you land.":
    "Y e o fleșă, un atac în fugă. Sau sari înainte cu R1 și fandează cu A când aterizezi.",
  "JUMP": "SALT",
  "FROM LONG RANGE!": "DE LA DISTANȚĂ!",
  "USE THE FLÈCHE OR THE JUMP": "FOLOSEȘTE FLEȘA SAU SALTUL",
  "SHORT: GET A LITTLE CLOSER FIRST": "SCURT: APROPIE-TE PUȚIN ÎNTÂI",
  "COACH": "ANTRENOR",
  "LEAVE DRILL": "IEȘI DIN EXERCIȚIU",
  "DRILL %d": "EXERCIȚIUL %d",
  "GOAL: %d": "OBIECTIV: %d",
  "DONE": "GATA",
  "%d OF %d DRILLS DONE": "%d DIN %d EXERCIȚII FĂCUTE",
  # nations
  "AZERBAIJAN": "AZERBAIDJAN", "BELGIUM": "BELGIA", "BOSNIA AND HERZEGOVINA": "BOSNIA ȘI HERȚEGOVINA",
  "BRAZIL": "BRAZILIA", "CÔTE D'IVOIRE": "COASTA DE FILDEȘ", "CAMEROON": "CAMERUN", "COLOMBIA": "COLUMBIA",
  "CROATIA": "CROAȚIA", "CYPRUS": "CIPRU", "CZECHIA": "CEHIA", "DENMARK": "DANEMARCA",
  "DOMINICAN REPUBLIC": "REPUBLICA DOMINICANĂ", "EGYPT": "EGIPT", "SPAIN": "SPANIA", "FINLAND": "FINLANDA",
  "FRANCE": "FRANȚA", "GREAT BRITAIN": "MAREA BRITANIE", "GERMANY": "GERMANIA", "GREECE": "GRECIA",
  "HUNGARY": "UNGARIA", "IRELAND": "IRLANDA", "IRAQ": "IRAK", "ICELAND": "ISLANDA", "ITALY": "ITALIA",
  "JORDAN": "IORDANIA", "JAPAN": "JAPONIA", "KAZAKHSTAN": "KAZAHSTAN", "KYRGYZSTAN": "KÂRGÂZSTAN",
  "KOREA": "COREEA", "SAUDI ARABIA": "ARABIA SAUDITĂ", "LATVIA": "LETONIA", "LEBANON": "LIBAN",
  "LITHUANIA": "LITUANIA", "LUXEMBOURG": "LUXEMBURG", "MOROCCO": "MAROC", "MALAYSIA": "MALAEZIA",
  "MEXICO": "MEXIC", "NORTH MACEDONIA": "MACEDONIA DE NORD", "NETHERLANDS": "ȚĂRILE DE JOS",
  "NORWAY": "NORVEGIA", "NEW ZEALAND": "NOUA ZEELANDĂ", "PHILIPPINES": "FILIPINE", "POLAND": "POLONIA",
  "PORTUGAL": "PORTUGALIA", "ROMANIA": "ROMÂNIA", "SOUTH AFRICA": "AFRICA DE SUD", "RUSSIA": "RUSIA",
  "SWITZERLAND": "ELVEȚIA", "SLOVAKIA": "SLOVACIA", "SWEDEN": "SUEDIA", "THAILAND": "THAILANDA",
  "TAJIKISTAN": "TADJIKISTAN", "CHINESE TAIPEI": "TAIPEIUL CHINEZ", "TRINIDAD AND TOBAGO": "TRINIDAD ȘI TOBAGO",
  "TÜRKIYE": "TURCIA", "UNITED ARAB EMIRATES": "EMIRATELE ARABE UNITE", "UKRAINE": "UCRAINA",
  "UNITED STATES": "STATELE UNITE",
}

def lua(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

def check():
    import re
    spec = re.compile(r"%[-+ #0-9.]*[sdifx%]")
    for k, v in RO.items():
        assert spec.findall(k) == spec.findall(v), "placeholders differ: %r -> %r" % (k, v)

def main():
    check()
    out = ["-- Romanian: the English text of the game (as in the code) -> Romanian.",
           "-- Generated by tools/lang_ro.py; edit the translations there.", "", "return {"]
    for k in sorted(RO):
        out.append("  [%s] = %s," % (lua(k), lua(RO[k])))
    out.append("}")
    open(os.path.join(ROOT, "src", "lang_ro.lua"), "w").write("\n".join(out) + "\n")
    print(len(RO), "strings")

if __name__ == "__main__":
    main()
