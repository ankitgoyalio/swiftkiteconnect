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
        'configuration': 'debug;locked;KiteConnect;macOS15;iOS18;downloads-only-v2',
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
    print(json.dumps({'key': f'package-downloads-v2-{kind}-{digest}',
                      'identity': dimensions}, indent=2, sort_keys=True))


def healthy_downloads(cache_root, allow_empty=False):
    """Check the saved bare repositories through Git, not resolver exit status."""
    repositories = cache_root / 'repositories'
    if repositories.is_symlink():
        return False
    entries = sorted(repositories.iterdir()) if repositories.is_dir() else []
    if not entries:
        return allow_empty and (not repositories.exists() or repositories.is_dir())
    for repository in entries:
        if repository.is_symlink() or not repository.is_dir():
            print(f'Invalid download repository: {repository.name} (not a directory).', flush=True)
            return False
        command = ['git', '--git-dir', str(repository)]
        bare = subprocess.run(command + ['rev-parse', '--is-bare-repository'],
                              capture_output=True, text=True)
        # A cached repository must contain reachable objects and be complete
        # without an alternate object store outside the saved directory.
        alternates = repository / 'objects/info/alternates'
        valid = (bare.returncode == 0 and bare.stdout.strip() == 'true'
                 and not alternates.exists())
        if valid:
            valid = subprocess.run(command + ['show-ref'], capture_output=True).returncode == 0
        if valid:
            valid = subprocess.run(command + ['fsck', '--full', '--no-dangling'],
                                   capture_output=True).returncode == 0
        if not valid:
            print(f'Invalid download repository: {repository.name} (Git health check failed).',
                  flush=True)
            return False
    print(f'Validated {len(entries)} shared download repositories with Git.', flush=True)
    return True


def discard_downloads(cache_root, scratch):
    print('Discard downloads and resolver scratch; clean resolution allowed once.', flush=True)
    # Credentials, configuration and test evidence remain outside these paths.
    repositories = cache_root / 'repositories'
    if repositories.is_symlink() or repositories.is_file():
        repositories.unlink()
    elif repositories.exists():
        shutil.rmtree(repositories)
    if scratch.exists():
        shutil.rmtree(scratch)


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
    recovered = not healthy_downloads(cache_root, allow_empty=True)
    if recovered:
        discard_downloads(cache_root, scratch)
    # Discarding invalid restored state already consumes the single clean retry.
    for attempt in range(1 if recovered else 2):
        result = subprocess.run(command)
        healthy = healthy_downloads(cache_root)
        if result.returncode == 0 and healthy:
            if os.environ.get('GITHUB_OUTPUT'):
                with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
                    output.write(f'recovered={str(recovered).lower()}\nhealthy=true\n')
            return 0
        if result.returncode == 0:
            print('Resolver succeeded but shared download cache is unhealthy; refusing save.',
                  flush=True)
        if not recovered and attempt == 0:
            recovered = True
            discard_downloads(cache_root, scratch)
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write(f'recovered={str(recovered).lower()}\nhealthy=false\n')
    return result.returncode or 1


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
