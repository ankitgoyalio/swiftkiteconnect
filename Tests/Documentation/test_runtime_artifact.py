"""Exercise the runtime transfer CLI and the Actions scheduling contract."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'Scripts/runtime-artifact.py'


class RuntimeArtifact(unittest.TestCase):
    def test_runtime_can_start_independently_and_ios_waits_only_for_runtime(self):
        result = subprocess.run([
            'ruby', '-rjson', '-ryaml', '-e',
            'puts JSON.generate(YAML.load_file(ARGV[0]))',
            str(ROOT / '.github/workflows/protocol-tests.yml')],
            check=True, capture_output=True, text=True)
        jobs = json.loads(result.stdout)['jobs']
        self.assertNotIn('needs', jobs['ios18-runtime'])
        self.assertEqual(jobs['minimum-ios']['needs'], 'ios18-runtime')
        self.assertEqual(set(jobs['minimum-apple']['needs']),
                         {'minimum-macos', 'minimum-ios'})

    def test_transfer_rejects_wrong_candidate_run_runtime_and_modified_image(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            image = folder / 'runtime.dmg'
            image.write_bytes(b'controlled runtime image')
            inventory = folder / 'inventory.json'
            inventory.write_text(json.dumps({'runtimes': [{
                'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-18-5',
                'version': '18.5', 'buildversion': '22F77', 'isAvailable': True,
            }]}))
            env = dict(os.environ, GITHUB_REPOSITORY='ankitgoyalio/swiftkiteconnect',
                       GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='1',
                       GITHUB_SHA=subprocess.check_output(
                           ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip())

            def run(command, environment=env):
                return subprocess.run(['python3', str(SCRIPT), command,
                                       str(folder), str(inventory)], cwd=ROOT,
                                      env=environment, capture_output=True, text=True)

            created = run('create')
            self.assertEqual(created.returncode, 0, created.stderr)
            manifest = folder / 'manifest.json'
            original = manifest.read_text()
            self.assertEqual(run('verify').returncode, 0)
            self.assertEqual(run('verify-installed').returncode, 0)
            for field in ('GITHUB_REPOSITORY', 'GITHUB_RUN_ID',
                          'GITHUB_RUN_ATTEMPT', 'GITHUB_SHA'):
                with self.subTest(field=field):
                    self.assertNotEqual(run('verify', dict(env, **{field: 'wrong'})).returncode, 0)
            for field, value in [('runtime', 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'),
                                 ('version', '27.0'), ('architecture', 'wrong'),
                                 ('build', ''), ('image', '../runtime.dmg')]:
                with self.subTest(field=field):
                    altered = json.loads(original)
                    altered[field] = value
                    manifest.write_text(json.dumps(altered))
                    self.assertNotEqual(run('verify').returncode, 0)
            manifest.write_text(original)
            wrong = json.loads(inventory.read_text())
            wrong['runtimes'][0]['buildversion'] = 'wrong'
            inventory.write_text(json.dumps(wrong))
            self.assertNotEqual(run('verify-installed').returncode, 0)
            image.write_bytes(b'modified runtime image')
            self.assertNotEqual(run('verify').returncode, 0)
            image.unlink()
            self.assertNotEqual(run('verify').returncode, 0)

    def test_import_requires_immutable_same_run_artifact_and_verified_identity(self):
        result = subprocess.run([
            'ruby', '-rjson', '-ryaml', '-e',
            'puts JSON.generate(YAML.load_file(ARGV[0]))',
            str(ROOT / '.github/workflows/protocol-tests.yml')],
            check=True, capture_output=True, text=True)
        jobs = json.loads(result.stdout)['jobs']
        export = jobs['ios18-runtime']
        self.assertEqual(export['outputs']['artifact-id'],
                         '${{ steps.runtime-upload.outputs.artifact-id }}')
        steps = jobs['minimum-ios']['steps']
        download = next(step for step in steps
                        if 'download-artifact@' in step.get('uses', ''))
        self.assertEqual(download['with']['artifact-ids'],
                         '${{ needs.ios18-runtime.outputs.artifact-id }}')
        self.assertNotIn('run-id', download['with'])
        self.assertNotIn('github-token', download['with'])
        commands = [step.get('run', '') for step in steps]
        verify = next(i for i, command in enumerate(commands)
                      if 'runtime-artifact.py verify ' in command)
        importing = next(i for i, command in enumerate(commands)
                         if 'xcodebuild -importPlatform' in command)
        installed = next(i for i, command in enumerate(commands)
                         if 'runtime-artifact.py verify-installed ' in command)
        testing = next(i for i, command in enumerate(commands)
                       if 'bash Scripts/test-ios.sh' in command)
        self.assertLess(verify, importing)
        self.assertLess(importing, installed)
        self.assertLess(installed, testing)
        for index in (verify, importing, installed, testing):
            self.assertFalse(steps[index].get('continue-on-error', False))
            self.assertNotIn('if', steps[index])
