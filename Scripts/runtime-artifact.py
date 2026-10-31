#!/usr/bin/env python3
"""Bind a same-run iOS runtime transfer to its image, build and candidate."""
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-18-5'
VERSION = '18.5'


def context():
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    if revision != os.environ['GITHUB_SHA']:
        raise ValueError('checkout does not match the Actions candidate')
    return {
        'repository': os.environ['GITHUB_REPOSITORY'],
        'run_id': os.environ['GITHUB_RUN_ID'],
        'run_attempt': os.environ['GITHUB_RUN_ATTEMPT'],
        'source_sha': revision,
        'architecture': platform.machine(),
        'runtime': RUNTIME,
        'version': VERSION,
    }


def installed(inventory):
    matches = [runtime for runtime in json.loads(inventory.read_text())['runtimes']
               if runtime['identifier'] == RUNTIME and runtime.get('isAvailable')
               and runtime.get('version') == VERSION and runtime.get('buildversion')]
    if len(matches) != 1:
        raise ValueError('exactly one available iOS 18.5 runtime is required')
    return matches[0]['buildversion']


def digest(image):
    checksum = hashlib.sha256()
    with image.open('rb') as source:
        for block in iter(lambda: source.read(8 * 1024 * 1024), b''):
            checksum.update(block)
    return checksum.hexdigest()


def main():
    command, directory, inventory_path = sys.argv[1:]
    folder, inventory = Path(directory), Path(inventory_path)
    manifest = folder / 'manifest.json'
    expected = context()
    if command == 'create':
        images = list(folder.glob('*.dmg'))
        if len(images) != 1:
            raise ValueError('exactly one exported runtime image is required')
        image = images[0]
        data = dict(expected, build=installed(inventory), image=image.name,
                    sha256=digest(image))
        manifest.write_text(json.dumps(data, indent=2) + '\n')
    elif command in ('verify', 'verify-installed'):
        data = json.loads(manifest.read_text())
        for key, value in expected.items():
            if data.get(key) != value:
                raise ValueError(f'runtime provenance mismatch: {key}')
        if not isinstance(data.get('build'), str) or not data['build']:
            raise ValueError('runtime build is missing')
        if command == 'verify-installed':
            if installed(inventory) != data['build']:
                raise ValueError('imported runtime build does not match export')
        else:
            name = data['image']
            if Path(name).name != name or not name.endswith('.dmg'):
                raise ValueError('invalid runtime image name')
            images = list(folder.glob('*.dmg'))
            if images != [folder / name] or digest(folder / name) != data['sha256']:
                raise ValueError('runtime image is missing, ambiguous or modified')
    else:
        raise ValueError(f'unknown operation: {command}')
    print(json.dumps(data, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        sys.exit(f'Runtime artifact verification failed: {error}')
