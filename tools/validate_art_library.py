#!/usr/bin/env python3
"""Validate complete art-library metadata and image checksums.
Requires the full ArtLibrary pack. --catalog-only does not assert image presence.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import struct
from pathlib import Path


def safe_path(root: Path, relative: str) -> Path:
    if not isinstance(relative, str) or not relative.startswith('art/reference/'):
        raise ValueError(f'Invalid art path: {relative!r}')
    path = root / relative
    if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
        raise ValueError(f'Unsafe art path: {relative}')
    return path


def validate(root: Path, catalog_only: bool = False) -> dict:
    manifest = json.loads((root/'art/reference/manifest.json').read_text(encoding='utf-8'))
    assert manifest['schema'] == 'slowrain.bountyhaven.art-reference/1', 'Wrong schema'
    assets = manifest['assets']
    assert len(assets) == manifest['image_count'] == 20, 'Expected all 20 unique concepts'
    assert len({a['id'] for a in assets}) == 20, 'Duplicate identifiers'
    assert len({a['sha256'] for a in assets}) == 20, 'Duplicate originals'
    assert [a['order'] for a in assets] == list(range(1,21)), 'Incorrect order'
    assert [sum(a['set'] == s for a in assets) for s in [1,2]] == [10,10], 'Wrong batches'
    assert len(manifest['prototype_captures']) == 7, 'Expected 6 captures + 1 montage'
    checked = 0
    missing = []
    files = []
    for a in assets:
        assert a['baked_ui'] is True and a['production_ready'] is False
        assert a['layer_status'] == 'not_extracted'
        assert (a['width'], a['height']) == (1672,941)
        assert a['planned_layers'] and a['handoff_note']
        for key, hash_key in [('original','sha256'),('preview','preview_sha256'),('thumbnail','thumbnail_sha256')]:
            p = safe_path(root, a[key])
            files.append((p,a[hash_key],a if key=='original' else None))
    for a in manifest['prototype_captures']:
        files.append((safe_path(root,a['path']),a['sha256'],a))
    for p, expected, meta in files:
        if not p.exists():
            missing.append(p.relative_to(root).as_posix())
            continue
        if catalog_only:
            continue
        data=p.read_bytes()
        assert hashlib.sha256(data).hexdigest() == expected, f'Checksum mismatch: {p.name}'
        if meta:
            assert len(data)==meta['bytes'], f'Size mismatch: {p.name}'
            if p.suffix.lower()=='.png':
                assert data[:8]==b'\x89PNG\r\n\x1a\n', f'Invalid PNG: {p.name}'
                assert struct.unpack('>II',data[16:24])==(meta['width'],meta['height']), f'Wrong dimensions: {p.name}'
        checked+=1
    if missing and not catalog_only:
        raise FileNotFoundError(f'{len(missing)} image files missing; first: {missing[0]}')
    return {'mode':'catalog_only' if catalog_only else 'full_files', 'concepts':len(assets),
            'prototype_captures':7,'verified_image_files':checked,'missing_image_files':len(missing),
            'all_images_verified':not catalog_only and checked==67,'gameplay_layers_extracted':False}


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--catalog-only',action='store_true')
    args=parser.parse_args()
    try:
        result=validate(args.root.resolve(),args.catalog_only)
    except (AssertionError,KeyError,ValueError,OSError,json.JSONDecodeError) as exc:
        parser.exit(1,f'ART VALIDATION FAILED: {exc}\n')
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
    main()
