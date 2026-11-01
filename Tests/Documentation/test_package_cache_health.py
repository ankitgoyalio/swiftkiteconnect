"""Cache CLI health checks use actual local Git repositories, without network."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'Scripts/ci-package-cache.py'


class DownloadCacheHealth(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.origin = self.root / 'origin'
        self.git('init', str(self.origin))
        (self.origin / 'package.txt').write_text('known package content\n')
        self.git('-C', str(self.origin), 'add', '.')
        self.git('-C', str(self.origin), '-c', 'user.name=Fixture',
                 '-c', 'user.email=fixture@example.invalid', 'commit', '-m', 'fixture')
        self.cache = self.root / 'cache'
        self.repository = self.cache / 'repositories/package'
        self.repository.parent.mkdir(parents=True)
        self.git('clone', '--mirror', '--no-local', str(self.origin), str(self.repository))
        (self.cache / 'credentials').write_text('preserved')
        self.scratch = self.root / 'scratch'
        self.scratch.mkdir()
        (self.scratch / 'stale').write_text('discard with poison')
        # Simulate a resolver that returns success by using its origin when a
        # cached repo is damaged, without repairing the existing download cache.
        resolver = self.root / 'swift'
        resolver.write_text(f'''#!{sys.executable}
import os, pathlib, shutil, subprocess, sys
assert ('--force-resolved-versions' in sys.argv and '--enable-dependency-cache' in sys.argv) or '-onlyUsePackageVersionsFromResolvedFile' in sys.argv
root = pathlib.Path(os.environ['FIXTURE'])
cache = pathlib.Path(sys.argv[sys.argv.index('--cache-path') + 1]) if '--cache-path' in sys.argv else pathlib.Path(sys.argv[sys.argv.index('-packageCachePath') + 1])
repo = cache / 'repositories/package'
scratch = pathlib.Path(sys.argv[sys.argv.index('--scratch-path') + 1]) if '--scratch-path' in sys.argv else pathlib.Path(sys.argv[sys.argv.index('-clonedSourcePackagesDirPath') + 1])
with (root / 'attempts').open('a') as output:
    output.write('resolve\\n')
if os.environ.get('FAIL_ALWAYS') or (os.environ.get('FAIL_FIRST') and (root / 'attempts').read_text() == 'resolve\\n'):
    sys.exit(19)
if not repo.exists() and not os.environ.get('EMPTY_CACHE'):
    subprocess.run(['git', 'clone', '--mirror', '--no-local', str(root / 'origin'), str(repo)], check=True)
if os.environ.get('POISON_ALWAYS') or (os.environ.get('POISON_ONCE') and not (root / 'poisoned').exists()):
    shutil.rmtree(repo / 'objects')
    (root / 'poisoned').touch()
# Try the shared cache, then bypass it from origin, leaving poison untouched.
checkout = scratch / 'resolved'
if not checkout.exists():
    result = subprocess.run(['git', 'clone', '--no-local', str(repo), str(checkout)])
    if result.returncode:
        subprocess.run(['git', 'clone', '--no-local', str(root / 'origin'), str(checkout)], check=True)
''')
        resolver.chmod(0o755)
        (self.root / 'xcodebuild').symlink_to(resolver)
        self.env = dict(os.environ, PATH=f'{self.root}:{os.environ["PATH"]}',
                        FIXTURE=str(self.root), GITHUB_OUTPUT=str(self.root / 'outputs'))

    def git(self, *arguments):
        result = subprocess.run(['git', *arguments], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def resolve(self, kind='swift'):
        (self.root / 'outputs').write_text('')
        return subprocess.run([sys.executable, str(SCRIPT), 'resolve', '--kind', kind,
                               '--cache-root', str(self.cache), '--scratch', str(self.scratch)],
                              env=self.env, capture_output=True, text=True)

    def assert_healthy_and_reusable(self):
        self.git('--git-dir', str(self.repository), 'fsck', '--full')
        # A subsequent consumer reads the exact shared bare cache with no origin
        # access or resolver fallback. Clone transfers objects rather than links.
        self.git('clone', '--no-local', str(self.repository), str(self.root / 'consumer'))
        self.assertEqual((self.root / 'consumer/package.txt').read_text(), 'known package content\n')
        self.assertEqual((self.cache / 'credentials').read_text(), 'preserved')
        self.assertFalse((self.scratch / 'stale').exists())
        self.assertIn('recovered=true\n', (self.root / 'outputs').read_text())
        self.assertIn('healthy=true\n', (self.root / 'outputs').read_text())

    def test_invalid_bare_cache_is_discarded_before_successful_resolver_for_both_kinds(self):
        for kind in ('swift', 'xcode'):
            with self.subTest(kind=kind):
                shutil.rmtree(self.repository / 'objects')
                result = self.resolve(kind)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assert_healthy_and_reusable()
                shutil.rmtree(self.root / 'consumer')
        self.assertEqual((self.root / 'attempts').read_text(), 'resolve\nresolve\n')

    def test_missing_reachable_object_is_repaired(self):
        oid = self.git('-C', str(self.origin), 'rev-parse', 'HEAD:package.txt')
        # Use the loose source objects, then remove a known reachable blob.
        shutil.rmtree(self.repository / 'objects')
        shutil.copytree(self.origin / '.git/objects', self.repository / 'objects')
        (self.repository / 'objects' / oid[:2] / oid[2:]).unlink()
        result = self.resolve()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_healthy_and_reusable()

    def test_command_success_with_still_poisoned_cache_gets_one_clean_retry(self):
        self.env['POISON_ONCE'] = '1'
        result = self.resolve()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.root / 'attempts').read_text(), 'resolve\nresolve\n')
        self.assert_healthy_and_reusable()
        # A normal next resolution uses healthy state without another recovery.
        self.env.pop('POISON_ONCE')
        shutil.rmtree(self.scratch)
        self.origin.rename(self.root / 'origin-offline')
        result = self.resolve()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('recovered=false\n', (self.root / 'outputs').read_text())
        self.assertEqual((self.scratch / 'resolved/package.txt').read_text(), 'known package content\n')

    def test_resolver_failure_retries_once_and_preserves_final_status(self):
        self.env['FAIL_FIRST'] = '1'
        result = self.resolve()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.root / 'attempts').read_text(), 'resolve\nresolve\n')
        self.assert_healthy_and_reusable()
        (self.root / 'attempts').write_text('')
        self.env['FAIL_ALWAYS'] = '1'
        result = self.resolve()
        self.assertEqual(result.returncode, 19, result.stdout + result.stderr)
        self.assertEqual((self.root / 'attempts').read_text(), 'resolve\nresolve\n')
        self.assertNotIn('healthy=true', (self.root / 'outputs').read_text())

    def test_invalid_restore_allows_only_one_clean_command(self):
        shutil.rmtree(self.repository / 'objects')
        self.env['FAIL_ALWAYS'] = '1'
        result = self.resolve()
        self.assertEqual(result.returncode, 19, result.stdout + result.stderr)
        self.assertEqual((self.root / 'attempts').read_text(), 'resolve\n')
        self.assertIn('recovered=true\nhealthy=false\n', (self.root / 'outputs').read_text())
        self.assertEqual((self.cache / 'credentials').read_text(), 'preserved')

    def test_success_cannot_save_persistent_poison_or_empty_downloads(self):
        for problem in ('POISON_ALWAYS', 'EMPTY_CACHE'):
            with self.subTest(problem=problem):
                shutil.rmtree(self.repository.parent, ignore_errors=True)
                (self.root / 'attempts').write_text('')
                self.env.pop('POISON_ALWAYS', None)
                self.env[problem] = '1'
                result = self.resolve()
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((self.root / 'attempts').read_text(), 'resolve\nresolve\n')
                self.assertNotIn('healthy=true', (self.root / 'outputs').read_text())
                self.assertEqual((self.cache / 'credentials').read_text(), 'preserved')
