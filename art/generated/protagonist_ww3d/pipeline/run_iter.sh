#!/bin/zsh
# ./run_iter.sh <NN> "<note>" [extra blender args]  -> iterations/iterNN/{views,sheet.png,score.json,notes.md,src/}
set -e
cd "$(dirname "$0")"
N=$1; NOTE=$2; shift 2
D=../iterations/iter$N
mkdir -p $D/src
python3 ww_textures.py
blender -b --factory-startup -P ww_build.py -- --out $D --views "$@" 2>&1 | grep -E "Error|Traceback|error:|Saved" | grep -v "^$" || true
for f in vfx vfx2 beauty; do [ -f $D/${f}_raw.png ] && python3 post_bloom.py $D/${f}_raw.png $D/$f.png; done
python3 ww_compare.py $D "$NOTE"
cp ww_build.py ww_render.py ww_rig.py ww_textures.py post_bloom.py $D/src/
echo "# iter$N\n\n$NOTE\n" > $D/notes.md
