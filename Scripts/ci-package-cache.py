#!/usr/bin/env python3
"""Resolve locked downloads with one clean retry; never retry builds or tests."""
import argparse
import hashlib
import json
import os
import platform
from pathlib import Path
import shutil
import subprocess
import sys


def identity(kind):
    def output(*command):
        return subprocess.check_output(command, text=True).strip()

    dimensions = {
        'kind': kind, 'os': platform.system(), 'architecture': platform.machine(),
        'compiler': output('swift', '--version'),
        'manifest': hashlib.sha256(Path('Package.swift').read_bytes()).hexdigest(),
        'resolution': hashlib.sha256(Path('Package.resolved').read_bytes()).hexdigest(),
        'configuration': 'debug;locked;KiteConnect;macOS15;iOS18;downloads-only-v1',
        'environment': {key: os.environ.get(key, '') for key in (
            'ImageOS', 'ImageVersion', 'TOOLCHAINS', 'DEVELOPER_DIR',
            'IOS_SIMULATOR_RUNTIME', 'IOS_SIMULATOR_NAME')},
    }
    if platform.system() == 'Darwin':
        dimensions['xcode'] = output('xcodebuild', '-version')
        dimensions['sdk'] = {sdk: output('xcrun', '--sdk', sdk, '--show-sdk-build-version')
                             for sdk in ('macosx', 'iphonesimulator')}
        dimensions['xcode_compiler'] = output('xcrun', 'swift', '--version')
    else:
        dimensions['distribution'] = Path('/etc/os-release').read_text()
    digest = hashlib.sha256(json.dumps(dimensions, sort_keys=True).encode()).hexdigest()
    print(json.dumps({'key': f'package-downloads-v1-{kind}-{digest}',
                      'identity': dimensions}, indent=2, sort_keys=True))


def resolve(kind, cache_root, scratch):
    if kind == 'swift':
        command = ['swift', 'package', '--cache-path', str(cache_root),
                   '--scratch-path', str(scratch), '--enable-dependency-cache',
                   'resolve', '--force-resolved-versions']
    else:
        command = ['xcodebuild', '-resolvePackageDependencies', '-scheme', 'KiteConnect',
                   '-destination', 'generic/platform=iOS Simulator',
                   '-packageCachePath', str(cache_root),
                   '-clonedSourcePackagesDirPath', str(scratch),
                   '-onlyUsePackageVersionsFromResolvedFile']
    for attempt in range(2):
        result = subprocess.run(command)
        if result.returncode == 0:
            if os.environ.get('GITHUB_OUTPUT'):
                with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
                    output.write(f'recovered={str(attempt == 1).lower()}\n')
            return 0
        if attempt == 0:
            print('Dependency resolution failed; discard downloads and resolver scratch, retry once.',
                  flush=True)
            # Only repository downloads and disposable resolution scratch are
            # cleared. Credentials, configuration and test evidence stay outside.
            shutil.rmtree(cache_root / 'repositories', ignore_errors=True)
            shutil.rmtree(scratch, ignore_errors=True)
    return result.returncode


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['resolve', 'identity'])
    parser.add_argument('--kind', choices=['swift', 'xcode'], required=True)
    parser.add_argument('--cache-root', type=Path)
    parser.add_argument('--scratch', type=Path)
    args = parser.parse_args()
    if args.operation == 'identity':
        identity(args.kind)
    else:
        if args.cache_root is None or args.scratch is None:
            parser.error('resolve requires --cache-root and --scratch')
        sys.exit(resolve(args.kind, args.cache_root, args.scratch))
