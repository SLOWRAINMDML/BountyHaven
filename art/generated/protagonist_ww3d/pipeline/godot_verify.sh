#!/bin/zsh
# ./godot_verify.sh <out_dir>  — import + capture in Godot 4.7.1, then a contact sheet <out_dir>/godot.png
set -e
cd "$(dirname "$0")"
OUT=$(cd "$1" && pwd)
G=${GODOT:-$HOME/project/Godot/Godot-4.7.1/Godot.app/Contents/MacOS/Godot}
REPO=$(cd ../../../.. && pwd)
$G --headless --path $REPO --import > $OUT/godot_import.log 2>&1
$G --path $REPO --resolution 1000x1000 res://art/generated/protagonist_ww3d/godot/hero_ww_preview.tscn -- --capture $OUT/godot_caps > $OUT/godot_run.log 2>&1
grep -E "CAPTURED|ANIMS|CAPTURE_DONE|ERROR" $OUT/godot_run.log
python3 - "$OUT" <<'PY'
import sys
from PIL import Image
d = sys.argv[1]
ims = [Image.open(f"{d}/godot_caps/godot_{n}.png").convert("RGB") for n in ("front", "q34", "side", "back", "face", "vfx")]
h = 520
ims = [i.resize((int(i.width * h / i.height), h)) for i in ims]
ims[:4] = [i.crop((i.width // 4, 0, i.width * 3 // 4, h)) for i in ims[:4]]
s = Image.new("RGB", (sum(i.width for i in ims) + 10 * len(ims), h), (20, 22, 28))
x = 0
for i in ims:
    s.paste(i, (x, 0)); x += i.width + 10
s.save(f"{d}/godot.png")
PY
