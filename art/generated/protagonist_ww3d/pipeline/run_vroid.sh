#!/bin/zsh
# ./run_vroid.sh <NN> "<note>" [extra blender args] -> iterations/vroid_vNN/ (body sheet + face sheet + scores)
set -e
cd "$(dirname "$0")"
N=$1; NOTE=$2; shift 2
D=../iterations/vroid_v$N
mkdir -p $D/src
python3 ww_textures.py
blender -b --factory-startup -P ww_build.py -- --out $D --views --face --expr "$@" 2>&1 | grep -E "Error|Traceback|error:" || true
for f in vfx vfx2 beauty expr; do [ -f $D/${f}_raw.png ] && python3 post_bloom.py $D/${f}_raw.png $D/$f.png; done
python3 ww_compare.py $D "$NOTE" | tail -1
python3 ww_face_score.py $D "$NOTE" | tail -1
[ -f $D/expr_neutral.png ] && python3 expr_sheet.py $D
cp ww_*.py expr_sheet.py ../measure/face/face_spec.json $D/src/
{ echo "# vroid_v$N"; echo; echo "$NOTE"; } > $D/notes.md
