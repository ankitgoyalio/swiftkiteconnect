"""Audit the Actions publication boundary; Ruby supplies the macOS YAML parser."""
import itertools
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PublicationWorkflow(unittest.TestCase):
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
        for name in ('apple', 'ubuntu'):
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
        uploads = [step for step in jobs['apple']['steps']
                   if 'upload-pages-artifact@' in step.get('uses', '')]
        self.assertEqual(len(uploads), 1)
        self.assertEqual(uploads[0]['with']['path'], '.build/documentation/site')
        artifacts = [step for step in jobs['apple']['steps']
                     if step.get('with', {}).get('name') == 'docc-site']
        self.assertEqual(len(artifacts), 1)
        self.assertEqual(artifacts[0]['with']['path'], '.build/documentation/docc-validation.tar')
