"""Exercise timing reports through the replay CLI, without GitHub access."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def job(name, start, end, conclusion='success', steps=None):
    return dict(name=name, status='completed', conclusion=conclusion,
                started_at=f'2026-10-30T00:{start}:00Z',
                completed_at=f'2026-10-30T00:{end}:00Z', steps=steps or [],
                runner_name='hosted', labels=['ubuntu-24.04'])


class TimingCLI(unittest.TestCase):
    def report(self, jobs, log=None, **changes):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            run = dict(id=1, run_attempt=1, status='completed', conclusion='success',
                       created_at='2026-10-30T00:00:00Z', event='pull_request',
                       head_sha='source', html_url='https://example.test/run/1')
            run.update(changes)
            (path / 'run.json').write_text(json.dumps(run))
            (path / 'jobs.json').write_text(json.dumps({'jobs': jobs}))
            (path / 'workflow.yml').write_text('''jobs:
  apple:
  ubuntu:
  minimum-macos:
  minimum-ios:
    needs: minimum-macos
  minimum-apple:
    needs: [minimum-macos, minimum-ios]
''')
            if log is not None:
                import zipfile
                with zipfile.ZipFile(path / 'logs.zip', 'w') as archive:
                    archive.writestr('0_apple.txt', log)
            result = subprocess.run(['python3', str(ROOT / 'Scripts/ci-timing.py'),
                                     '--replay', str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            measurement = json.loads((path / 'measurement.json').read_text())
            measurement['_summary'] = (path / 'summary.md').read_text()
            return measurement

    def successful_jobs(self):
        return [job('apple', '01', '05'), job('ubuntu', '01', '04'),
                job('minimum-macos', '02', '06'), job('minimum-ios', '07', '10'),
                job('minimum-apple', '11', '12')]

    def test_parallel_jobs_report_elapsed_wait_and_runner_cost_separately(self):
        report = self.report(self.successful_jobs())
        self.assertTrue(report['qualified'])
        self.assertEqual(report['required_wait_seconds'], 720)
        self.assertEqual(report['runner_minutes'], 15)
        self.assertEqual(report['completion_chain'],
                         ['minimum-macos', 'minimum-ios', 'minimum-apple'])
        self.assertEqual(report['jobs']['minimum-ios']['queue_seconds'], 60)
        self.assertEqual(report['jobs']['minimum-ios']['dependency_wait_seconds'], 360)
        self.assertEqual(report['jobs']['minimum-ios']['execution_seconds'], 180)

    def test_failed_pages_deploy_preserves_successful_required_check_wait(self):
        jobs = self.successful_jobs() + [job('deploy', '13', '14', 'failure')]
        report = self.report(jobs, conclusion='failure')
        self.assertTrue(report['qualified'])
        self.assertEqual(report['successful_required_wait_seconds'], 720)
        self.assertEqual(report['classification'], 'failure')
        self.assertEqual(report['runner_minutes'], 16)
        self.assertEqual(report['required_runner_minutes'], 15)

    def test_required_success_is_independent_of_cancelled_or_incomplete_workflow(self):
        for status, conclusion, classification in (
                ('completed', 'cancelled', 'cancelled'),
                ('in_progress', None, 'incomplete')):
            with self.subTest(status=status, conclusion=conclusion):
                jobs = self.successful_jobs() + [dict(
                    name='deploy', status=status, conclusion=conclusion, steps=[])]
                report = self.report(jobs, status=status, conclusion=conclusion)
                self.assertTrue(report['qualified'])
                self.assertEqual(report['successful_required_wait_seconds'], 720)
                self.assertEqual(report['classification'], classification)
                self.assertEqual(report['workflow_status'], status)
                self.assertEqual(report['workflow_conclusion'], conclusion)
                self.assertIsNone(report['runner_minutes'])
                self.assertIn('Required qualification: **success**', report['_summary'])
                self.assertIn(f'Workflow status: `{status}`', report['_summary'])

    def test_failed_and_cancelled_required_work_cannot_qualify(self):
        for conclusion in ('failure', 'cancelled'):
            jobs = self.successful_jobs()
            jobs[3]['conclusion'] = conclusion
            report = self.report(jobs, conclusion=conclusion)
            self.assertFalse(report['qualified'])
            self.assertEqual(report['classification'], conclusion)
            self.assertIsNone(report['successful_required_wait_seconds'])
            self.assertEqual(report['required_wait_seconds'], 720)

    def test_missing_reversed_or_placeholder_timestamps_never_qualify(self):
        for field, value in [('completed_at', None),
                             ('started_at', '0001-01-01T00:00:00Z'),
                             ('completed_at', '2026-10-29T00:00:00Z')]:
            jobs = self.successful_jobs()
            jobs[3][field] = value
            report = self.report(jobs)
            self.assertFalse(report['qualified'])
            self.assertEqual(report['classification'], 'incomplete')
            self.assertIsNone(report['runner_minutes'])
            self.assertIsNone(report['successful_required_wait_seconds'])
        report = self.report(self.successful_jobs()[:-1], status='in_progress', conclusion=None)
        self.assertFalse(report['qualified'])
        self.assertIsNone(report['required_wait_seconds'])
        self.assertIsNone(report['completion_chain'])

    def test_missing_or_skipped_work_cannot_hide_behind_successful_aggregate(self):
        for change in ('missing', 'skipped', 'failure'):
            jobs = self.successful_jobs()
            if change == 'missing':
                jobs.pop(2)
            else:
                jobs[2]['conclusion'] = change
            report = self.report(jobs)
            self.assertFalse(report['qualified'])
            self.assertIsNone(report['successful_required_wait_seconds'])

    def test_step_costs_and_environment_have_provenance_and_unknowns(self):
        jobs = self.successful_jobs()
        jobs[0]['steps'] = [dict(name='Build macOS tests', status='completed',
                                conclusion='success', started_at='2026-10-30T00:01:00Z',
                                completed_at='2026-10-30T00:03:00Z'),
                            dict(name='macOS public protocol tests', status='completed',
                                 conclusion='success', started_at='2026-10-30T00:03:00Z',
                                 completed_at=None)]
        report = self.report(jobs, log="""2026-10-30T00:00:00Z ##[group]Runner Image
2026-10-30T00:00:00Z Image: xcode-27-arm64
2026-10-30T00:00:00Z Version: 20261026.0314.1
2026-10-30T00:00:00Z ##[endgroup]
2026-10-30T00:00:00Z [command]/usr/bin/git log -1 --format=%H
2026-10-30T00:00:00Z 0123456789012345678901234567890123456789
2026-10-30T00:00:00Z Apple Swift version 6.4 (swift-6.4-RELEASE)
2026-10-30T00:00:00Z Target: arm64-apple-macosx27.0.0
""")
        apple = report['jobs']['apple']
        self.assertEqual(apple['costs_seconds']['build'], 120)
        self.assertIsNone(apple['costs_seconds']['test'])
        self.assertEqual(apple['environment']['tested_revision'], '0123456789012345678901234567890123456789')
        self.assertEqual(apple['environment']['runner_image'], 'xcode-27-arm64 20261026.0314.1')
        self.assertEqual(apple['environment']['architecture'], 'arm64')
        self.assertIsNone(apple['environment']['sdk'])
        self.assertIn('sdk', apple['unavailable'])

    def test_cache_transfer_costs_are_separate_from_build_and_artifact_costs(self):
        jobs = self.successful_jobs()
        jobs[0]['steps'] = [
            dict(name=name, conclusion='success',
                 started_at='2026-10-30T00:01:00Z',
                 completed_at='2026-10-30T00:02:00Z')
            for name in ('Restore compatible compilation outputs',
                         'Save qualified compilation products',
                         'Run ./.github/actions/package-downloads')]
        report = self.report(jobs)
        costs = report['jobs']['apple']['costs_seconds']
        self.assertEqual(costs.get('cache_restore'), 60)
        self.assertEqual(costs.get('cache_save'), 60)
        # Composite action metadata exposes an envelope, not separate transfers.
        self.assertEqual(costs.get('cache'), 60)
        self.assertIsNone(costs['artifact'])
        self.assertIn('Cache restore s', report['_summary'])
        self.assertIn('Cache save s', report['_summary'])
        self.assertIn('Cache envelope s', report['_summary'])

    def test_ios_commands_that_compile_are_not_reported_as_isolated_test_cost(self):
        jobs = self.successful_jobs()
        jobs[0]['steps'] = [
            dict(name=name, conclusion='success',
                 started_at='2026-10-30T00:01:00Z',
                 completed_at='2026-10-30T00:02:00Z')
            for name in ('iOS Simulator public protocol and real loopback HTTP tests',
                         'iOS 18 public protocol and real transport tests')]
        costs = self.report(jobs)['jobs']['apple']['costs_seconds']
        self.assertEqual(costs['mixed_qualification'], 120)
        self.assertIsNone(costs['test'])

    def test_queued_job_placeholder_start_does_not_report_dispatch_latency(self):
        jobs = self.successful_jobs()
        jobs[0].update(status='queued', conclusion=None, completed_at=None)
        report = self.report(jobs, status='queued', conclusion=None)
        self.assertIsNone(report['jobs']['apple']['queue_seconds'])
        self.assertIsNone(report['jobs']['apple']['execution_seconds'])
        self.assertFalse(report['qualified'])

    def test_summary_is_compact_and_marks_unknown_environment(self):
        report = self.report(self.successful_jobs())
        self.assertIn('Required-check wait: 720', report['_summary'])
        self.assertIn('Runner minutes', report['_summary'])
        self.assertIn('minimum-macos → minimum-ios → minimum-apple', report['_summary'])
        self.assertIn('unavailable', report['_summary'])
        self.assertEqual(report['required_conclusions'],
                         {'apple': 'success', 'ubuntu': 'success', 'minimum-apple': 'success'})

    def test_collection_retains_paginated_api_data_for_the_specific_attempt(self):
        import os
        import base64
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            executable = path / 'gh'
            # Fake only the external gh boundary; run the real collection CLI.
            responses = {
                'actions/runs/1': dict(id=1, run_attempt=2, head_sha='source',
                                      status='in_progress', conclusion=None),
                'actions/runs/1/attempts/2/jobs?per_page=100': [
                    {'jobs': self.successful_jobs()[:2]}, {'jobs': self.successful_jobs()[2:]}],
                'actions/runs/1/artifacts?per_page=100': [{'artifacts': []}],
                'contents/.github/workflows/protocol-tests.yml?ref=source': {
                    'content': base64.b64encode(b'jobs:\n  apple:\n  ubuntu:\n  minimum-apple:\n').decode()},
            }
            (path / 'responses.json').write_text(json.dumps(responses))
            executable.write_text('''#!/usr/bin/env python3
import json, pathlib, sys
root = pathlib.Path(__file__).parent
key = sys.argv[-1].split('repos/owner/repo/')[1]
if key.endswith('/logs'):
    sys.stderr.write('logs not ready')
    sys.exit(1)
print(json.dumps(json.loads((root / 'responses.json').read_text())[key]))
''')
            executable.chmod(0o755)
            result = subprocess.run(['python3', str(ROOT / 'Scripts/ci-timing.py'),
                                     '--run-id', '1', '--repo', 'owner/repo',
                                     '--output', str(path / 'evidence')],
                                    env=dict(os.environ, PATH=str(path) + os.pathsep + os.environ['PATH']),
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            evidence = path / 'evidence'
            self.assertEqual(len(json.loads((evidence / 'jobs.json').read_text())['jobs']), 5)
            report = json.loads((evidence / 'measurement.json').read_text())
            self.assertFalse(report['qualified'])
            self.assertIn('logs not ready', (evidence / 'collection-warnings.txt').read_text())
            self.assertTrue((evidence / 'run.json').is_file())

    def test_summary_workflow_cannot_change_qualification_or_execute_measured_code(self):
        result = subprocess.run(['ruby', '-rjson', '-ryaml', '-e',
                                 'puts JSON.generate(YAML.load_file(ARGV[0]))',
                                 str(ROOT / '.github/workflows/ci-timing.yml')],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        workflow = json.loads(result.stdout)
        self.assertEqual(workflow['permissions'], {'contents': 'read', 'actions': 'read'})
        job = workflow['jobs']['timing']
        checkout = job['steps'][0]
        self.assertEqual(checkout['with']['ref'], '${{ github.event.repository.default_branch }}')
        self.assertFalse(checkout['with']['persist-credentials'])
        self.assertNotIn('needs', job)
        self.assertTrue(any(s.get('with', {}).get('name', '').startswith('ci-timing-')
                            for s in job['steps']))

    def test_intentionally_skipped_deployment_consumes_no_runner_minutes(self):
        jobs = self.successful_jobs() + [dict(name='deploy', status='completed',
                                             conclusion='skipped', steps=[])]
        report = self.report(jobs)
        self.assertTrue(report['qualified'])
        self.assertEqual(report['runner_minutes'], 15)
        self.assertIsNone(report['jobs']['deploy']['execution_seconds'])

    def test_replay_rejects_object_tags_in_untrusted_workflow_snapshots(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / 'run.json').write_text(json.dumps(dict(id=1, status='in_progress')))
            (path / 'jobs.json').write_text('{"jobs": []}')
            (path / 'workflow.yml').write_text('name: !ruby/object:Object {}\njobs: {}\n')
            result = subprocess.run(['python3', str(ROOT / 'Scripts/ci-timing.py'),
                                     '--replay', str(path)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
