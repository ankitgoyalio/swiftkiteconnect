"""Exercise completed coverage files through the documentation audit command."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class CoverageDeliveryTests(unittest.TestCase):
    def test_separate_slice_requires_its_declaration_comment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Scripts').mkdir()
            (root / 'Documentation/DocCCoverage').mkdir(parents=True)
            (root / 'symbols').mkdir()
            script = Path(__file__).resolve().parents[2] / 'Scripts/check-documentation-coverage.py'
            shutil.copy(script, root / 'Scripts')
            (root / 'Documentation/DocCCoverage.json').write_text('{"completedSlices": {}}')
            (root / 'Documentation/DocCCoverage/orders.json').write_text(
                '{"completedSlices": {"orders": ["KiteOrder"]}}')
            symbol = {
                'identifier': {'precise': 'test-order'},
                'pathComponents': ['KiteOrder'],
                'kind': {'identifier': 'swift.struct'},
                'location': {'uri': 'file:///Order.swift'},
            }
            graph = root / 'symbols/KiteConnect.symbols.json'
            graph.write_text(json.dumps({'symbols': [symbol]}))
            command = ['python3', str(root / 'Scripts/check-documentation-coverage.py'),
                       str(root / 'symbols')]
            missing = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(missing.returncode, 0)
            self.assertIn('KiteOrder: missing meaningful documentation', missing.stderr)
            symbol['docComment'] = {'lines': [
                {'text': 'A strict REST order record; submission alone does not prove execution.'}]}
            graph.write_text(json.dumps({'symbols': [symbol]}))
            documented = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(documented.returncode, 0, documented.stderr)
            # A stale target must fail even if every remaining symbol is documented.
            (root / 'Documentation/DocCCoverage/orders.json').write_text(
                '{"completedSlices": {"orders": ["RemovedOrder"]}}')
            stale = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(stale.returncode, 0)
            self.assertIn('declared coverage target is missing: RemovedOrder', stale.stderr)


if __name__ == '__main__':
    unittest.main()
