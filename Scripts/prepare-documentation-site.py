#!/usr/bin/env python3
"""Prepare one root-hosted development site from a verified DocC archive."""
from pathlib import Path
import shutil
import sys

archive, site = (Path(value).resolve() for value in sys.argv[1:])
if archive == site or archive in site.parents or site in archive.parents:
    sys.exit('Archive and site must be separate, non-nested directories.')
if not (archive / 'documentation/kiteconnect/index.html').is_file():
    sys.exit('Missing KiteConnect static landing route. Build the DocC archive first.')
if site.exists():
    shutil.rmtree(site)
shutil.copytree(archive, site)
(site / 'index.html').write_text('''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="0; url=/documentation/kiteconnect/">
<link rel="canonical" href="https://kiteconnect.ankitgoyal.io/documentation/kiteconnect/">
<title>KiteConnect development documentation</title>
</head>
<body>
<p>KiteConnect development documentation for the unofficial partial 0.x package.</p>
<p><a href="/documentation/kiteconnect/">Open the documentation</a>.</p>
</body>
</html>
''')
# The Pages API owns the custom domain for Actions deployments. CNAME also
# records the intended host for anyone inspecting or serving the artifact.
(site / 'CNAME').write_text('kiteconnect.ankitgoyal.io\n')
(site / '.nojekyll').touch()
print(f'Prepared root-hosted development site: {site}')
