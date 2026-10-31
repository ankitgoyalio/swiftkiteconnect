"""Compilation experiment behavior at its command boundary."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'Scripts/ci-compilation-cache.py'


class CompilationCache(unittest.TestCase):
    def run_cli(self, *args, cwd, env=None):
        return subprocess.run(['python3', str(SCRIPT), *args], cwd=cwd,
                              env=env, capture_output=True, text=True)

    def test_paths_select_observed_swift_build_outputs_without_downloads_or_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            # Swift 6.4.0 hosted run 41199125525 uses Swift Build, not native debug.
            for name in (
                    '.build/out/Products/Debug/KiteConnectPackageTests.xctest/Contents/MacOS/tests',
                    '.build/out/Intermediates.noindex/XCBuildData/build.db',
                    '.build/out/ModuleCache.noindex/Swift.swiftmodule',
                    '.build/checkouts/dependency/source.swift',
                    '.build/repositories/download', '.test-results/suite.txt',
                    '.swiftpm/security/credentials'):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('fixture')
            result = self.run_cli('paths', cwd=root)
            self.assertEqual(result.returncode, 0, result.stderr)
            paths = result.stdout.splitlines()
            self.assertEqual(paths, ['.build/out/Products/Debug',
                                     '.build/out/Intermediates.noindex',
                                     '.build/out/ModuleCache.noindex'])
            selected = {str(p.relative_to(root)) for name in paths
                        for p in (root / name).rglob('*') if p.is_file()}
            self.assertEqual(selected, {
                '.build/out/Products/Debug/KiteConnectPackageTests.xctest/Contents/MacOS/tests',
                '.build/out/Intermediates.noindex/XCBuildData/build.db',
                '.build/out/ModuleCache.noindex/Swift.swiftmodule'})

    def test_validation_fails_explicitly_until_compilation_outputs_are_present(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            # An absent scratch tree, old native layout, empty directories, and
            # a partial Swift Build tree must never be reported ready for save.
            for name in ('.build/arm64-apple-macosx/debug/test',
                         '.build/build.db', '.build/debug.yaml'):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('old layout')
            database = root / '.build/out/Intermediates.noindex/XCBuildData/build.db'
            module = root / '.build/out/ModuleCache.noindex/Swift.swiftmodule'
            executable = root / '.build/out/Products/Debug/LayoutTests.xctest/Contents/MacOS/LayoutTests'
            for path in (database, module, executable):
                result = self.run_cli('validate', cwd=root)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Compilation cache outputs missing or empty', result.stderr)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()
                result = self.run_cli('validate', cwd=root)
                self.assertNotEqual(result.returncode, 0)
                path.write_text('actual output')
            result = self.run_cli('validate', cwd=root)
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(result.stdout)
            self.assertEqual(report['state'], 'validated-for-save')
            self.assertEqual(report['database'], '.build/out/Intermediates.noindex/XCBuildData/build.db')
            self.assertEqual(set(report['paths']), {'.build/out/Products/Debug',
                                                  '.build/out/Intermediates.noindex',
                                                  '.build/out/ModuleCache.noindex'})
            self.assertGreater(report['bytes'], 0)

    def test_invalid_experiment_corrupts_actual_swift_build_database_and_requires_it(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = self.run_cli('invalidate', cwd=root)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Compilation cache outputs missing or empty', result.stderr)
            database = root / '.build/out/Intermediates.noindex/XCBuildData/build.db'
            database.parent.mkdir(parents=True)
            database.write_bytes(b'SQLite format 3\0fixture')
            result = self.run_cli('invalidate', cwd=root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(database.read_text(), 'deliberately unusable SQLite state')
            self.assertFalse((root / '.build/build.db').exists())

    def test_minimum_build_step_handles_cold_warm_and_cache_off_under_system_bash(self):
        result = subprocess.run(['ruby', '-rjson', '-ryaml', '-e',
                                 'puts JSON.generate(YAML.load_file(ARGV[0]))',
                                 str(ROOT / '.github/workflows/protocol-tests.yml')],
                                check=True, capture_output=True, text=True)
        steps = json.loads(result.stdout)['jobs']['minimum-macos']['steps']
        build = next(step for step in steps if step.get('name') == 'Build macOS 15 tests')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.test-results').mkdir()
            for name in ('python3', 'swift'):
                tool = root / name
                tool.write_text(f'#!{sys.executable}\nimport json, sys\nprint(json.dumps(sys.argv[1:]))\n')
                tool.chmod(0o755)
            for mode, matched, expected in (
                    ('cold', '', ['Scripts/ci-compilation-cache.py', 'build']),
                    ('warm', '', ['Scripts/ci-compilation-cache.py', 'build']),
                    ('warm', 'compatible-key', ['Scripts/ci-compilation-cache.py', 'build', '--restored']),
                    ('off', '', ['build', '--build-tests']),
                    ('', '', ['build', '--build-tests'])):
                with self.subTest(mode=mode, matched=matched):
                    env = dict(os.environ, PATH=f'{root}:{os.environ["PATH"]}',
                               COMPILATION_MODE=mode, MATCHED_COMPILATION=matched)
                    result = subprocess.run(['/bin/bash', '-c', build['run']], cwd=root,
                                            env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(json.loads(result.stdout), expected)

    def test_probe_changes_compiled_source_and_test_expectation_together(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = self.run_cli('probe', '--token', 'before', cwd=root)
            self.assertEqual(first.returncode, 0, first.stderr)
            source = root / 'Sources/KiteConnect/CICompilationProbe.swift'
            test = root / 'Tests/KiteConnectTests/CICompilationProbeTests.swift'
            previous = source.read_text()
            second = self.run_cli('probe', '--token', 'after', cwd=root)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertNotEqual(previous, source.read_text())
            self.assertIn('"after"', source.read_text())
            self.assertIn('"after"', test.read_text())
            self.assertIn('ciCompilationProbe()', test.read_text())

    def test_restored_build_has_one_clean_retry_and_preserves_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.build').mkdir()
            (root / '.build/stale').write_text('bad cache')
            (root / 'swift').write_text('''#!/usr/bin/env python3
import pathlib, os, sys
root = pathlib.Path('.')
with open('attempts', 'a') as log: log.write('build\\n')
assert sys.argv[1:] == ['build', '--build-tests', '--verbose']
if (root / '.build/stale').exists(): sys.exit(42)
sys.exit(int(os.environ.get('BUILD_STATUS', '0')))
''')
            (root / 'swift').chmod(0o755)
            env = dict(os.environ, PATH=f'{root}:{os.environ["PATH"]}')
            result = self.run_cli('build', '--restored', cwd=root, env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / 'attempts').read_text(), 'build\nbuild\n')
            (root / 'attempts').unlink()
            env['BUILD_STATUS'] = '19'
            result = self.run_cli('build', '--restored', cwd=root, env=env)
            self.assertEqual(result.returncode, 19, result.stderr)
            self.assertEqual((root / 'attempts').read_text(), 'build\nbuild\n')
            (root / 'attempts').unlink()
            result = self.run_cli('build', cwd=root, env=env)
            self.assertEqual(result.returncode, 19, result.stderr)
            self.assertEqual((root / 'attempts').read_text(), 'build\n')

    def test_identity_rejects_environment_and_dependency_changes_but_allows_edits(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Package.swift').write_text('// swift-tools-version: 6.4\n')
            (root / 'Package.resolved').write_text('{"pins": []}')
            for name, value in [('swift', 'COMPILER'), ('xcrun', 'SDK'),
                                ('xcodebuild', 'XCODE'), ('sw_vers', 'OS_VERSION')]:
                tool = root / name
                tool.write_text(f'#!/bin/sh\nprintenv {value}\n')
                tool.chmod(0o755)
            env = dict(os.environ, PATH=f'{root}:{os.environ["PATH"]}',
                       COMPILER='Swift 6.4.0 arm64', SDK='SDK1', XCODE='Xcode16.4',
                       OS_VERSION='15.5 build A', CI_BUILD_CONFIGURATION='debug')

            def key():
                result = self.run_cli('identity', cwd=root, env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                return json.loads(result.stdout)['key']

            original = key()
            (root / 'Source.swift').write_text('a source edit')
            self.assertEqual(key(), original)
            for name in ('COMPILER', 'SDK', 'XCODE', 'OS_VERSION', 'CI_BUILD_CONFIGURATION'):
                previous = env[name]
                env[name] = 'changed'
                self.assertNotEqual(key(), original, name)
                env[name] = previous
            for name in ('Package.swift', 'Package.resolved'):
                previous = (root / name).read_text()
                (root / name).write_text('changed')
                self.assertNotEqual(key(), original, name)
                (root / name).write_text(previous)

    def test_identity_uses_selected_compiler_instead_of_temporary_swiftly_launcher(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Package.swift').write_text('// swift-tools-version: 6.4\n')
            (root / 'Package.resolved').write_text('{"pins": []}')
            compiler = root / 'toolchain/usr/bin/swift'
            compiler.parent.mkdir(parents=True)
            compiler.write_text('#!/bin/sh\necho "Swift 6.4 stable target"\n')
            compiler.chmod(0o755)
            for name in ('sw_vers', 'xcodebuild', 'xcrun'):
                tool = root / name
                tool.write_text('#!/bin/sh\nif [ "$1" = --find ]; then\n'
                                '  echo "$SELECTED_COMPILER"\nelse\n  echo stable\nfi\n')
                tool.chmod(0o755)
            identities = []
            for attempt in ('random-install-one', 'random-install-two'):
                launcher = root / attempt / 'swift'
                launcher.parent.mkdir()
                launcher.write_text(f'#!/bin/sh\nexec "{compiler}" "$@"\n')
                launcher.chmod(0o755)
                env = dict(os.environ, PATH=f'{launcher.parent}:{root}:{os.environ["PATH"]}',
                           SELECTED_COMPILER=str(compiler))
                result = self.run_cli('identity', cwd=root, env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                identities.append(json.loads(result.stdout))
            self.assertEqual(identities[0]['key'], identities[1]['key'])
            self.assertEqual(identities[0]['identity']['compiler_path'], str(compiler.resolve()))

    def test_workflow_keeps_pilot_off_and_preserves_candidate_checks(self):
        result = subprocess.run(['ruby', '-rjson', '-ryaml', '-e',
                                 'puts JSON.generate(YAML.load_file(ARGV[0]))',
                                 str(ROOT / '.github/workflows/protocol-tests.yml')],
                                check=True, capture_output=True, text=True)
        workflow = json.loads(result.stdout)
        self.assertEqual(workflow.get('on', workflow.get('true'))['workflow_dispatch']['inputs']['compilation_cache']['default'], 'off')
        jobs = workflow['jobs']
        for name, job in jobs.items():
            pilot = [step for step in job.get('steps', [])
                     if step.get('uses') == './.github/actions/compilation-cache']
            self.assertEqual(len(pilot), int(name == 'minimum-macos'))
        steps = jobs['minimum-macos']['steps']
        build = next(step for step in steps if step.get('name') == 'Build macOS 15 tests')
        self.assertNotIn('if', build)
        self.assertIn('swift build --build-tests', build['run'])
        for title in ('macOS 15 public protocol and real transport tests',
                      'macOS 15 constrained-executor HTTP regression'):
            step = next(step for step in steps if step.get('name') == title)
            self.assertNotIn('if', step)
            self.assertFalse(step.get('continue-on-error', False))
        action = subprocess.run(['ruby', '-rjson', '-ryaml', '-e',
                                 'puts JSON.generate(YAML.load_file(ARGV[0]))',
                                 str(ROOT / '.github/actions/compilation-cache/action.yml')],
                                check=True, capture_output=True, text=True)
        restore = next(step for step in json.loads(action.stdout)['runs']['steps']
                       if step.get('uses') == 'actions/cache/restore@v5')
        self.assertNotIn('.test-results', restore['with']['path'])
        self.assertEqual(restore['with']['path'], '${{ steps.identity.outputs.paths }}')
        save = next(step for step in steps if step.get('uses') == 'actions/cache/save@v5')
        self.assertEqual(save['with']['path'], '${{ steps.compilation.outputs.paths }}')
        validation = next(step for step in steps
                          if step.get('name') == 'Record compilation storage before transfer')
        self.assertLess(steps.index(validation), steps.index(save))
        self.assertIn('set -euo pipefail', validation['run'])
        self.assertIn('ci-compilation-cache.py validate', validation['run'])
        self.assertFalse(validation.get('continue-on-error', False))
        self.assertIn('steps.identity.outputs.key', restore['with']['restore-keys'])

    def test_comparison_requires_matching_executed_tests_and_observed_probe(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cached = root / 'cached.txt'
            clean = root / 'clean.txt'
            text = ('✔ Test compilationCacheSourceEdit() passed after 0.01 seconds.\n'
                    '✔ Test realHTTP() passed after 0.02 seconds.\n'
                    '✔ Test run with 2 tests passed after 0.03 seconds.\n')
            cached.write_text(text)
            clean.write_text(text.replace('0.01', '0.99'))
            args = ('compare-results', '--cached', str(cached), '--clean', str(clean))
            result = self.run_cli(*args, cwd=root)
            self.assertEqual(result.returncode, 0, result.stderr)
            clean.write_text(text.replace('realHTTP()', 'differentTest()'))
            self.assertNotEqual(self.run_cli(*args, cwd=root).returncode, 0)
            clean.write_text('')
            self.assertNotEqual(self.run_cli(*args, cwd=root).returncode, 0)
            cached.write_text(text.replace('compilationCacheSourceEdit()', 'otherTest()'))
            clean.write_text(cached.read_text())
            self.assertNotEqual(self.run_cli(*args, cwd=root).returncode, 0)

    def test_comparison_accepts_a_successful_single_test_summary(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('cached.txt', 'clean.txt'):
                (root / name).write_text(
                    '✔ Test compilationCacheSourceEdit() passed after 0.01 seconds.\n'
                    '✔ Test run with 1 test in 0 suites passed after 0.01 seconds.\n')
            result = self.run_cli('compare-results', '--cached', str(root / 'cached.txt'),
                                  '--clean', str(root / 'clean.txt'), cwd=root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)['observations'], 1)
