"""Validate native tutorial navigation through the static-site check command."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class TutorialNavigation(unittest.TestCase):
    def check_archive(self, *, missing_page=False, missing_overview=False):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory)
            routes = [
                'documentation/kiteconnect',
                'documentation/kiteconnect/create-a-client',
                'documentation/kiteconnect/kiteconfiguration',
                'documentation/kiteconnect/kiteclient',
                'tutorials/kiteconnect/first-request',
            ]
            if not missing_overview:
                routes.append('tutorials/getting-started')
            for route in routes:
                path = archive / route / 'index.html'
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('<html></html>')
            (archive / 'index').mkdir()
            (archive / 'index/index.json').write_text('{}')
            (archive / 'data').mkdir()
            overview = 'doc://example/tutorials/Getting-started'
            chapter = overview + '/Authenticate-and-read-a-profile'
            references = {
                chapter: {'url': '/tutorials/getting-started/authenticate-and-read-a-profile'},
                overview: {'url': '/tutorials/getting-started'},
            }
            if missing_page:
                references['doc://example/documentation/Missing'] = {
                    'url': '/documentation/missing'}
            page = {
                'identifier': {'url': 'doc://example/tutorials/KiteConnect/First-request'},
                'hierarchy': {'reference': overview, 'modules': [{'reference': chapter}]},
                'references': references,
            }
            (archive / 'data/first-request.json').write_text(json.dumps(page))
            return subprocess.run(
                ['python3', str(ROOT / 'Scripts/check-documentation-site.py'), str(archive)],
                capture_output=True, text=True)

    def test_native_chapter_breadcrumb_resolves_through_overview(self):
        result = self.check_archive()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_article_is_still_rejected(self):
        result = self.check_archive(missing_page=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('/documentation/missing', result.stderr)

    def test_chapter_requires_its_overview_route(self):
        result = self.check_archive(missing_overview=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('/tutorials/getting-started', result.stderr)
