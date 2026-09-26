#!/usr/bin/env python3
"""Publish the COMPLETE local ArtLibrary pack to SLOWRAINMDML/BountyHaven/main.
Python 3.10+, Git and an existing authorized Git login are required.
Default: preview in an isolated clone. --push explicitly commits and pushes.
The metadata-only repository does not contain the source PNGs: use the full ZIP.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from validate_art_library import validate

REPOSITORY='https://github.com/SLOWRAINMDML/BountyHaven.git'
TREES=('art/reference','docs/art')
FILES=('tools/art_gallery.gd','tools/art_gallery.tscn','tools/validate_art_library.py',
       'tools/publish_art_library.py','tools/test_art_library.py','ART_LIBRARY_START_HERE.md')


def git(cwd: Path, *args: str) -> str:
    p=subprocess.run(['git','-C',str(cwd),*args],text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if p.returncode:
        raise RuntimeError(f'Git failed: {args[0]}\n{p.stderr.strip()}')
    return p.stdout.strip()


def copy_pack(source: Path, destination: Path) -> list[str]:
    candidates=[]
    for rel in TREES:
        candidates.extend(p for p in (source/rel).rglob('*') if p.is_file())
    candidates.extend(source/rel for rel in FILES)
    paths=[]
    for p in candidates:
        if p.is_symlink() or not p.is_file():
            raise ValueError(f'Invalid pack file: {p}')
        relative=p.relative_to(source)
        if any(part in ('__pycache__','.godot','.git') for part in relative.parts):
            continue
        dest=destination/relative
        if dest.exists() and relative.suffix.lower() in ('.png','.jpg') and dest.read_bytes()!=p.read_bytes():
            raise ValueError(f'Refusing to overwrite a different version of {relative}. Use a new versioned filename.')
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(p,dest)
        paths.append(relative.as_posix())
    return sorted(paths)


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--push',action='store_true',help='Commit and push verified art assets to main')
    args=parser.parse_args()
    source=Path(__file__).resolve().parents[1]
    try:
        validate(source)
        if not shutil.which('git'):
            raise RuntimeError('Git is required. Install Git and sign in before publishing.')
        temp=Path(tempfile.mkdtemp(prefix='bountyhaven-art-publish-'))
        clone=temp/'BountyHaven'
        proc=subprocess.run(['git','clone','--single-branch','--branch','main',REPOSITORY,str(clone)],text=True)
        if proc.returncode:
            raise RuntimeError('Clone failed. Check network access and the existing Git login. No credentials are stored by this script.')
        if git(clone,'remote','get-url','origin')!=REPOSITORY:
            raise RuntimeError('Unexpected target repository')
        paths=copy_pack(source,clone)
        validate(clone)
        (clone/'art/reference/UPLOAD_STATUS.md').write_text('# Image files installed\n\nAll 20 original concept PNGs, 40 preview files and 7 archived runtime images passed the full checksum check during publication. See manifest.json and the Git commit history. These are references, not extracted gameplay layers.\n',encoding='utf-8')
        if 'art/reference/UPLOAD_STATUS.md' not in paths:
            paths.append('art/reference/UPLOAD_STATUS.md')
        git(clone,'add','--',*paths)
        diff=git(clone,'diff','--cached','--stat')
        print(diff or 'Art pack already present with identical content.')
        print(f'Isolated working copy: {clone}')
        if not diff:
            return
        if not args.push:
            print('Preview only: nothing committed or pushed. Run again with --push to publish.')
            return
        for key in ('user.name','user.email'):
            if not git(clone,'config','--get',key):
                raise RuntimeError(f'Set your Git {key} before publishing.')
        git(clone,'commit','-m','art: add 20 original BountyHaven visual references and usage toolkit')
        git(clone,'push','origin','HEAD:main')
        commit=git(clone,'rev-parse','HEAD')
        remote=git(clone,'ls-remote','origin','refs/heads/main').split()[0]
        if remote!=commit:
            raise RuntimeError('Remote head differs; inspect the repository before claiming success.')
        receipt={'repository':REPOSITORY,'branch':'main','commit':commit,
                 'original_concepts':20,'prototype_captures':7,'full_validation':validate(clone)}
        (source/'publish_receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(receipt,indent=2))
    except (RuntimeError,ValueError,OSError,AssertionError,subprocess.SubprocessError) as exc:
        parser.exit(1,f'PUBLISH NOT COMPLETED: {exc}\n')

if __name__=='__main__':
    main()
