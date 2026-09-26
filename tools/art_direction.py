#!/usr/bin/env python3
"""BountyHaven art direction preflight. Python 3.10+, standard library only.
Config checks do not certify source availability. Import ONLY verified originals
from a supplied archive; never overwrite game files or current art instructions.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import tempfile
import zipfile

CONTRACT = 'art/canonical/style_contract.json'
MAX_IMAGE_BYTES = 12 * 1024 * 1024


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def safe_path(root: Path, relative: str) -> Path:
    require(isinstance(relative, str) and relative.startswith('art/reference/originals/'), 'Invalid source path')
    parts = PurePosixPath(relative).parts
    require('..' not in parts and '\\' not in relative, 'Unsafe source path')
    target = root.joinpath(*parts)
    require(not any(p.is_symlink() for p in [target, *target.parents]), 'Symlink source paths are not allowed')
    require(target.resolve().is_relative_to(root.resolve()), 'Source escapes project root')
    return target


def load_contract(root: Path) -> tuple[dict, dict[int, dict]]:
    contract = json.loads((root / CONTRACT).read_text(encoding='utf-8'))
    require(contract['schema'] == 'slowrain.bountyhaven.art-direction/2', 'Unknown art schema')
    require(contract['master_reference'] == 1, 'Rust Harbor 01 must remain the master')
    require(contract['prototype_art_is_canon'] is False, 'Prototype art cannot become canon')
    require(contract['source_policy'] == 'verified_original_png_required', 'Original source gate is required')
    require(contract['missing_source_behavior'] == 'stop_no_style_substitution', 'Silent art fallback is forbidden')
    require(contract['source_inventory'] == 'docs/art/source_inventory.tsv', 'Unexpected inventory path')
    with (root / contract['source_inventory']).open(encoding='utf-8', newline='') as f:
        rows = list(csv.DictReader(f, delimiter='\t'))
    require(len(rows) == 20, 'Expected 20 source records')
    inventory = {int(row['order']): row for row in rows}
    require(set(inventory) == set(range(1, 21)), 'Duplicate or missing source order')
    refs = contract['references']
    require(len(refs) == 20 and {r['order'] for r in refs} == set(inventory), 'Incomplete reference priorities')
    expected_primary = {1, 4, 7, 11, 17, 18, 20}
    expected_secondary = {2, 5, 6, 9}
    for ref in refs:
        n = ref['order']; row = inventory[n]
        tier = 'primary' if n in expected_primary else 'secondary' if n in expected_secondary else 'support'
        require(ref['tier'] == tier, f'Unexpected tier for reference {n}')
        require(ref['id'] == row['id'], f'Reference identity mismatch: {n}')
        require(re.fullmatch(r'[0-9a-f]{64}', row['sha256']) is not None, 'Invalid source checksum')
        require((int(row['width']), int(row['height'])) == (1672, 941), 'Unexpected original dimensions')
        require(0 < int(row['bytes']) <= MAX_IMAGE_BYTES, 'Invalid image length')
        require(PurePosixPath(row['original_path']).name == row['id'] + '.png', 'Filename/identity mismatch')
        safe_path(root, row['original_path'])
    require(len({r['original_path'] for r in rows}) == 20, 'Duplicate source filenames')
    for name, orders in contract['recipes'].items():
        require(re.fullmatch(r'[a-z_]+', name) is not None, 'Unsafe recipe name')
        require(1 <= len(orders) <= 3 and orders[0] == 1, 'Use master plus at most two contextual references')
        require(len(orders) == len(set(orders)) and set(orders) <= set(inventory), 'Unknown or duplicate recipe reference')
    for rel in ['AGENTS.md', 'CLAUDE.md', 'ART_LIBRARY_START_HERE.md', 'docs/ART_DIRECTION.md',
                'docs/art/CANONICAL_STYLE_GUIDE.md', 'docs/art/NEXT_AGENT_HANDOFF.md',
                'docs/art/PROMPTS.md', 'docs/art/ASSET_HANDOFF.md']:
        require((root / rel).is_file(), f'Missing handoff document: {rel}')
    return contract, inventory


def check_image(data: bytes, row: dict) -> None:
    require(len(data) == int(row['bytes']), f"Length mismatch: {row['id']}")
    require(hashlib.sha256(data).hexdigest() == row['sha256'], f"SHA-256 mismatch: {row['id']}")
    require(len(data) >= 24 and data[:8] == b'\x89PNG\r\n\x1a\n' and data[12:16] == b'IHDR', 'Invalid PNG header')
    require(struct.unpack('>II', data[16:24]) == (int(row['width']), int(row['height'])), 'PNG dimension mismatch')


def inspect_sources(root: Path, inventory: dict[int, dict], orders: list[int]) -> tuple[list[dict], list[str]]:
    verified, problems = [], []
    for n in orders:
        row = inventory[n]; target = safe_path(root, row['original_path'])
        if not target.is_file():
            problems.append(f"Missing original: {row['original_path']}")
            continue
        try:
            require(target.stat().st_size <= MAX_IMAGE_BYTES, 'Oversized source')
            check_image(target.read_bytes(), row)
        except (ValueError, OSError) as exc:
            problems.append(str(exc))
            continue
        verified.append({'order': n, 'id': row['id'], 'path': row['original_path'], 'sha256': row['sha256']})
    return verified, problems


def install_originals(root: Path, archive: Path, inventory: dict[int, dict]) -> None:
    staged: list[tuple[Path, bytes]] = []
    with zipfile.ZipFile(archive) as z:
        for row in inventory.values():
            relative = row['original_path']
            matches = [i for i in z.infolist() if i.filename == relative or i.filename.endswith('/' + relative)]
            require(len(matches) == 1, f'Missing or ambiguous archive original: {relative}')
            info = matches[0]
            require('..' not in PurePosixPath(info.filename).parts and '\\' not in info.filename, 'Unsafe archive member')
            require(((info.external_attr >> 16) & 0o170000) != 0o120000, 'Archive symlink rejected')
            require(info.file_size == int(row['bytes']) <= MAX_IMAGE_BYTES, 'Unexpected archive image length')
            data = z.read(info); check_image(data, row)
            target = safe_path(root, relative)
            if target.exists():
                require(target.is_file() and target.stat().st_size == len(data), 'Refusing to replace an existing different original')
                require(target.read_bytes() == data, 'Refusing to overwrite a different original')
            staged.append((target, data))
    # Validate the entire input before creating any output. Atomic replacement per file.
    for target, data in staged:
        if target.exists():
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as f:
                temporary = Path(f.name); f.write(data)
            temporary.replace(target)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--check-config', action='store_true', help='Validate rules only, not generation readiness')
    parser.add_argument('--archive', type=Path, help='Restore exact original PNGs only from an ArtLibrary ZIP')
    parser.add_argument('--scene', default='harbor', help='Recipe key from style_contract.json')
    args = parser.parse_args(); root = args.root.resolve()
    try:
        contract, inventory = load_contract(root)
        require(args.scene in contract['recipes'], 'Unknown scene; choose a recipe from style_contract.json')
        if args.archive:
            install_originals(root, args.archive, inventory)
        all_verified, all_problems = inspect_sources(root, inventory, list(inventory))
        verified, problems = inspect_sources(root, inventory, contract['recipes'][args.scene])
        result = {'revision': contract['revision'], 'configuration_valid': True,
                  'mode': 'config_only' if args.check_config else 'generation_preflight',
                  'source_files_present': len(all_verified), 'total_originals': 20,
                  'all_originals_verified': not all_problems,
                  'scene': args.scene, 'generation_ready': not args.check_config and not problems,
                  'attach_these_actual_images': verified, 'source_problems': problems,
                  'instruction': 'Open and attach these actual images, then use docs/art/PROMPTS.md. Never use prototype art as a substitute.'}
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if args.check_config or not problems else 2
    except (ValueError, OSError, KeyError, TypeError, zipfile.BadZipFile, zipfile.LargeZipFile) as exc:
        print(json.dumps({'configuration_valid': False, 'generation_ready': False, 'error': str(exc)}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
