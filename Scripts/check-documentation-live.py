#!/usr/bin/env python3
"""Compare a deployed HTTPS site with the exact Pages artifact, without Kite calls."""
import argparse
import json
import os
from pathlib import Path
import re
import ssl
import sys
from urllib.error import URLError
from urllib.parse import unquote, urlsplit
from urllib.request import Request, urlopen

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('site', type=Path, help='The site directory from the deployed run artifact')
parser.add_argument('--base-url', default='https://kiteconnect.ankitgoyal.io')
args = parser.parse_args()
base = args.base_url.rstrip('/')
origin = urlsplit(base)
if origin.scheme != 'https' or origin.path or origin.query or origin.fragment or origin.username:
    sys.exit('Use an HTTPS origin without a path, query, fragment, or credentials.')
routes = ('documentation/kiteconnect', 'documentation/kiteconnect/kiteclient',
          'documentation/kiteconnect/create-a-client',
          'tutorials/getting-started', 'tutorials/kiteconnect/first-request')
assets = set()
checked = 0
# Pass an explicit CA bundle when requested, including on Apple Python builds
# that otherwise load the platform certificate store instead of SSL_CERT_FILE.
context = ssl.create_default_context(cafile=os.environ.get('SSL_CERT_FILE'))


def fetch(route, local, expected_type):
    global checked
    request = Request(base + route, headers={'Cache-Control': 'no-cache'})
    with urlopen(request, timeout=30, context=context) as response:
        final = urlsplit(response.url)
        if (final.scheme, final.netloc) != (origin.scheme, origin.netloc):
            raise ValueError(f'{route}: redirected outside the HTTPS origin')
        if response.status != 200:
            raise ValueError(f'{route}: HTTP {response.status}')
        content_type = response.headers.get_content_type()
        if expected_type and content_type not in expected_type:
            raise ValueError(f'{route}: unexpected content type {content_type}')
        data = response.read()
    if data != local.read_bytes():
        raise ValueError(f'{route}: content differs from the supplied deployment artifact')
    checked += 1
    return data


try:
    fetch('/', args.site / 'index.html', {'text/html'})
    for route in routes:
        html = args.site / route / 'index.html'
        # Repeat the direct request to check reloads, then exercise the form
        # without a trailing slash as a bookmark might supply it.
        for suffix in ('/', '/', ''):
            fetch('/' + route + suffix, html, {'text/html'})
        for asset in re.findall(r'(?:src|href)="(/[^"?#]+)', html.read_text()):
            if (args.site / unquote(asset).lstrip('/')).is_file():
                assets.add(asset)
        data_route = '/data/' + route + '.json'
        page = json.loads(fetch(data_route, args.site / data_route.lstrip('/'), {'application/json'}))
        for reference in page.get('references', {}).values():
            for variant in reference.get('variants', []):
                assets.update(path for path in variant.get('paths', []) if path.startswith('/'))
            url = reference.get('url', '')
            if url.startswith(('/downloads/', '/images/', '/videos/')):
                assets.add(url)
    index = json.loads(fetch('/index/index.json', args.site / 'index/index.json', {'application/json'}))
    if not index.get('interfaceLanguages'):
        raise ValueError('Empty navigation/search index')
    # Include lazy-loaded renderer/search chunks, not only the initial HTML assets.
    for directory in ('js', 'css'):
        assets.update('/' + path.relative_to(args.site).as_posix()
                      for path in (args.site / directory).rglob('*') if path.is_file())
    for asset in sorted(assets):
        path = unquote(urlsplit(asset).path)
        local = args.site / path.lstrip('/')
        expected = None
        if path.endswith('.js'):
            expected = {'application/javascript', 'text/javascript'}
        elif path.endswith('.css'):
            expected = {'text/css'}
        fetch(asset, local, expected)
except (OSError, URLError, ValueError) as error:
    sys.exit(f'Live documentation verification failed at {getattr(error, "url", base)}: {error}')
print(f'Verified HTTPS, landing, direct routes and reloads, tutorial resources, assets, '
      f'and search data against the deployment artifact ({checked} responses).')
