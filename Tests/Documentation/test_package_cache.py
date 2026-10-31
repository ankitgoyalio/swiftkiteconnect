"""Exercise the resolver command boundary, including bounded clean recovery."""
import os
from pathlib import Path
import subprocess
import tempfile
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'Scripts/ci-package-cache.py'


class PackageCacheRecovery(unittest.TestCase):
    def test_unusable_downloads_retry_once_and_preserve_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cache = root / 'cache'
            (cache / 'repositories').mkdir(parents=True)
            (cache / 'repositories/broken').write_text('unusable')
            (cache / 'credentials').write_text('must survive')
            scratch = root / 'scratch'
            scratch.mkdir()
            (scratch / 'stale').write_text('stale resolution')
            # Swift is an external process boundary. Fail while restored state
            # exists, then succeed only after both resolver inputs are clean.
            compiler = root / 'swift'
            compiler.write_text('''#!/usr/bin/env python3
import os, pathlib, sys
root = pathlib.Path(os.environ['FIXTURE'])
with (root / 'attempts').open('a') as output:
    output.write('resolve\\n')
assert '--force-resolved-versions' in sys.argv
assert '--enable-dependency-cache' in sys.argv
if (root / 'cache/repositories/broken').exists():
    sys.exit(42)
assert not (root / 'scratch/stale').exists()
sys.exit(int(os.environ.get('FINAL_STATUS', '0')))
''')
            compiler.chmod(0o755)
            env = dict(os.environ, PATH=f'{root}:{os.environ["PATH"]}', FIXTURE=str(root))
            command = ['python3', str(SCRIPT), 'resolve', '--kind', 'swift',
                       '--cache-root', str(cache), '--scratch', str(scratch)]
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / 'attempts').read_text(), 'resolve\nresolve\n')
            self.assertEqual((cache / 'credentials').read_text(), 'must survive')
            (root / 'attempts').unlink()
            env['FINAL_STATUS'] = '19'
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 19, result.stderr)
            self.assertEqual((root / 'attempts').read_text(), 'resolve\nresolve\n')

    def test_identity_separates_dependencies_toolchain_sdk_and_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Package.swift').write_text('// swift-tools-version: 6.4\n')
            (root / 'Package.resolved').write_text('{"pins": []}')
            tool = root / 'swift'
            tool.write_text('#!/bin/sh\nprintf "%s\\n" "$COMPILER"\n')
            tool.chmod(0o755)
            xcrun = root / 'xcrun'
            xcrun.write_text('#!/bin/sh\nprintf "%s\\n" "$SDK"\n')
            xcrun.chmod(0o755)
            xcode = root / 'xcodebuild'
            xcode.write_text('#!/bin/sh\necho "Xcode pinned"\n')
            xcode.chmod(0o755)
            env = dict(os.environ, PATH=f'{root}:{os.environ["PATH"]}',
                       COMPILER='Swift 6.4.0', SDK='SDK1')
            command = ['python3', str(SCRIPT), 'identity', '--kind', 'swift']

            def identity():
                result = subprocess.run(command, cwd=root, env=env,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                return result.stdout

            original = identity()
            (root / 'Source.swift').write_text('edited source must rebuild')
            self.assertEqual(identity(), original)
            (root / 'Package.resolved').write_text('{"pins": ["changed"]}')
            self.assertNotEqual(identity(), original)
            (root / 'Package.resolved').write_text('{"pins": []}')
            env['COMPILER'] = 'Swift 6.4.1'
            self.assertNotEqual(identity(), original)
            env['COMPILER'] = 'Swift 6.4.0'
            env['IOS_SIMULATOR_RUNTIME'] = 'explicit-runtime'
            self.assertNotEqual(identity(), original)

            if sys.platform == 'darwin':
                env.pop('IOS_SIMULATOR_RUNTIME', None)
                # Preserve any inherited explicit runtime for the comparison.
                env['IOS_SIMULATOR_RUNTIME'] = os.environ.get('IOS_SIMULATOR_RUNTIME', '')
                env['SDK'] = 'SDK2'
                self.assertNotEqual(identity(), original)


class IOSRunnerArguments(unittest.TestCase):
    def test_optional_cache_arguments_under_system_bash(self):
        # Stub external tools: this exercises argument construction, not a device.
        import json
        import shutil
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            python = root / 'python3'
            python.symlink_to(sys.executable)
            xcrun = root / 'xcrun'
            xcrun.write_text('#!/bin/sh\necho \'{"devices":{"test.iOS-18-0":[{"name":"iPhone Test","udid":"fixture-id"}]}}\'\n')
            xcrun.chmod(0o755)
            xcode = root / 'xcodebuild'
            xcode.write_text(f'#!{sys.executable}\nimport json, os, sys\nopen(os.environ["ARGUMENTS"], "w").write(json.dumps(sys.argv[1:]))\n')
            xcode.chmod(0o755)
            for cached in (False, True):
                with self.subTest(cached=cached):
                    env = dict(os.environ, PATH=str(root), ARGUMENTS=str(root / 'args'))
                    for key in ('CI_XCODE_PACKAGE_CACHE', 'CI_XCODE_PACKAGE_CLONES',
                                'IOS_SIMULATOR_RUNTIME', 'IOS_SIMULATOR_NAME'):
                        env.pop(key, None)
                    # mkdir and mktemp remain real; simulator and build calls are fixtures.
                    for utility in ('mkdir', 'mktemp'):
                        target = root / utility
                        if not target.exists():
                            target.symlink_to(shutil.which(utility))
                    if cached:
                        env.update(CI_XCODE_PACKAGE_CACHE='/cache with spaces',
                                   CI_XCODE_PACKAGE_CLONES='/clones with spaces')
                    result = subprocess.run(['/bin/bash', str(ROOT / 'Scripts/test-ios.sh')],
                                            cwd=root, env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    arguments = json.loads((root / 'args').read_text())
                    self.assertEqual(arguments[:3], ['test', '-scheme', 'KiteConnect'])
                    if cached:
                        self.assertEqual(arguments[3:8], ['-packageCachePath', '/cache with spaces',
                            '-clonedSourcePackagesDirPath', '/clones with spaces',
                            '-onlyUsePackageVersionsFromResolvedFile'])
                    else:
                        self.assertNotIn('-packageCachePath', arguments)
                    self.assertIn('platform=iOS Simulator,id=fixture-id', arguments)
