#!/bin/bash
# RG Fencing: build script
#
#   ./build.sh             build everything below into dist/
#   ./build.sh muos        muOS package       -> dist/RGFencing_vX.Y.Z.muxapp
#   ./build.sh portmaster  PortMaster package -> dist/rgfencing_vX.Y.Z_portmaster.zip
#   ./build.sh love        game only          -> dist/rgfencing.love
#   ./build.sh test [N]    headless AI-vs-AI self-test, N bouts per pairing
#   ./build.sh drills      headless check that every training drill can be completed
#   ./build.sh tactics [N] headless check of the tactical bout: every exchange staged
#                          as drawn, then N CPU-vs-CPU bouts per style pairing
#   ./build.sh wheel [N]   headless check of the wheel bout: every pairing staged as
#                          the wheel says, then N CPU-vs-CPU bouts per style pairing
#   ./build.sh smoke       drive every screen with scripted input (opens a window
#                          briefly; add "ro" to run it in Romanian)
#   ./build.sh shots       render the README screenshots into screenshots/
#   ./build.sh showcase    render just the README's showcase GIF (needs ffmpeg)
#   ./build.sh run [args]  run the game on this PC (needs LÖVE 11.x)
#
# The muxapp bundles an aarch64 LÖVE 11.5 runtime (bin/love + bin/libs.aarch64),
# as RG Lander and rgTrek do. By default it is taken from the 2048 Plus project
# (MIT licensed, proven on muOS H700 devices) at a pinned tag. To use your own
# runtime, set LOVE_RUNTIME=/path/to/dir containing love and libs.aarch64/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$ROOT/dist"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE="$CACHE_ROOT/rgfencing"
MUX_NAME="RGFencing"
RUNTIME_REPO="https://github.com/saitamasahil/2048plus.git"
RUNTIME_TAG="v7.0.1"
GAME_FILES=(main.lua conf.lua src)

VERSION="$(sed -n 's/^ *VERSION = "\([0-9.]*\)",$/\1/p' "$ROOT/src/core.lua")"
[ -n "$VERSION" ] || { echo "Could not read VERSION from src/core.lua" >&2; exit 1; }

fetch_runtime() {
    RUNTIME_LICENSES=""
    if [ -n "${LOVE_RUNTIME:-}" ]; then
        [ -x "$LOVE_RUNTIME/love" ] && [ -d "$LOVE_RUNTIME/libs.aarch64" ] || {
            echo "LOVE_RUNTIME must contain 'love' and 'libs.aarch64/'" >&2; exit 1; }
        RUNTIME_DIR="$LOVE_RUNTIME"
        return
    fi
    # the same pinned runtime may already be cached by a sibling project
    local checkout=""
    for c in "$CACHE" "$CACHE_ROOT/rglander" "$CACHE_ROOT/rgtrek"; do
        if [ -x "$c/runtime-$RUNTIME_TAG/bin/love" ] && [ -d "$c/runtime-$RUNTIME_TAG/bin/libs.aarch64" ]; then
            checkout="$c/runtime-$RUNTIME_TAG"
            break
        fi
    done
    if [ -z "$checkout" ]; then
        checkout="$CACHE/runtime-$RUNTIME_TAG"
        echo "Downloading aarch64 LÖVE runtime from 2048 Plus ($RUNTIME_TAG)..."
        rm -rf "$checkout"
        mkdir -p "$CACHE"
        git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$RUNTIME_TAG" \
            --filter=blob:none --sparse "$RUNTIME_REPO" "$checkout"
        git -C "$checkout" sparse-checkout set bin licenses >/dev/null
    fi
    RUNTIME_DIR="$checkout/bin"
    RUNTIME_LICENSES="$checkout/licenses"
}

copy_game() {
    local dest="$1"
    mkdir -p "$dest"
    (cd "$ROOT" && tar --exclude='.DS_Store' -cf - "${GAME_FILES[@]}") | (cd "$dest" && tar -xf -)
}

build_love() {
    local stage="$DIST/love-stage"
    local out="$DIST/rgfencing.love"
    rm -rf "$stage" "$out"
    copy_game "$stage"
    (cd "$stage" && zip -qr -X "$out" .)
    rm -rf "$stage"
    echo "Built $(basename "$out")  (run with: love dist/rgfencing.love)"
}

build_portmaster() {
    local stage="$DIST/pm-stage"
    local out="$DIST/rgfencing_v${VERSION}_portmaster.zip"
    rm -rf "$stage" "$out"
    copy_game "$stage/rgfencing/gamedata"
    cp "$ROOT/LICENSE" "$stage/rgfencing/LICENSE"
    cp "$ROOT/port/RG Fencing.sh" "$stage/"
    chmod +x "$stage/RG Fencing.sh"
    (cd "$stage" && zip -qr -X "$out" "RG Fencing.sh" rgfencing)
    rm -rf "$stage"
    echo "Built $(basename "$out")  (unzip into the SD card's ports/ folder)"
}

build_muos() {
    fetch_runtime
    local stage="$DIST/mux-stage"
    local app="$stage/$MUX_NAME"
    local out="$DIST/${MUX_NAME}_v${VERSION}.muxapp"
    rm -rf "$stage" "$out"
    mkdir -p "$app/glyph" "$app/.game/bin" "$app/.game/licenses"

    cp "$ROOT/muos/mux_launch.sh" "$ROOT/muos/mux_lang.ini" "$app/"
    cp "$ROOT/muos/glyph/rgfencing.svg" "$ROOT/muos/glyph/rgfencing.png" "$app/glyph/"
    copy_game "$app/.game"
    cp "$RUNTIME_DIR/love" "$app/.game/bin/"
    cp -R "$RUNTIME_DIR/libs.aarch64" "$app/.game/bin/"

    cp "$ROOT/LICENSE" "$app/.game/licenses/rgfencing.LICENSE"
    if [ -n "$RUNTIME_LICENSES" ] && [ -f "$RUNTIME_LICENSES/love.LICENSE" ]; then
        cp "$RUNTIME_LICENSES/love.LICENSE" "$app/.game/licenses/love.LICENSE"
        cp "$RUNTIME_LICENSES/2048plus.LICENSE" "$app/.game/licenses/runtime-from-2048plus.LICENSE" 2>/dev/null || true
    fi

    chmod +x "$app/mux_launch.sh" "$app/.game/bin/love"
    (cd "$stage" && zip -qr -X "$out" "$MUX_NAME")
    rm -rf "$stage"
    echo "Built $(basename "$out") ($(du -h "$out" | cut -f1))"
    echo "  Copy it to /mnt/mmc/MUOS/ARCHIVE/ and install with Applications > Archive Manager."
}

find_love() {
    if command -v love >/dev/null 2>&1; then
        echo love
    elif [ -x /Applications/love.app/Contents/MacOS/love ]; then
        echo /Applications/love.app/Contents/MacOS/love
    else
        echo "LÖVE 11.x not found. Install it from https://love2d.org" >&2
        return 1
    fi
}

# Where LÖVE keeps the game's save files, and so the rendered shots.
save_dir() {
    case "$(uname)" in
        Darwin) echo "$HOME/Library/Application Support/LOVE/rgfencing" ;;
        *) echo "${XDG_DATA_HOME:-$HOME/.local/share}/love/rgfencing" ;;
    esac
}

# The showcase GIF at the top of the README: the reel of src/reel.lua,
# played and captured by the game (30 fps at 360x240), then put together by
# ffmpeg, which stores only the pixels that change from one frame to the
# next. Needs ffmpeg, and Python 3 with Pillow.
build_showcase() {
    local love dir
    love="$(find_love)"
    command -v ffmpeg >/dev/null 2>&1 || { echo "The showcase GIF needs ffmpeg: skipped" >&2; return 0; }
    (cd "$ROOT" && "$love" . --shot showcase --mode reel --res 2 >/dev/null)
    dir="$(save_dir)"
    # frames with few colours are saved as palette PNGs: give ffmpeg one format
    python3 - "$dir" <<'PY' | ffmpeg -v error -y -f rawvideo -pix_fmt rgb24 -s 360x240 -framerate 30 -i - \
        -vf "scale=iw*2:ih*2:flags=neighbor,split[a][b];[a]palettegen=max_colors=256:stats_mode=full:reserve_transparent=1[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" \
        -loop 0 "$ROOT/screenshots/showcase.gif"
import glob, sys
from PIL import Image
for f in sorted(glob.glob(sys.argv[1] + "/showcase_[0-9][0-9][0-9][0-9].png")):
    sys.stdout.buffer.write(Image.open(f).convert("RGB").tobytes())
PY
    echo "Built screenshots/showcase.gif ($(( $(wc -c < "$ROOT/screenshots/showcase.gif") / 1024 )) KB)"
}

# Screenshots for the README, rendered by the game itself at 720x480.
build_shots() {
    local love
    love="$(find_love)"
    mkdir -p "$ROOT/screenshots"
    run_shot() {
        local name="$1"; shift
        (cd "$ROOT" && "$love" . --shot "$name" --res 2 "$@" >/dev/null)
    }
    run_shot title --mode title --time 4
    run_shot lunge --mode pose --pose lunge,parry --gap 2.15 --time 0.6
    run_shot decision --mode bout --until decision:2 --hold 0.5 --time 1 --seed 12
    run_shot lockout --mode bout --until lockout:2 --hold 0.12 --time 1 --seed 5
    run_shot salute --mode demo --time 1.0
    run_shot pool --mode pool --time 0.5 --seed 4
    run_shot bracket --mode bracket --time 0.5 --seed 4
    run_shot drill --mode drill --drill 3 --go 1 --time 2.2
    run_shot training --mode training --time 0.5
    run_shot quick --mode quick --time 1.5
    run_shot profile --mode profile --time 0.5
    run_shot keyboard --mode keyboard --time 0.5
    run_shot tactical --mode tactical --menu attack --sel 2 --time 0.3
    run_shot exchange --mode tactical --exchange feint,counter,counter --time 0.9
    run_shot romana --mode tactical --menu defend --sel 3 --time 0.3 --lang 2
    run_shot modes --mode choose --time 0.5
    run_shot wheel --mode wheel --menu wheel2 --sel 4 --time 0.3
    run_shot wheelex --mode wheel --exchange wline,wdirect --time 0.9
    run_shot bout --mode film --act bout --every 2 --start 1.2 --dur 7 --seed 21
    for r in 1 2 3; do
        (cd "$ROOT" && "$love" . --shot "res$r" --res "$r" --mode pose --pose lunge,parry --gap 2.15 --time 0.6 >/dev/null)
    done
    local dir
    dir="$(save_dir)"
    for f in title lunge decision lockout salute pool bracket drill training quick profile keyboard tactical exchange romana modes wheel wheelex; do
        cp "$dir/$f.png" "$ROOT/screenshots/$f.png"
    done
    # the animated bout clip and the resolution comparison (needs Python 3 with Pillow)
    python3 - "$dir" "$ROOT/screenshots" <<'PY'
import glob, sys
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
fr = [Image.open(f).convert("RGB") for f in sorted(glob.glob(src + "/bout_[0-9][0-9][0-9].png"))]
k = 720 // fr[0].width
fr = [f.resize((f.width * k, f.height * k), Image.NEAREST).quantize(colors=96, method=Image.MEDIANCUT) for f in fr]
fr[0].save(out + "/bout.gif", save_all=True, append_images=fr[1:], duration=33, loop=0, optimize=True)
crops = [Image.open(src + "/res%d.png" % r).convert("RGB").crop((190, 200, 550, 400)) for r in (1, 2, 3)]
sheet = Image.new("RGB", (360 * 3 + 8, 200), (21, 17, 28))
for i, c in enumerate(crops):
    sheet.paste(c, (i * 364, 0))
sheet.save(out + "/resolutions.png")
PY
    echo "Screenshots in screenshots/"
}

mkdir -p "$DIST"
case "${1:-all}" in
    all) build_love; build_portmaster; build_muos ;;
    love) build_love ;;
    portmaster) build_portmaster ;;
    muos) build_muos ;;
    test) (cd "$ROOT" && "$(find_love)" . --autotest "${2:-10}") ;;
    drills) (cd "$ROOT" && "$(find_love)" . --autotest drills) ;;
    tactics) (cd "$ROOT" && "$(find_love)" . --autotest tactics --n "${2:-2}") ;;
    wheel) (cd "$ROOT" && "$(find_love)" . --autotest wheel --n "${2:-2}") ;;
    smoke) (cd "$ROOT" && "$(find_love)" . --smoke --windowed --lang "$([ "${2:-}" = ro ] && echo 2 || echo 1)") ;;
    shots) build_shots; build_showcase ;;
    showcase) build_showcase ;;
    run)
        shift
        LOVE_BIN="$(find_love)"
        cd "$ROOT" && "$LOVE_BIN" . "$@"
        ;;
    *) echo "Usage: ./build.sh [all|muos|portmaster|love|test|drills|tactics|wheel|smoke|shots|showcase|run]" >&2; exit 1 ;;
esac
