# RG Fencing

A pixel-art **foil fencing** game for LÖVE 11, made for the **Anbernic RG34XXSP**
(720×480, Allwinner H700) and packaged for both muOS and PortMaster. It plays
by the real rules: only the trunk is target, the scoring box locks out 300 ms
after the first hit, and when both lamps light the referee gives the touch by
**right of way**, and tells you why. The fencers move with weight and momentum,
in the spirit of the rotoscoped classics, and each player fences under their
own profile, name and flag. A **tactical bout** turns each exchange into a
choice from a menu, and the whole game can be played in **English or Romanian**.

![An exchange between two Elite fencers: attack, parry, riposte, and the referee's call](screenshots/bout.gif)

| | |
|---|---|
| ![Title](screenshots/title.png) | ![A lunge meets a parry in sixte](screenshots/lunge.png) |
| ![The referee's decision](screenshots/decision.png) | ![Lockout: the red lamp, and the priority marker](screenshots/lockout.png) |
| ![Career: the pool sheet](screenshots/pool.png) | ![Career: the table of 8](screenshots/bracket.png) |
| ![Training: attack the open line](screenshots/drill.png) | ![The salute before the bout](screenshots/salute.png) |
| ![Your profile](screenshots/profile.png) | ![Typing a name, accents included](screenshots/keyboard.png) |
| ![Tactical bout: choosing the attack](screenshots/tactical.png) | ![Tactical bout: a feint caught by a counterattack](screenshots/exchange.png) |
| ![Tactical bout, in Romanian](screenshots/romana.png) | ![Career: arcade or tactical, chosen when a competition starts](screenshots/modes.png) |

*Screenshots and the clip are rendered by the game itself at 360×240, shown at 720×480 (`./build.sh shots`).*

## Install

Download a package from [Releases](https://github.com/ctanas/rgfencing/releases),
or build them all with `./build.sh` (output in `dist/`).

### muOS (MustardOS)

1. Copy `RGFencing_vX.Y.Z.muxapp` to `/mnt/mmc/MUOS/ARCHIVE/` on the SD card.
2. On the device, open **Applications → Archive Manager** and install it.
3. Launch **RG Fencing** from Applications.

The muxapp is self-contained: it bundles an aarch64 LÖVE 11.5 runtime, since
muOS doesn't include LÖVE. Settings and profiles (each with its career) are stored
in `MUOS/application/RGFencing/.game/save/`. If the game doesn't start, check
`MUOS/application/RGFencing/.game/rgfencing.log`.

### PortMaster (Knulli, ROCKNIX, stock OS, ...)

Unzip `rgfencing_vX.Y.Z_portmaster.zip` into the SD card's `ports/` folder. You
should get `RG Fencing.sh` and `rgfencing/`. Refresh the game list, then launch
**RG Fencing** from Ports.

The launcher uses PortMaster's `love_11.5` runtime. If you have never installed
a LÖVE-based port, install that runtime from PortMaster first, or the launcher
will show a message and exit. Logs go to `ports/rgfencing/log.txt`, and saves
to `ports/rgfencing/conf/`.

### PC

`./build.sh run`, or `love .` from this folder (LÖVE 11.4/11.5). The packaged
game alone is `dist/rgfencing.love`.

## Controls

| Input | Action |
|---|---|
| D-pad ←/→ | Advance / retreat (towards the opponent is an advance) |
| D-pad ↑/↓ | High / low line. While your arm is going out: change the attack line (disengage) |
| A | Lunge. Hold to stay in the lunge (a remise); let go to recover. Press → during the lunge to recover forward |
| B | Parry in your line (hold ↑/↓ to choose it). Against a blade that isn't attacking: a beat |
| X | Extend the arm. Hold: point in line. After a parry: the riposte |
| Y | Flèche |
| R1 / L1 | Balestra (jump forward) / jump back |
| Start / Select | Pause |
| Select + Start | Quit |

Keyboard (desktop): arrows, Z = A, X = B, C = X, V = Y, Q/E = L1/R1, Enter = Start, Esc = Select.

You fence from the left (red) end of the piste, or from the right (green) with
**Options → Piste side**; it applies to quick bouts, the career and the training
drills (which mirror). A parry in your current guard line lasts
longer than one in the other line. With **Options → Assists** on (the default),
a yellow ▼ marks the fencer with priority, an orange arrow shows the line of an
incoming attack, and the distance readout turns yellow, then orange, once a
lunge can reach.

## Language

**Options → Language** switches between English and Romanian (Română) at once:
menus, help, drills, the referee's decisions and the nation names. The
referee's calls stay in French, as on a real piste (*En garde ! Prêts ? Allez !
Halte !*). The Romanian uses the terms of Romanian fencing: fandare,
pas-fandare, fleșă, degajament, bătaie, fentă, paradă, ripostă, remiză,
contraatac, braț în linie, prioritate, tușă.

## Foil, as the referee sees it

- **Target.** The trunk: the metallic lamé on each fencer. A hit there lights
  your colour (red left, green right). A hit on the mask or the legs lights white:
  the phrase stops and nobody scores. Arms don't count as blocking: in a side
  view they are beside the body, not in front of it.
- **Lockout.** After the first hit the other fencer has 300 ms to land.
- **One lamp:** that touch counts, whoever made it. A counterattack that lands a
  clear 300 ms before the attack scores on its own: *counterattack in time*.
- **Two lamps:** the touch goes to the fencer with **priority**:
  - The first fencer to start an attack (arm extending, point threatening) has it.
    Stepping forward is only preparation: an attack into it takes the priority.
  - Attacks started within 0.1 s of each other are **simultaneous**: no touch.
  - A **parry** takes the priority: the **riposte** has it, if it starts within
    0.65 s. A parry of the riposte gives a **counter-riposte**, and so on.
  - An attack that falls short, is withdrawn or parried has lost it. Holding the
    lunge is a **remise**, which never has priority over a riposte.
  - A **beat** on a still blade takes the priority for half a second: the
    **beat-attack**.
  - A **point in line** (arm straight before the opponent attacks) has priority;
    the attacker must beat it first.
  - If the fencer with priority hits off target, nobody scores.
- **The piste.** 14 m between the end lines, en-garde lines 2 m from the centre,
  2 m warning zones, 2 m run-off. Crossing your own end line with both feet
  concedes a touch. Body contact (corps-à-corps) halts the bout. A flèche that
  misses is halted as the fencers pass; a parried flèche is stopped in its run,
  open to the riposte.
- **Time.** The clock runs only between *Allez!* and *Halte!*. Bouts to 5: one
  period of 3 minutes. To 10: two. To 15: three, with a one-minute break at 8.
  A tie at time goes to a **priority minute**: the first touch wins, and if
  nobody scores, the fencer drawn for priority does.

Every halt ends with the referee's call (*ATTACK FROM THE LEFT · TOUCH LEFT*,
*PARRY-RIPOSTE FROM THE RIGHT*, *SIMULTANEOUS ATTACKS · NO TOUCH*...) and a line
that explains it (*COUNTERATTACK NOT IN TIME*, *THE RIPOSTE BEATS THE REMISE*,
*ONLY THE TRUNK IS VALID IN FOIL*...). The referee signals it too, and the
new score glows in the scorer's colour.

## Profiles

The first time the game starts it asks for your **name** and the **nation** you
fence for. Your name and flag then appear on the scoreboard, the pool sheets
and the rankings. Each profile keeps its own career, training progress and
record (bouts, wins, touches scored and received), so several players can share
the console: **Title → Profile** lets you switch, add, rename, change the
nationality or delete a profile.

- **Names** are typed on an on-screen keyboard, up to 12 letters. Y switches to
  accented capitals (À Á Â Ä Ă Ç É Ê Ë Î Ñ Ö Ø Ș Ț Ü Š Ž Č Ł Ő ...).
  B deletes, X types a space, Start confirms.
- **Nationality**: 112 nations with their FIE/IOC code and a 9×6 pixel flag.
  ◄/► jump between initial letters, L1/R1 page.
- A career and training progress from v0.1.0 are moved into the first profile.

## Game modes

Every bout against the CPU (quick bout, tactical bout or career) can be fenced
in **arcade** mode, every action on the buttons, or in **tactical** mode, live
footwork with the blade work chosen from menus. **Mode** in the pause menu
switches between them at any point of a bout; the switch takes effect when you
resume.

### Quick bout

Pick the opponent's level and style and the bout length (5, 10 or 15 touches).

### Tactical bout

**In short.** You move your fencer freely in real time (←/→, L1/R1), but the
blade work is chosen from menus.

1. **Starting an exchange.** Press A and the bout freezes so you can pick an
   attack: direct lunge, disengage, step-lunge, beat-lunge, feint-disengage or
   flèche. When the CPU attacks, the bout freezes and you pick a defence
   (simple parry, circular parry, retreat or counterattack) without knowing
   which attack is coming.
2. **Deciding the result.** Both choices are compared like rock-paper-scissors,
   following the real "tactical wheel":
   - a parry stops a direct attack;
   - a disengage or feint deceives a simple parry, and a circular parry catches
     a disengage;
   - a counterattack beats a feint, but loses to a direct attack or a beat;
   - a retreat makes a lunge fall short, but not a step-lunge or a flèche.
3. **Adjusting the odds.** Three things shift the chances:
   - **Distance:** a lunge from too far falls short, and retreating with no
     room behind can cost a touch.
   - **Ratings:** attack, defence, timing and footwork. Yours grow with the
     training drills you complete and with your wins.
   - **Habits:** stronger CPUs notice what you pick often and counter it. The
     menu also shows what the CPU has picked most so far.
4. **Seeing it play out.** The result is drawn at random from those odds, then
   played in slow motion by the normal fencers and referee. The lights, right
   of way and the referee's call are the real ones.
5. **Continuing the exchange.**
   - After a parry: the side that parried picks a riposte (direct, indirect or
     delayed), and the other side picks a counter-parry, a remise or recovering
     back.
   - After an attack that falls short: the defender may attack the opponent
     while they recover.
   - Otherwise everyone returns to free movement until the next attack.

**Pe scurt, în română.** Te miști liber, în timp real (←/→, L1/R1), dar
acțiunile cu arma le alegi din meniuri.

1. **Începutul fazei.** Apeși A și asaltul se oprește ca să alegi atacul:
   fandare directă, degajament, pas-fandare, bătaie-fandare, fentă-degajament
   sau fleșă. Când atacă adversarul, asaltul se oprește și alegi apărarea
   (paradă simplă, paradă circulară, retragere sau contraatac), fără să știi ce
   atac vine.
2. **Cine câștigă faza.** Cele două alegeri se compară ca la
   piatră-foarfecă-hârtie, după „roata tactică" din scrima reală:
   - parada oprește atacul direct;
   - degajamentul și fenta înșală parada simplă, iar parada circulară prinde
     degajamentul;
   - contraatacul bate fenta, dar pierde în fața atacului direct și a bătăii;
   - retragerea face ca fandarea să rămână scurtă, dar nu și pas-fandarea sau
     fleșa.
3. **Ce modifică șansele.**
   - **Distanța:** o fandare de prea departe rămâne scurtă, iar retragerea fără
     spațiu în spate poate costa o tușă.
   - **Atributele:** atac, apărare, simțul timpului și deplasare. Ale tale cresc
     cu exercițiile de antrenament făcute și cu victoriile.
   - **Obiceiurile:** adversarii mai buni observă ce alegi des și răspund pe
     măsură. Meniul îți arată și ție ce a ales adversarul cel mai des până acum.
4. **Faza pe planșă.** Rezultatul se trage la sorți după aceste șanse, apoi e
   jucat cu încetinitorul de aceiași scrimeri și același arbitru ca într-un
   asalt normal: lămpile, prioritatea și decizia arbitrului sunt cele reale.
5. **Continuarea fazei.**
   - După o paradă: cel care a parat alege riposta (directă, indirectă sau
     întârziată), iar celălalt alege contraparada, remiza sau revenirea înapoi.
   - După un atac scurt: cel care s-a apărat poate ataca pe revenirea
     adversarului.
   - Altfel, amândoi se mișcă din nou liber până la următorul atac.

#### In detail

| Attacks | Defences | Ripostes | Answers to a riposte |
|---|---|---|---|
| Direct lunge | Simple parry | Direct | Counter-parry |
| Disengage | Circular parry | Indirect (with a disengage) | Remise |
| Step-lunge | Retreat | Delayed | Recover back |
| Beat-lunge | Counterattack | | |
| Feint-disengage (one-two) | | | |
| Flèche | | | |

The outcome is drawn from how each choice fares against the other one, the
fencing **tactical wheel**: the parry stops a simple attack; the disengage and
the feint deceive a simple parry, and the circular parry catches the disengage;
the counterattack has no priority against a simple attack but lands a tempo
ahead of a feint or a step forward; the beat spoils a stop-hit; a retreat makes
a lunge fall short, but a step-lunge or a flèche can still reach. A direct
riposte beats a remise, the counter-parry stops a direct riposte, and a delayed
riposte loses to the remise. Then:

- **Distance** counts: a lunge from step-lunge distance usually falls short, a
  step-lunge from too close ends in body contact, and a retreat with your back
  line behind you can cost a touch. The menu shows the distance.
- **Ratings** (attack, defence, timing and footwork, shown before the first
  touch) shift the odds. The opponent's come from its level and style; yours
  start at club level and rise with each training drill completed and with your
  wins.
- **The opponent reads you.** Stronger opponents keep count of what you choose
  and answer it. You can read them too: the menu shows what they have chosen
  most so far.

The exchange is then fenced out in slow motion by the same fencers, scoring box
and referee as a real-time bout, so the lamps, the priority and the referee's
call are those of the real rules. With **Options → Assists** on, the banner over
the fencers shows the chance the attack had.

### Career

Work up a ladder of six competitions. Each is run like a real event: two pools
of six (bouts to 5, in the FIE bout order), a ranking by victories/matches,
indicator and touches scored, then a direct elimination table of 8. You fence
your own bouts; the others are simulated from the fencers' ratings. A medal
(top 3) unlocks the next competition. The career is saved after every bout; you
can leave a bout from the pause menu and fence it later.

When a competition starts you choose arcade or tactical mode for your bouts.
A switch in the pause menu holds for the rest of that competition, and the
event screen shows the current mode. The National Championships are fenced
only between fencers of your own nationality.

Fencers go by one name, as on a fencing scoreboard.

| Competition | Opponents | DE bouts to |
|---|---|---|
| Club Open | Novice to Club | 10 |
| Regional Circuit | Novice to Club | 10 |
| National Championships | Club to National | 15 |
| Satellite Cup | Club to National | 15 |
| World Cup | National to Elite | 15 |
| World Championships | National to Elite | 15 |

### Training

Eight drills with a scripted coach. Success is judged from the referee's real
decisions, so they teach the actual rules.

| Drill | What it teaches |
|---|---|
| 1. Footwork | Steps and jumps: put your front foot in the marked zone |
| 2. The lunge | Hitting from the right distance; a lunge from too far falls short |
| 3. High and low | The coach guards a line and parries it: attack the open one |
| 4. Parry-riposte | Parry in the line of the attack, riposte with X |
| 5. Attack first | Attack into the coach's preparation to take the priority |
| 6. Point in line | Beat the blade, then attack |
| 7. Disengage | The coach parries the line you start in: change it mid-lunge |
| 8. Flèche | Score from long distance with the flèche or a balestra-lunge |

## The AI

Opponents play through a virtual gamepad, so they have exactly your moves and
timings. They only react to what they could have seen: an attack is noticed
after a reaction time, the parry goes into the line the attack was in at that
moment (a late change of line fools them), and distance is judged with an error.

| Level | Reaction | Parry timing error (sd) | Speed | Reads a disengage |
|---|---|---|---|---|
| Novice | 0.36 s | 90 ms | 82% | never |
| Club | 0.28 s | 60 ms | 90% | 20% |
| National | 0.22 s | 42 ms | 96% | 45% |
| Elite | 0.17 s | 28 ms | 100% | 70% |

Styles: **all-rounder**, **attacker** (presses, beats, attacks), **counter-puncher**
(waits, attacks your preparation, holds a point in line), **defender** (parries
and ripostes) and **flècheur**. In the career you see your next opponent's style
on the pool sheet.

`./build.sh test` fences AI against AI headless and reports how the touches were
scored. Between Elite fencers of all styles, about half the touches are attacks,
four in ten parry-ripostes and the rest beat-attacks and counterattacks, which is
roughly the mix of real top-level foil.

## Animation

The fencers are a procedural skeleton, animated to move like people rather than
cut-outs. Rotoscoped games of the late 1980s were the inspiration: weight,
momentum and follow-through, not any one game's frames.

- **Momentum.** The pelvis follows a velocity-continuous path: held steps flow
  into each other at a steady 1.25 m/s instead of stopping between steps, and
  letting go decelerates smoothly onto the step's mark (so distances stay exact).
- **Secondary motion.** Damped springs on the hips, trunk, head, rear arm and a
  resting blade add lag, overshoot and settle, driven by the fencer's speed and
  by impacts: a foot planting, the lunge landing, a jump taken in the knees, a
  parry's clang, the flinch of being touched.
- **Feet** roll heel to toe. The lunge kicks the front foot out toe-up and slaps
  it flat; a balestra crouches before it leaps.
- **Alive on guard:** a light bounce in the knees, breathing, and the point
  circling. A parry snaps through with a slight overshoot.
- **The body wire** hangs from a clip on the back of the jacket to the reel at
  the end of the piste, held taut by the reel's spring: retreating towards the
  reel gives it a little slack, advancing pulls it tight, and sudden moves leave
  a small wobble.
- **Between touches** the fencers stand up, turn round and walk back to their
  lines with a real stride and swinging arms, then step back into guard on
  *En garde!*.
- **Pixel-stable:** fencers and camera move in whole pixels, so the limbs keep
  their shape instead of shimmering.

The rules use the same skeleton, so the target you see is always the target
that counts. `./build.sh test` re-measures every action's reach and timing for
the AI.

## Pixel art

Everything is drawn into a canvas of 240×160, 360×240 or 720×480 (see
Resolution) and scaled by a whole number to fill the panel. Nothing is loaded
from files:

- **Fencers** are rasterised every frame from their skeleton: each limb is a filled
  quad with a 1-pixel ink outline, drawn back to front, with far limbs shaded. The
  hips and front leg are outlined as one silhouette and the jacket's hem overlaps
  them, so the leg grows out of the body instead of being stuck on. So
  the art always matches the geometry the rules use: the lamé you see is exactly
  the target, and the blade bends where it hit. The legs use two-bone IK.
- **Hand-drawn** pixel sprites: the fencing mask (9×10, and 14×15 for the finer
  resolutions), the title's crossed foils, two fonts (5×7 and 7×10; accented
  capitals are built from the base letter and its accent), and 112 flags at 9×6.
- **Generated** at start-up: the tiered crowd (with a cheering frame), dithered
  light shafts, the LED barrier boards and the floor.
- **Sound** is synthesised at start-up too: steel on steel from inharmonic
  partials, the scoring-box buzzer, feet on the metal piste, and the crowd.

## Resolution

**Options → Resolution** picks how finely the game is drawn. Each choice scales
by a whole number to the RG34XXSP's 720×480 panel, so pixels stay crisp:

| Setting | Scale | Fencer height | Look |
|---|---|---|---|
| 240×160 | ×3 | 47 px | Chunky pixel art |
| 360×240 (default) | ×2 | 70 px | Finer pixel art, more detailed mask |
| 720×480 | ×1 | 140 px | Full panel resolution, smooth limbs |

![The same lunge and parry at 240×160, 360×240 and 720×480](screenshots/resolutions.png)

There is no 480×320: 720 ÷ 480 = 1.5, so it can't fill the panel without
uneven pixels or blur.

Menus and text keep the same layout and size at every setting. Screens are laid
out once, and the drawing helpers map them to whole canvas pixels with a font
made for each resolution: the 5×7 font at 240×160, a 7×10 font at 360×240 and
the same doubled at 720×480. The arena and the fencers are drawn natively, at
30, 45 or 90 px per metre. That's where the extra detail goes: finer outlines,
blades and limbs, and a 14×15 mask instead of 9×10. The crowd, the LED boards
and the floor are generated at 360×240 density and doubled at 720×480, so the
backdrop keeps its pixel grain.

## Built for the handheld

- **Simulation** at a fixed 120 Hz, independent of the frame rate.
- **Rendering** stays cheap for the Mali-G31: static layers are pre-rendered images;
  per frame it's two fencers, a few dozen polygons and some text.
- **Input** is SDL gamepad first. On the device, if a gamepad is detected,
  keyboard events from gptokeyb are ignored so no button is read twice. The
  left stick, if there is one, works as the D-pad. *Options → Swap A/B* is there
  for pads that label them the other way round.

## Development

```sh
./build.sh                # all packages: dist/rgfencing.love, *_portmaster.zip, *.muxapp
./build.sh muos           # just the muxapp (also: portmaster, love)
./build.sh test 10        # headless: AI vs AI, levels and styles, touch statistics
./build.sh drills         # headless: a scripted student completes every drill
./build.sh tactics 2      # headless: every tactical exchange staged as drawn, then CPU-vs-CPU bouts
./build.sh smoke          # drives every screen with scripted input (opens a window; "smoke ro" in Romanian)
./build.sh shots          # renders the README screenshots and clip (clip needs Python + Pillow)
./build.sh run            # play on this PC
```

To look at motion frame by frame, the film mode drives the left fencer with a
scripted button timeline and saves a contact sheet plus single frames to the
save directory:

```sh
love . --shot walk --mode film --act walk        # also: advance lunge parry fleche jump idle hit
love . --shot bout --mode film --act bout --every 2 --start 1.2 --dur 7   # whole screen, AI vs AI
```

The muxapp's LÖVE runtime comes from [2048 Plus](https://github.com/saitamasahil/2048plus)
(pinned tag, MIT); a copy already cached by RG Lander or rgTrek is reused. Set
`LOVE_RUNTIME=/path/to/dir` (containing `love` and `libs.aarch64/`) to use your own.

| File | What it does |
|---|---|
| `src/fencer.lua` | Skeleton, footwork, lunge, flèche, extension, parry, beat |
| `src/bout.lua` | The rules: phases, lockout, right of way, decisions, time |
| `src/ai.lua` | The AI: levels, styles, perception, distance, defence |
| `src/controller.lua` | Pad → fencer commands, shared by the player, the AI and the coaches |
| `src/view.lua` | Drawing a bout: arena, piste, referee, fencers, HUD |
| `src/career.lua`, `src/training.lua` | The career and the drills |
| `src/profile.lua`, `src/profiles_ui.lua` | Profiles; the name keyboard, nation picker and profile screen |
| `src/nations.lua` | 112 nations and their pixel flags |
| `src/tactics.lua` | Tactical bout: the actions, the odds, the CPU's choices and the staging of each outcome |
| `src/tactical.lua` | Bouts against the CPU, arcade or tactical and switchable mid-bout; the tactical menus, the banner, the ratings card |
| `src/i18n.lua`, `src/lang_ro.lua` | Languages; the Romanian table is generated by `tools/lang_ro.py` |
| `tools/font360.py` | Generates the 7×10 font (`src/font360.lua`) |

## License

MIT, see [LICENSE](LICENSE).
