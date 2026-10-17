#!/usr/bin/env python3
"""Bounded source contract; no production writes."""
import copy
import json
from pathlib import Path
import unittest
import apply_lighting_v11 as lighting


class LightingContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = lighting.SCENE.read_text()
        cls.plan = json.loads(lighting.PLAN.read_text())

    def test_idempotent_and_preserves_independent_metadata(self):
        original = self.text.replace('metadata/campaign_level_id = "pale_ward_01"',
                                     'metadata/campaign_level_id = "pale_ward_01"\nmetadata/independent_audit_sentinel = "staff-update"', 1)
        once, report = lighting.patch_scene(original)
        twice, _ = lighting.patch_scene(once)
        self.assertEqual(once, twice)
        self.assertIn('metadata/independent_audit_sentinel = "staff-update"', once)
        self.assertTrue(report['protected_node_bytes_unchanged'])
        self.assertTrue(once.endswith('\n') and not once.endswith('\n\n'))

    def test_exact_target_and_inventory_rejected(self):
        with self.assertRaises(AssertionError):
            lighting.patch_scene(self.text.replace('metadata/campaign_level_id = "pale_ward_01"', 'metadata/campaign_level_id = "other"', 1))
        plan = copy.deepcopy(self.plan)
        plan['legacy_emitters'].append('NonexistentLight')
        # An already applied scene may have zero legacy emitters; a partial old
        # inventory is deliberately rejected independently of owned subtree.
        malformed = self.text + '\n[node name="NonexistentLight" type="Node3D" parent="."]\n'
        with self.assertRaises(AssertionError):
            lighting.patch_scene(malformed, plan)

    def test_authored_mount_budget_and_protected_landmarks(self):
        fixtures = self.plan['fixtures']
        self.assertEqual(len(fixtures), 56)
        self.assertEqual(len({f['id'] for f in fixtures}), 56)
        damaged = [f for f in fixtures if f['damaged']]
        self.assertEqual(len(damaged), 2)
        self.assertTrue(all(f['kind'] == 'warning' and f['energy'] == .26 for f in damaged))
        self.assertTrue(all(not f['damaged'] for f in fixtures if 'cache' in f['id'] or 'exit' in f['id'] or 'stair' in f['id']))

if __name__ == '__main__':
    unittest.main()
