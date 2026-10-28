#!/usr/bin/env python3
"""Build the static DocC artifact and audit the public declarations it documents."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
OUTPUT = ROOT / '.build/documentation'
CATALOG = ROOT / 'Sources/KiteConnect/KiteConnect.docc'


def run(*args):
    subprocess.run(args, check=True)


# Use SwiftPM's supported symbol extraction and the toolchain's DocC compiler.
# No documentation plugin dependency is needed by package consumers.
docc = shutil.which('docc')
if not docc and sys.platform == 'darwin':
    docc = subprocess.check_output(['xcrun', '--find', 'docc'], text=True).strip()
if not docc:
    sys.exit('DocC is required. Select full Xcode on macOS or install a Swift toolchain with DocC.')
run('python3', 'Scripts/check-documentation.py')
run('python3', 'Scripts/check-documentation-examples.py')
run('swift', 'package', 'dump-symbol-graph', '--minimum-access-level', 'public',
    '--skip-synthesized-members')
graphs = ROOT / '.build/out/symbolgraph'
# Only this module enters DocC. Dependency graphs are not package API.
module_graphs = OUTPUT / 'symbols'
module_graphs.mkdir(parents=True, exist_ok=True)
for old in module_graphs.glob('*.json'):
    old.unlink()
for graph in graphs.glob('KiteConnect*.symbols.json'):
    shutil.copy2(graph, module_graphs / graph.name)
if not list(module_graphs.glob('*.json')):
    sys.exit('SwiftPM produced no KiteConnect symbol graph.')
run('python3', 'Scripts/check-documentation-coverage.py', str(module_graphs))
archive = OUTPUT / 'KiteConnect.doccarchive'
if archive.exists():
    shutil.rmtree(archive)
run(docc, 'convert', str(CATALOG), '--additional-symbol-graph-dir', str(module_graphs),
    '--output-path', str(archive), '--fallback-bundle-identifier', 'io.ankitgoyal.KiteConnect',
    '--fallback-display-name', 'KiteConnect', '--warnings-as-errors',
    '--transform-for-static-hosting')
run('python3', 'Scripts/check-documentation-site.py', str(archive))
site = OUTPUT / 'site'
run('python3', 'Scripts/prepare-documentation-site.py', str(archive), str(site))
run('python3', 'Scripts/check-documentation-site.py', str(site))
# DocC symbol filenames contain colons. Preserve them inside a tar file because
# upload-artifact rejects colons in individual uploaded paths.
with tarfile.open(OUTPUT / 'docc-validation.tar', 'w') as bundle:
    for path in (archive, site, OUTPUT / 'public-api-inventory.json'):
        bundle.add(path, arcname=path.name)
print(f'Static documentation artifact: {archive.relative_to(ROOT)}')
print(f'Pages artifact root: {site.relative_to(ROOT)}')
