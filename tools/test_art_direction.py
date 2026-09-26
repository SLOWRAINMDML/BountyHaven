"""Offline regression tests for canonical guidance and safe image handoff."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile
from art_direction import check_image, inspect_sources, install_originals, load_contract, safe_path

ROOT = Path(__file__).resolve().parents[1]


class ArtDirectionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        for name in ['AGENTS.md', 'CLAUDE.md', 'ART_LIBRARY_START_HERE.md', 'docs/ART_DIRECTION.md',
                     'docs/art/CANONICAL_STYLE_GUIDE.md', 'docs/art/NEXT_AGENT_HANDOFF.md',
                     'docs/art/PROMPTS.md', 'docs/art/ASSET_HANDOFF.md', 'docs/art/source_inventory.tsv',
                     'art/canonical/style_contract.json']:
            target = self.root / name; target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        self.contract, self.inventory = load_contract(self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def change_contract(self, edit):
        data = copy.deepcopy(self.contract); edit(data)
        (self.root/'art/canonical/style_contract.json').write_text(json.dumps(data), encoding='utf-8')

    def test_all_twenty_references_and_tiers(self):
        self.assertEqual(len(self.inventory), 20)
        self.assertEqual(sum(r['tier'] == 'primary' for r in self.contract['references']), 7)

    def test_recipes_always_include_master_and_limit(self):
        for recipe in self.contract['recipes'].values():
            self.assertEqual(recipe[0], 1); self.assertLessEqual(len(recipe), 3)

    def test_missing_original_does_not_pass(self):
        verified, problems = inspect_sources(self.root, self.inventory, [1])
        self.assertEqual(verified, []); self.assertIn('Missing original', problems[0])

    def test_configuration_is_not_generation_readiness(self):
        p = subprocess.run([sys.executable, str(ROOT/'tools/art_direction.py'), '--root', str(self.root), '--check-config'], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0)
        result = json.loads(p.stdout)
        self.assertFalse(result['generation_ready']); self.assertEqual(result['source_files_present'], 0)

    def test_missing_generation_returns_two(self):
        p = subprocess.run([sys.executable, str(ROOT/'tools/art_direction.py'), '--root', str(self.root), '--scene', 'harbor'], capture_output=True, text=True)
        self.assertEqual(p.returncode, 2); self.assertFalse(json.loads(p.stdout)['generation_ready'])

    def test_prototype_cannot_become_canon(self):
        self.change_contract(lambda c: c.update(prototype_art_is_canon=True))
        with self.assertRaises(ValueError): load_contract(self.root)

    def test_unknown_recipe_reference_rejected(self):
        self.change_contract(lambda c: c['recipes'].update(harbor=[1, 99]))
        with self.assertRaises(ValueError): load_contract(self.root)

    def test_wrong_primary_tier_rejected(self):
        self.change_contract(lambda c: c['references'][12].update(tier='primary'))
        with self.assertRaises(ValueError): load_contract(self.root)

    def test_traversal_rejected(self):
        with self.assertRaises(ValueError): safe_path(self.root, 'art/reference/originals/../../project.godot')

    def test_symlink_rejected(self):
        (self.root/'art/reference/originals').mkdir(parents=True)
        (self.root/'art/reference/originals/test.png').symlink_to(self.root/'AGENTS.md')
        with self.assertRaises(ValueError): safe_path(self.root, 'art/reference/originals/test.png')

    def test_corrupt_source_rejected(self):
        row = self.inventory[1]; path = safe_path(self.root, row['original_path'])
        path.parent.mkdir(parents=True); path.write_bytes(b'not an original')
        verified, problems = inspect_sources(self.root, self.inventory, [1])
        self.assertFalse(verified); self.assertTrue(problems)

    def fixture(self):
        data = b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR' + struct.pack('>II', 1672, 941) + b'test'
        row = {'id':'fixture','original_path':'art/reference/originals/fixture.png','bytes':str(len(data)),
               'width':'1672','height':'941','sha256':hashlib.sha256(data).hexdigest()}
        return data, row

    def test_hash_gate_rejects_changed_bytes(self):
        data, row = self.fixture()
        with self.assertRaises(ValueError): check_image(data[:-1] + b'X', row)

    def test_import_only_images_not_project_or_instructions(self):
        data, row = self.fixture(); archive = self.root/'pack.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr('oldpack/'+row['original_path'], data)
            z.writestr('oldpack/project.godot', 'DO NOT COPY')
            z.writestr('oldpack/AGENTS.md', 'DO NOT COPY')
        before = (self.root/'AGENTS.md').read_bytes()
        install_originals(self.root, archive, {1:row})
        self.assertEqual(safe_path(self.root, row['original_path']).read_bytes(), data)
        self.assertEqual((self.root/'AGENTS.md').read_bytes(), before)
        self.assertFalse((self.root/'project.godot').exists())

    def test_import_validates_all_before_writing(self):
        data, row = self.fixture(); archive = self.root/'pack.zip'
        missing = dict(row, id='missing', original_path='art/reference/originals/missing.png')
        with zipfile.ZipFile(archive, 'w') as z: z.writestr('oldpack/'+row['original_path'], data)
        with self.assertRaises(ValueError): install_originals(self.root, archive, {1:row, 2:missing})
        self.assertFalse(safe_path(self.root, row['original_path']).exists())

    def test_conflicting_original_not_overwritten(self):
        data, row = self.fixture(); archive = self.root/'pack.zip'
        path = safe_path(self.root, row['original_path']); path.parent.mkdir(parents=True); path.write_bytes(b'different')
        with zipfile.ZipFile(archive, 'w') as z: z.writestr('oldpack/'+row['original_path'], data)
        with self.assertRaises(ValueError): install_originals(self.root, archive, {1:row})
        self.assertEqual(path.read_bytes(), b'different')


if __name__ == '__main__':
    unittest.main()
