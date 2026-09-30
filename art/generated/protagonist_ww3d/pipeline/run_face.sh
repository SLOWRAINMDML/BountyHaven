#!/bin/zsh
# ./run_face.sh <NN> "<note>" [extra blender args] -> iterations/face_iterNN/{fface_*.png, face_sheet.png, face_score.json, notes.md, src/}
set -e
cd "$(dirname "$0")"
N=$1; NOTE=$2; shift 2
D=../iterations/face_iter$N
mkdir -p $D/src
python3 ww_textures.py
blender -b --factory-startup -P ww_build.py -- --out $D --face "$@" 2>&1 | grep -E "Error|Traceback|error:" || true
python3 ww_face_score.py $D "$NOTE"
cp ww_build.py ww_face.py ww_textures.py ../measure/face/face_spec.json $D/src/
{ echo "# face_iter$N"; echo; echo "$NOTE"; } > $D/notes.md
