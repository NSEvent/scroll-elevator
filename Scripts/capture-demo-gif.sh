#!/bin/bash
set -euo pipefail

# capture-demo-gif.sh — a short looping marketing GIF of Scroll Elevator:
# scroll down a long document, the elevator buttons appear, click jump-to-top,
# then hold to cruise. Records the full screen with screencapture's video mode
# and crops to the demo window (screencapture mis-maps -R on scaled displays,
# so we record full-screen and crop in ffmpeg).
#
# For a legible marketing clip it temporarily raises the idle opacity and sets
# a fixed button distance, then RESTORES your real settings on exit. It drives
# synthetic input, so it takes over the pointer for ~12s — don't touch the mouse.
#
# Requirements: ffmpeg (brew install ffmpeg) and Screen Recording permission
# for the terminal/host process. Scroll Elevator must be installed.
#
# Output: marketing/scroll-elevator-demo.gif (~620px wide, looping)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$ROOT/marketing"
mkdir -p "$OUT_DIR"

DURATION=12
FPS=18
GIF_WIDTH=620
APP_NAME="Scroll Elevator"
BUNDLE="xyz.kevintang.ScrollElevator"

command -v ffmpeg >/dev/null || { echo "ffmpeg required: brew install ffmpeg" >&2; exit 1; }

# Palette-optimized looping GIF, scaled to GIF_WIDTH. Shared by both modes.
to_gif() {  # <src.mov> <out.gif> [crop=w:h:x:y]
    local crop=""; [[ -n "${3:-}" ]] && crop="crop=$3,"
    ffmpeg -y -loglevel error -i "$1" \
        -vf "${crop}fps=$FPS,scale=$GIF_WIDTH:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
        -loop 0 "$2"
    echo "Wrote $2 ($(du -h "$2" | cut -f1 | tr -d ' '))"
}

# Recommended path: record ~8-12s yourself (QuickTime ⌘⇧5, or `screencapture -v
# clip.mov`) showing a real scroll → buttons → jump → hold-to-cruise, then:
#   ./Scripts/capture-demo-gif.sh --convert clip.mov
# A natural recording of the real app beats synthetic input every time.
if [[ "${1:-}" == "--convert" ]]; then
    SRC="${2:?usage: capture-demo-gif.sh --convert <recording.mov> [WxH+X+Y]}"
    CROP=""
    if [[ -n "${3:-}" ]]; then  # optional ImageMagick-style geometry WxH+X+Y -> ffmpeg w:h:x:y
        CROP="$(echo "$3" | sed -E 's/([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)/\1:\2:\3:\4/')"
    fi
    to_gif "$SRC" "$OUT_DIR/scroll-elevator-demo.gif" "$CROP"
    exit 0
fi

restart_app() { pkill -x "$APP_NAME" 2>/dev/null || true; sleep 1; open -a "$APP_NAME" 2>/dev/null || true; sleep 2; }

# Save real settings; force legible demo values; restore on any exit.
ORIG_OPACITY="$(defaults read "$BUNDLE" idleOpacity 2>/dev/null || echo 0.3)"
ORIG_DIST="$(defaults read "$BUNDLE" placementDistance 2>/dev/null || echo 56)"
restore() {
    defaults write "$BUNDLE" idleOpacity -float "$ORIG_OPACITY"
    defaults write "$BUNDLE" placementDistance -float "$ORIG_DIST"
    restart_app
    [[ -n "${TMP_DIR:-}" ]] && rm -rf "$TMP_DIR"
    [[ -n "${DOC:-}" ]] && rm -f "$DOC"
}
trap restore EXIT INT TERM

defaults write "$BUNDLE" idleOpacity -float 0.92
defaults write "$BUNDLE" placementDistance -float 64
DIST=64

# --- A sparse, calm document so the translucent buttons pop over whitespace.
# Unique filename per run so TextEdit loads fresh content (it won't reload an
# already-open file). ---
DOC="/tmp/se-demo-$$.txt"
python3 - > "$DOC" <<'PY'
out = []
out += ["", "", "        ↑   T O P   ·   Scroll Elevator", "", "", ""]
for i in range(1, 41):
    out += [f"        Section {i:>2}", "", "", ""]
out += ["", "        ↓   B O T T O M   ·   you made it", ""]
print("\n".join(out))
PY

restart_app
open -a TextEdit "$DOC"

# Wait for our TextEdit window. CGWindowList is front-to-back, so the FIRST
# TextEdit window is the one we just opened (frontmost) — picking it avoids
# disturbing any other TextEdit docs.
BOUNDS="$(python3 - <<'PY'
import time, sys, Quartz
opts = Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements
for _ in range(40):
    for w in Quartz.CGWindowListCopyWindowInfo(opts, Quartz.kCGNullWindowID) or []:
        if w.get("kCGWindowOwnerName") == "TextEdit" and int(w.get("kCGWindowLayer", 99)) == 0:
            b = w["kCGWindowBounds"]
            if b["Width"] * b["Height"] > 60000:
                print(f'{int(b["X"])} {int(b["Y"])} {int(b["Width"])} {int(b["Height"])}'); sys.exit(0)
    time.sleep(0.25)
sys.exit(1)
PY
)" || { echo "ERROR: TextEdit window never appeared" >&2; exit 1; }
read -r WX WY WW WH <<< "$BOUNDS"

# Best-effort: enlarge the window with a synthetic bottom-right corner drag.
python3 - "$WX" "$WY" "$WW" "$WH" <<'PY' || true
import sys, time, Quartz
WX, WY, WW, WH = (int(a) for a in sys.argv[1:5])
def post(ev): Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
def mev(t,x,y): post(Quartz.CGEventCreateMouseEvent(None, t, (x, y), Quartz.kCGMouseButtonLeft))
sx, sy = WX+WW-2, WY+WH-2
tx, ty = min(WX+WW+430, 1500), min(WY+WH+300, 1300)
Quartz.CGWarpMouseCursorPosition((sx, sy)); time.sleep(0.1)
mev(Quartz.kCGEventLeftMouseDown, sx, sy); time.sleep(0.05)
for i in range(1, 19):
    t=i/18; mev(Quartz.kCGEventLeftMouseDragged, sx+(tx-sx)*t, sy+(ty-sy)*t); time.sleep(0.012)
mev(Quartz.kCGEventLeftMouseUp, tx, ty)
PY
sleep 0.5
# Re-fetch bounds after the resize.
BOUNDS="$(python3 - <<'PY'
import Quartz
opts = Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements
for w in Quartz.CGWindowListCopyWindowInfo(opts, Quartz.kCGNullWindowID) or []:
    if w.get("kCGWindowOwnerName") == "TextEdit" and int(w.get("kCGWindowLayer", 99)) == 0:
        b = w["kCGWindowBounds"]
        if b["Width"] * b["Height"] > 60000:
            print(f'{int(b["X"])} {int(b["Y"])} {int(b["Width"])} {int(b["Height"])}'); break
PY
)"
read -r WX WY WW WH <<< "$BOUNDS"
echo "TextEdit window: ${WW}x${WH} @ (${WX},${WY})"

TMP_DIR="$(mktemp -d /tmp/se-gif.XXXXXX)"
CLIP="$TMP_DIR/clip.mov"

python3 -c "import Quartz; Quartz.CGWarpMouseCursorPosition(($WX + $WW/2, $WY + $WH/2))"
sleep 0.4

screencapture -v -V "$DURATION" "$CLIP" 2>/dev/null &
REC_PID=$!
sleep 1.0

# --- Synthetic demo driver ---
python3 - "$WX" "$WY" "$WW" "$WH" "$DIST" <<'PY'
import sys, time, Quartz
WX, WY, WW, WH, DIST = (float(a) for a in sys.argv[1:6])
cx, cy = WX + WW / 2, WY + WH / 2

def post(ev): Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
def move(x, y):
    Quartz.CGWarpMouseCursorPosition((x, y))
    post(Quartz.CGEventCreateMouseEvent(None, Quartz.kCGEventMouseMoved, (x, y), 0))
def glide(x0, y0, x1, y1, steps=16, dt=0.02):
    for i in range(1, steps + 1):
        t = i / steps
        move(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t); time.sleep(dt)
def scroll(amount, ticks=14, dt=0.022):
    for _ in range(ticks):
        post(Quartz.CGEventCreateScrollWheelEvent(None, Quartz.kCGScrollEventUnitPixel, 1, int(amount)))
        time.sleep(dt)
def press(x, y, hold):
    move(x, y); time.sleep(0.05)
    post(Quartz.CGEventCreateMouseEvent(None, Quartz.kCGEventLeftMouseDown, (x, y), Quartz.kCGMouseButtonLeft))
    time.sleep(hold)
    post(Quartz.CGEventCreateMouseEvent(None, Quartz.kCGEventLeftMouseUp, (x, y), Quartz.kCGMouseButtonLeft))

move(cx, cy); time.sleep(0.4)

# 1) Scroll down into the document — the elevator buttons appear.
scroll(-80, ticks=16)
time.sleep(0.9)

# 2) Hover the jump-to-top button (it goes solid), then click — snap to TOP.
glide(cx, cy, cx, cy - DIST)
time.sleep(0.7)
press(cx, cy - DIST, 0.12)
time.sleep(1.3)

# 3) Scroll down again, hover jump-to-bottom, then HOLD to cruise to BOTTOM.
scroll(-70, ticks=12)
time.sleep(0.6)
glide(cx, cy, cx, cy + DIST)
time.sleep(0.5)
press(cx, cy + DIST, 1.6)   # >0.35s engages hold-to-cruise
time.sleep(0.9)
PY

wait "$REC_PID" 2>/dev/null || true

# --- crop full-screen clip to the window, palette-optimized looping GIF ---
vidw="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$CLIP")"
dispw="$(python3 -c 'import Quartz; print(int(Quartz.CGDisplayBounds(Quartz.CGMainDisplayID()).size.width))')"
read -r cx cy cw ch <<< "$(python3 -c "
s = $vidw / $dispw
print(int($WX*s), int($WY*s), int($WW*s)//2*2, int($WH*s)//2*2)")"

to_gif "$CLIP" "$OUT_DIR/scroll-elevator-demo.gif" "${cw}:${ch}:${cx}:${cy}"
