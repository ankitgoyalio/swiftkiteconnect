#!/usr/bin/env python3
"""Minimum-macOS compilation pilot. Cache outputs, never qualification evidence."""
import argparse
import hashlib
import re
from collections import Counter
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


# Swift 6.4 defaults to Swift Build. Keep this allowlist shared by restore/save;
# never include the whole scratch directory (which also contains downloads).
CACHE_PATHS = ('.build/out/Products/Debug', '.build/out/Intermediates.noindex',
               '.build/out/ModuleCache.noindex')
BUILD_DATABASE = Path('.build/out/Intermediates.noindex/XCBuildData/build.db')


def validate():
    def nonempty_file(path):
        return path.is_file() and path.stat().st_size > 0

    missing = [name for name in CACHE_PATHS
               if not Path(name).is_dir() or not any(
                   nonempty_file(path) for path in Path(name).rglob('*'))]
    if not nonempty_file(BUILD_DATABASE):
        missing.append(str(BUILD_DATABASE))
    bundles = list(Path(CACHE_PATHS[0]).glob('*.xctest'))
    if not any(any(nonempty_file(path) for path in bundle.rglob('*')) for bundle in bundles):
        missing.append(f'{CACHE_PATHS[0]}/*.xctest (nonempty test bundle)')
    if missing:
        raise ValueError('Compilation cache outputs missing or empty: ' + ', '.join(missing))
    return {'state': 'validated-for-save', 'paths': list(CACHE_PATHS),
            'database': str(BUILD_DATABASE),
            'bytes': sum(path.stat().st_size for name in CACHE_PATHS
                         for path in Path(name).rglob('*') if path.is_file())}


def invalidate():
    if not BUILD_DATABASE.is_file() or BUILD_DATABASE.stat().st_size == 0:
        raise ValueError(f'Compilation cache outputs missing or empty: {BUILD_DATABASE}')
    BUILD_DATABASE.write_text('deliberately unusable SQLite state')
    print(f'Deliberately corrupted {BUILD_DATABASE}')


def probe(token):
    if not token or not all(character.isalnum() or character in '-_.' for character in token):
        raise ValueError('Probe token must contain only letters, numbers, dot, dash or underscore')
    files = {
        'Sources/KiteConnect/CICompilationProbe.swift':
            f'func ciCompilationProbe() -> String {{ "{token}" }}\n',
        'Tests/KiteConnectTests/CICompilationProbeTests.swift':
            'import Testing\n@testable import KiteConnect\n'
            f'@Test func compilationCacheSourceEdit() {{ #expect(ciCompilationProbe() == "{token}") }}\n',
    }
    for name, content in files.items():
        path = Path(name)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    print(json.dumps({'probe': token, 'files': list(files)}))


def identity():
    def output(*arguments):
        return subprocess.check_output(arguments, text=True).strip()

    downloads = json.loads(output(sys.executable, str(Path(__file__).with_name(
        'ci-package-cache.py')), 'identity', '--kind', 'swift'))['identity']
    dimensions = {
        'downloads': downloads,
        'os_build': output('sw_vers'),
        'target': output('swift', '-print-target-info'),
        # setup-swift puts a randomly located swiftly launcher on PATH. Key the
        # selected toolchain executable, which is also verified by preflight.
        'compiler_path': str(Path(output('xcrun', '--find', 'swift')).resolve()),
        'sdk_path': output('xcrun', '--sdk', 'macosx', '--show-sdk-path'),
        'sdk_version': output('xcrun', '--sdk', 'macosx', '--show-sdk-version'),
        'workspace': str(Path.cwd().resolve()),
        'configuration': os.environ.get('CI_BUILD_CONFIGURATION', 'debug'),
        'command': ['swift', 'build', '--build-tests', '--verbose'],
        'build_environment': {key: os.environ.get(key, '') for key in (
            'SDKROOT', 'MACOSX_DEPLOYMENT_TARGET', 'CC', 'CXX', 'CFLAGS',
            'CXXFLAGS', 'LDFLAGS', 'SWIFT_EXEC', 'SWIFTFLAGS')},
        'pilot': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    }
    digest = hashlib.sha256(json.dumps(dimensions, sort_keys=True).encode()).hexdigest()
    print(json.dumps({'key': f'minimum-macos-compilation-v1-{digest}',
                      'identity': dimensions}, indent=2, sort_keys=True))


def command(arguments, log):
    log.parent.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    with log.open('w') as output:
        process = subprocess.Popen(arguments, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            print(line, end='', flush=True)
            output.write(line)
        status = process.wait()
    return {'command': arguments, 'status': status, 'seconds': time.monotonic() - start}


def build(restored):
    results = []
    directory = Path('.test-results/compilation-cache')
    for attempt in range(2 if restored else 1):
        result = command(['swift', 'build', '--build-tests', '--verbose'],
                         directory / f'build-{attempt}.txt')
        results.append(result)
        if result['status'] == 0:
            break
        if restored and attempt == 0:
            print('Restored build failed; remove compilation scratch and retry once.', flush=True)
            shutil.rmtree('.build', ignore_errors=True)
    (directory / 'build.json').write_text(json.dumps(results, indent=2))
    return results[-1]['status']


def outcomes(path):
    text = path.read_text()
    results = Counter(re.findall(r'Test (?!run with )(.+?) (passed|skipped|failed)(?: after|[ .:]|$)', text))
    if not re.search(r'Test run with [1-9][0-9]* tests?\b.*passed', text):
        raise ValueError(f'Missing successful complete suite summary: {path}')
    if not results or any(status == 'failed' for name, status in results):
        raise ValueError(f'Missing or failed named tests: {path}')
    return results


def compare_results(cached, clean, require_probe=True):
    first, second = outcomes(cached), outcomes(clean)
    if require_probe and ('compilationCacheSourceEdit()', 'passed') not in first:
        raise ValueError('Observable source probe did not execute successfully')
    if first != second:
        raise ValueError('Cached and clean candidate test outcomes differ')
    return {'matching': True, 'observations': sum(first.values()),
            'tests': [{'name': name, 'outcome': status, 'count': count}
                      for (name, status), count in sorted(first.items())]}


def compare():
    directory = Path('.test-results/compilation-cache')
    # Evidence is retained outside scratch, never restored from the cache.
    sources = [Path('Sources/KiteConnect/CICompilationProbe.swift'),
               Path('Tests/KiteConnectTests/CICompilationProbeTests.swift')]
    hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    shutil.rmtree('.build')
    commands = [
        (['swift', 'build', '--build-tests', '--verbose'], 'clean-build.txt'),
        ([sys.executable, 'Scripts/test-macos.py'], 'clean-suite.txt'),
        (['env', 'LIBDISPATCH_COOPERATIVE_POOL_STRICT=1', 'swift', 'test',
          '--skip-build', '--filter', 'real (local )?HTTP', '--maximum-repetitions', '10'],
         'clean-constrained.txt'),
    ]
    timings = []
    for arguments, log in commands:
        result = command(arguments, directory / log)
        timings.append(result)
        if result['status']:
            return result['status']
    if hashes != {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}:
        raise ValueError('Probe source changed during clean comparison')
    report = {
        'candidate': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        'probe_hashes': hashes,
        'suite': compare_results(Path('.test-results/minimum-macos-tests.txt'),
                                 directory / 'clean-suite.txt'),
        'constrained': compare_results(Path('.test-results/minimum-macos-constrained.txt'),
                                       directory / 'clean-constrained.txt', require_probe=False),
        'clean_timings': timings,
    }
    (directory / 'comparison.json').write_text(json.dumps(report, indent=2))
    print('Edited candidate outcomes match a fresh clean build; see comparison.json.')
    return 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=[
        'probe', 'build', 'identity', 'compare-results', 'compare', 'paths', 'validate', 'invalidate'])
    parser.add_argument('--token')
    parser.add_argument('--restored', action='store_true')
    parser.add_argument('--cached', type=Path)
    parser.add_argument('--clean', type=Path)
    args = parser.parse_args()
    if args.operation == 'paths':
        print('\n'.join(CACHE_PATHS))
    elif args.operation == 'validate':
        print(json.dumps(validate(), indent=2))
    elif args.operation == 'invalidate':
        invalidate()
    elif args.operation == 'probe':
        probe(args.token)
    elif args.operation == 'identity':
        identity()
    elif args.operation == 'compare-results':
        print(json.dumps(compare_results(args.cached, args.clean)))
    elif args.operation == 'compare':
        sys.exit(compare())
    else:
        sys.exit(build(args.restored))
