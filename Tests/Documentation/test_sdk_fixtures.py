"""Preserve the independent fixture set and its upstream provenance offline."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / 'Tests/KiteConnectTests/Fixtures/OfficialPHP'


class OfficialSDKFixtures(unittest.TestCase):
    def test_pinned_responses_retain_exact_upstream_bytes_and_attribution(self):
        manifest = json.loads((FIXTURES / 'manifest.json').read_text())
        self.assertEqual(manifest['repository'], 'https://github.com/zerodha/phpkiteconnect')
        self.assertEqual(manifest['revision'], '34107a327473c0ce0fac2bdad121afa2ee05f76b')
        self.assertEqual(manifest['inspectedDate'], '2026-10-28')
        entries = manifest['fixtures']
        self.assertEqual(len(entries), 29)
        self.assertEqual(len({entry['file'] for entry in entries}), 29)
        self.assertEqual({entry['file'] for entry in entries},
                         {p.name for p in FIXTURES.glob('*.json')} - {'manifest.json'})
        for entry in entries:
            with self.subTest(fixture=entry['file']):
                self.assertEqual(entry['upstreamPath'], 'tests/mock_responses/' + entry['file'])
                data = (FIXTURES / entry['file']).read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(), entry['sha256'])
                self.assertIsInstance(json.loads(data), dict)
        license_text = (FIXTURES / 'LICENSE.md').read_text()
        self.assertIn('Copyright (c) [Zerodha Technology]', license_text)
        self.assertIn('Permission is hereby granted, free of charge', license_text)
        self.assertIn('THE SOFTWARE IS PROVIDED "AS IS"', license_text)


if __name__ == '__main__':
    unittest.main()
