"""Exercise the live-site command against a controlled HTTPS static host."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import ssl
import subprocess
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / 'Tests/KiteConnectTests/Fixtures'


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


class LiveDocumentation(unittest.TestCase):
    def check_host(self, broken_search=False):
        with tempfile.TemporaryDirectory() as directory:
            site = Path(directory)
            routes = ('documentation/kiteconnect',
                      'documentation/kiteconnect/kiteclient',
                      'documentation/kiteconnect/create-a-client',
                      'tutorials/getting-started', 'tutorials/kiteconnect/first-request')
            (site / 'index.html').write_text('KiteConnect development documentation')
            for route in routes:
                html = site / route / 'index.html'
                html.parent.mkdir(parents=True, exist_ok=True)
                html.write_text('<script src="/js/main.js"></script>')
                data = site / 'data' / (route + '.json')
                data.parent.mkdir(parents=True, exist_ok=True)
                data.write_text(json.dumps({'references': {}}))
            (site / 'js').mkdir()
            (site / 'js/main.js').write_text('renderer')
            (site / 'index').mkdir()
            (site / 'index/index.json').write_text('{"interfaceLanguages":{"swift":[]}}')
            server = ThreadingHTTPServer(('localhost', 0), partial(QuietHandler, directory=directory))
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(FIXTURES / 'localhost-cert.pem', FIXTURES / 'localhost-key.pem')
            server.socket = context.wrap_socket(server.socket, server_side=True)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                if broken_search:
                    (site / 'index/index.json').unlink()
                return subprocess.run([
                    'python3', str(ROOT / 'Scripts/check-documentation-live.py'), str(site),
                    '--base-url', f'https://localhost:{server.server_port}'],
                    env={**os.environ, 'SSL_CERT_FILE': str(FIXTURES / 'localhost-cert.pem')},
                    capture_output=True, text=True)
            finally:
                server.shutdown()
                server.server_close()
                thread.join()

    def test_direct_routes_reload_assets_and_search_over_https(self):
        result = self.check_host()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Verified HTTPS', result.stdout)

    def test_missing_search_data_fails_verification(self):
        result = self.check_host(broken_search=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('index/index.json', result.stderr)
