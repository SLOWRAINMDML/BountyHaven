#!/bin/zsh
# ./godot_verify.sh <out_dir>  — import + capture in Godot 4.7.1, then a contact sheet <out_dir>/godot.png
set -e
cd "$(dirname "$0")"
OUT=$(cd "$1" && pwd)
G=${GODOT:-$HOME/project/Godot/Godot-4.7.1/Godot.app/Contents/MacOS/Godot}
REPO=$(cd ../../../.. && pwd)
$G --headless --path $REPO --import > $OUT/godot_import.log 2>&1
$G --path $REPO --resolution 1000x1000 res://art/generated/protagonist_ww3d/godot/hero_ww_preview.tscn -- --capture $OUT/godot_caps > $OUT/godot_run.log 2>&1
grep -E "CAPTURED|ANIMS|CAPTURE_DONE|ERROR|SPRING|SCRIPT ERROR" $OUT/godot_run.log
python3 - "$OUT" <<'PY'
import sys
from PIL import Image
d = sys.argv[1]
ims = [Image.open(f"{d}/godot_caps/godot_{n}.png").convert("RGB") for n in ("front", "q34", "side", "back", "face", "vfx")]
import os as _os
ex = [Image.open(f"{d}/godot_caps/godot_expr_{e}.png").convert("RGB") for e in ("neutral", "happy", "angry", "surprised", "blink", "aa") if _os.path.exists(f"{d}/godot_caps/godot_expr_{e}.png")]
h = 520
ims = [i.resize((int(i.width * h / i.height), h)) for i in ims]
ims[:4] = [i.crop((i.width // 4, 0, i.width * 3 // 4, h)) for i in ims[:4]]
s = Image.new("RGB", (sum(i.width for i in ims) + 10 * len(ims), h), (20, 22, 28))
x = 0
for i in ims:
    s.paste(i, (x, 0)); x += i.width + 10
s.save(f"{d}/godot.png")
if ex:
    h2 = 360
    ex = [i.crop((i.width // 2 - i.height // 3, i.height // 6, i.width // 2 + i.height // 3, i.height * 5 // 6)) for i in ex]
    ex = [i.resize((h2, int(i.height * h2 / i.width))) for i in ex]
    e2 = Image.new("RGB", (len(ex) * (h2 + 10), ex[0].height), (20, 22, 28))
    for k, i in enumerate(ex):
        e2.paste(i, (k * (h2 + 10), 0))
    e2.save(f"{d}/godot_expr.png")
PY
