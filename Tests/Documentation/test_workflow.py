"""Audit the Actions publication boundary; Ruby supplies the macOS YAML parser."""
import itertools
import json
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PublicationWorkflow(unittest.TestCase):
    def test_minimum_gate_fails_if_either_suite_does_not_succeed(self):
        result = subprocess.run([
            'ruby', '-rjson', '-ryaml', '-e',
            'puts JSON.generate(YAML.load_file(ARGV[0]))',
            str(ROOT / '.github/workflows/protocol-tests.yml')],
            check=True, capture_output=True, text=True)
        job = json.loads(result.stdout)['jobs']['minimum-apple']
        self.assertEqual(set(job['needs']), {'minimum-macos', 'minimum-ios'})
        self.assertEqual(job['if'], 'always()')
        gate = job['steps'][0]
        self.assertEqual(gate['env'], {
            'MACOS_RESULT': '${{ needs.minimum-macos.result }}',
            'IOS_RESULT': '${{ needs.minimum-ios.result }}',
        })
        for macos, ios in itertools.product(
                ('success', 'failure', 'cancelled', 'skipped', ''), repeat=2):
            result = subprocess.run(
                ['bash', '-c', gate['run']],
                env=dict(os.environ, MACOS_RESULT=macos, IOS_RESULT=ios),
                capture_output=True, text=True)
            self.assertEqual(result.returncode == 0,
                             macos == ios == 'success', (macos, ios))

    def test_only_successful_main_push_can_publish(self):
        result = subprocess.run([
            'ruby', '-rjson', '-ryaml', '-e',
            'puts JSON.generate(YAML.load_file(ARGV[0]))',
            str(ROOT / '.github/workflows/protocol-tests.yml')],
            check=True, capture_output=True, text=True)
        workflow = json.loads(result.stdout)
        jobs = workflow['jobs']
        self.assertIn('deploy', jobs)
        deploy = jobs['deploy']
        self.assertEqual(set(deploy['needs']), {'apple', 'ubuntu'})
        self.assertEqual(workflow['permissions'], {'contents': 'read'})
        self.assertEqual(deploy['permissions'], {'pages': 'write', 'id-token': 'write'})
        for name in ('apple', 'apple-platform', 'docc', 'ubuntu'):
            self.assertNotIn('permissions', jobs[name])
            self.assertFalse(jobs[name].get('continue-on-error', False))
        # Evaluate the actual declarative condition for events, refs and job
        # outcomes, including skipped/cancelled jobs. Unknown syntax fails.
        condition = ' '.join(deploy['if'].removeprefix('${{').removesuffix('}}').split())
        for event, ref, apple, ubuntu in itertools.product(
                ('push', 'pull_request', 'workflow_dispatch'),
                ('refs/heads/main', 'refs/heads/integration/docc-30'),
                ('success', 'failure', 'cancelled', 'skipped'),
                ('success', 'failure', 'cancelled', 'skipped')):
            expression = condition
            for key, value in {
                'github.event_name': event, 'github.ref': ref,
                'needs.apple.result': apple, 'needs.ubuntu.result': ubuntu,
            }.items():
                expression = expression.replace(key, repr(value))
            expression = expression.replace('&&', ' and ').replace('||', ' or ')
            allowed = eval(expression, {'__builtins__': {}}, {})
            expected = (event == 'push' and ref == 'refs/heads/main'
                        and apple == 'success' and ubuntu == 'success')
            self.assertEqual(allowed, expected, (event, ref, apple, ubuntu))
        self.assertEqual(deploy['environment']['name'], 'github-pages')
        self.assertFalse(deploy.get('continue-on-error', False))
        publish = [step for step in deploy['steps'] if 'deploy-pages@' in step.get('uses', '')]
        self.assertEqual(len(publish), 1)
        uploads = [step for step in jobs['docc']['steps']
                   if 'upload-pages-artifact@' in step.get('uses', '')]
        self.assertEqual(len(uploads), 1)
        self.assertEqual(uploads[0]['with']['path'], '.build/documentation/site')
        artifacts = [step for step in jobs['docc']['steps']
                     if step.get('with', {}).get('name') == 'docc-site']
        self.assertEqual(len(artifacts), 1)
        self.assertEqual(artifacts[0]['with']['path'], '.build/documentation/docc-validation.tar')

    def test_pinned_formatter_and_base_check_block_apple_job(self):
        result = subprocess.run([
            'ruby', '-rjson', '-ryaml', '-e',
            'puts JSON.generate(YAML.load_file(ARGV[0]))',
            str(ROOT / '.github/workflows/protocol-tests.yml')],
            check=True, capture_output=True, text=True)
        apple = json.loads(result.stdout)['jobs']['apple-platform']['steps']
        install = next(step for step in apple if step.get('name') == 'Install pinned SwiftFormat')
        enforce = next(step for step in apple if step.get('name') == 'Enforce authored changes with commit checks')
        pin = (ROOT / '.githooks/check_swift_format.py').read_text().split('SWIFTFORMAT_VERSION = "')[1].split('"')[0]
        self.assertIn(f'/download/{pin}/swiftformat.zip', install['run'])
        self.assertIn('python3 Scripts/check-development.py', enforce['run'])
        self.assertIn('swiftformat . --lint --config .swiftformat', enforce['run'])
        self.assertIn('python3 .githooks/pre-commit --base "$base"', enforce['run'])
        self.assertIn('github.event.pull_request.base.sha', enforce['env']['CHECK_BASE'])
        self.assertIn('github.event.before', enforce['env']['CHECK_BASE'])
        self.assertFalse(enforce.get('continue-on-error', False))
        self.assertNotIn('if', enforce)
        self.assertEqual(apple[0]['with']['fetch-depth'], 0)

    def test_apple_gate_requires_platform_tests_and_documentation(self):
        result = subprocess.run([
            'ruby', '-rjson', '-ryaml', '-e',
            'puts JSON.generate(YAML.load_file(ARGV[0]))',
            str(ROOT / '.github/workflows/protocol-tests.yml')],
            check=True, capture_output=True, text=True)
        jobs = json.loads(result.stdout)['jobs']
        gate = jobs['apple']
        self.assertEqual(set(gate['needs']), {'apple-platform', 'docc'})
        self.assertEqual(gate['if'], 'always()')
        for name in ('apple-platform', 'docc'):
            self.assertNotIn('needs', jobs[name])
            self.assertNotIn('if', jobs[name])
        step = gate['steps'][0]
        self.assertEqual(step['env'], {
            'PLATFORM_RESULT': '${{ needs.apple-platform.result }}',
            'DOCC_RESULT': '${{ needs.docc.result }}',
        })
        for platform, docc in itertools.product(
                ('success', 'failure', 'cancelled', 'skipped', ''), repeat=2):
            result = subprocess.run(
                ['bash', '-c', step['run']],
                env=dict(os.environ, PLATFORM_RESULT=platform, DOCC_RESULT=docc),
                capture_output=True, text=True)
            self.assertEqual(result.returncode == 0,
                             platform == docc == 'success', (platform, docc))

    def test_minimum_ios_waits_for_runtime_without_waiting_for_macos_tests(self):
        result = subprocess.run([
            'ruby', '-rjson', '-ryaml', '-e',
            'puts JSON.generate(YAML.load_file(ARGV[0]))',
            str(ROOT / '.github/workflows/protocol-tests.yml')],
            check=True, capture_output=True, text=True)
        jobs = json.loads(result.stdout)['jobs']
        self.assertEqual(jobs['minimum-ios']['needs'], 'ios18-runtime')
        runtime = jobs['ios18-runtime']
        self.assertNotIn('needs', runtime)
        self.assertNotIn('if', runtime)
        self.assertFalse(runtime.get('continue-on-error', False))
        self.assertEqual(runtime['runs-on'], 'macos-15')
        self.assertEqual(runtime['env']['DEVELOPER_DIR'],
                         '/Applications/Xcode_16.4.app/Contents/Developer')
        uploads = [step for step in runtime['steps']
                   if step.get('with', {}).get('name') == 'ios18-runtime']
        self.assertEqual(len(uploads), 1)
        self.assertEqual(uploads[0]['with']['compression-level'], 0)
        downloads = [step for step in jobs['minimum-ios']['steps']
                     if 'download-artifact@' in step.get('uses', '')]
        self.assertEqual(len(downloads), 1)
        # No run-id/repository override: consume only this run's runtime artifact.
        self.assertEqual(downloads[0]['with'], {
            'name': 'ios18-runtime', 'path': '${{ runner.temp }}/ios18-runtime',
        })
        self.assertEqual(set(jobs['minimum-apple']['needs']),
                         {'minimum-macos', 'minimum-ios'})

    def test_runtime_export_initializes_simulator_service_first(self):
        result = subprocess.run([
            'ruby', '-rjson', '-ryaml', '-e',
            'puts JSON.generate(YAML.load_file(ARGV[0]))',
            str(ROOT / '.github/workflows/protocol-tests.yml')],
            check=True, capture_output=True, text=True)
        steps = json.loads(result.stdout)['jobs']['ios18-runtime']['steps']
        export = next(i for i, step in enumerate(steps)
                      if 'xcodebuild -downloadPlatform' in step.get('run', ''))
        initializers = [step for step in steps[:export]
                        if 'xcrun simctl list runtimes' in step.get('run', '')]
        self.assertEqual(len(initializers), 1)
        self.assertIn('xcrun simctl list devices available', initializers[0]['run'])
        self.assertLessEqual(initializers[0]['timeout-minutes'], 5)
