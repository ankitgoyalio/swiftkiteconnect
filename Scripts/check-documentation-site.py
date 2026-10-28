#!/usr/bin/env python3
"""Verify generated DocC routes, navigation, assets, and search data offline."""
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

archive = Path(sys.argv[1])
errors = []
pages = list((archive / 'data').rglob('*.json'))
if not pages:
    sys.exit('DocC produced no page data.')
for page in pages:
    data = json.loads(page.read_text())
    route = data.get('identifier', {}).get('url', '')
    if route.startswith('doc://'):
        route_path = urlsplit(route).path.lstrip('/').lower()
        if not (archive / route_path / 'index.html').is_file():
            errors.append(f'Missing direct static route: {route_path}')
    # Native tutorial chapters are hierarchy nodes rendered inside their overview,
    # not standalone pages. Their breadcrumb references have no static route.
    hierarchy = data.get('hierarchy', {})
    overview = hierarchy.get('reference', '')
    overview_path = urlsplit(overview).path.lstrip('/').lower()
    chapter_ids = set()
    if (overview.startswith('doc://') and overview_path.startswith('tutorials/')
            and (archive / overview_path / 'index.html').is_file()):
        chapter_ids = {module['reference'] for module in hierarchy.get('modules', [])
                       if module.get('reference', '').startswith(overview + '/')}
    for identifier, reference in data.get('references', {}).items():
        url = reference.get('url', '')
        parsed = urlsplit(url)
        if not parsed.scheme and url.startswith('/'):
            path = unquote(parsed.path).lstrip('/')
            if identifier not in chapter_ids and not ((archive / path).is_file() or (archive / path / 'index.html').is_file()):
                errors.append(f'{page.name}: missing reference target {url}')
        for variant in reference.get('variants', []):
            for asset in variant.get('paths', []):
                if not urlsplit(asset).scheme and not (archive / unquote(asset).lstrip('/')).is_file():
                    errors.append(f'{page.name}: missing asset {asset}')
for route in ('documentation/kiteconnect', 'documentation/kiteconnect/create-a-client',
              'documentation/kiteconnect/kiteconfiguration', 'documentation/kiteconnect/kiteclient'):
    if not (archive / route / 'index.html').is_file():
        errors.append(f'Missing foundation route: {route}')
if not (archive / 'index/index.json').is_file():
    errors.append('Missing navigation/search index')
for html in archive.rglob('index.html'):
    for asset in re.findall(r'(?:src|href)="(/[^"?#]+)', html.read_text()):
        if asset.startswith(('/js/', '/css/')) and not (archive / unquote(asset).lstrip('/')).is_file():
            errors.append(f'{html}: missing renderer asset {asset}')
if errors:
    sys.exit('\n'.join(sorted(set(errors))))
print(f'Verified {len(pages)} DocC page records, direct routes, references, assets, and search index.')
