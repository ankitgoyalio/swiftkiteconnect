"""Exercise the artifact preparation command at the documentation delivery seam."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PublicationArtifact(unittest.TestCase):
    def test_root_opens_current_documentation_and_preserves_direct_routes(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / 'archive'
            site = Path(directory) / 'site'
            route = archive / 'documentation/kiteconnect/index.html'
            route.parent.mkdir(parents=True)
            route.write_text('DocC renderer')
            (archive / 'index.html').write_text('Original root renderer')
            asset = archive / 'js/renderer.js'
            asset.parent.mkdir()
            asset.write_text('renderer')
            site.mkdir()
            (site / 'stale.html').write_text('previous version')
            result = subprocess.run([
                'python3', str(ROOT / 'Scripts/prepare-documentation-site.py'),
                str(archive), str(site)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            landing = (site / 'index.html').read_text()
            self.assertIn('url=/documentation/kiteconnect/', landing)
            self.assertIn('https://kiteconnect.ankitgoyal.io/documentation/kiteconnect/', landing)
            self.assertIn('development', landing)
            self.assertIn('partial 0.x', landing)
            self.assertEqual((site / 'documentation/kiteconnect/index.html').read_text(), 'DocC renderer')
            self.assertEqual((site / 'js/renderer.js').read_text(), 'renderer')
            self.assertEqual((site / 'CNAME').read_text(), 'kiteconnect.ankitgoyal.io\n')
            self.assertTrue((site / '.nojekyll').is_file())
            self.assertFalse((site / 'stale.html').exists())
            self.assertEqual((archive / 'index.html').read_text(), 'Original root renderer')
