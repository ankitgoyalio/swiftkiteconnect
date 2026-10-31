"""Read-only Actions API snapshot collection. Never execute measured-run code."""
import base64
import json
from pathlib import Path
import subprocess
from urllib.parse import quote

from ci_timing_details import environment, job_logs


def collect(repo, run_id, output):
    warnings = []

    def api(endpoint, paginated=False):
        command = ['gh', 'api']
        if paginated:
            command += ['--paginate', '--slurp']
        return subprocess.run(command + [f'repos/{repo}/{endpoint}'],
                              check=True, capture_output=True).stdout

    run = json.loads(api(f'actions/runs/{run_id}'))
    attempt = run['run_attempt']
    path = output or Path(f'.test-results/ci-timing/{run_id}-attempt-{attempt}')
    # Do not mix evidence from separate snapshots or leave stale logs on retry.
    path.mkdir(parents=True, exist_ok=False)
    (path / 'run.json').write_text(json.dumps(run, indent=2) + '\n')
    pages = api(f'actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100', True)
    (path / 'jobs-pages.json').write_bytes(pages)
    jobs = [job for page in json.loads(pages) for job in page['jobs']]
    (path / 'jobs.json').write_text(json.dumps({'jobs': jobs}, indent=2) + '\n')
    for filename, endpoint, paginated in [
        ('logs.zip', f'actions/runs/{run_id}/attempts/{attempt}/logs', False),
        ('artifacts.json', f'actions/runs/{run_id}/artifacts?per_page=100', True),
    ]:
        try:
            (path / filename).write_bytes(api(endpoint, paginated))
        except subprocess.CalledProcessError as error:
            warnings.append(f'{filename}: {error.stderr.decode().strip()}')
    logs = job_logs(path / 'logs.zip')
    revisions = {environment(log)['tested_revision'] for log in logs.values()}
    revisions.discard(None)
    if len(revisions) > 1:
        raise ValueError(f'Inconsistent tested checkout revisions: {revisions}')
    revision = next(iter(revisions), run['head_sha'])
    if not revisions:
        warnings.append('Tested checkout revision unavailable; workflow snapshot uses source head_sha.')
    content = api('contents/.github/workflows/protocol-tests.yml?ref=' + quote(revision, safe=''))
    (path / 'workflow-api.json').write_bytes(content)
    (path / 'workflow.yml').write_bytes(base64.b64decode(json.loads(content)['content']))
    # Artifacts list is run-scoped, not attempt-scoped; do not infer provenance from its names.
    warnings.append('Artifact listing is run-scoped; timestamps/attempt provenance must be checked before reuse.')
    (path / 'collection-warnings.txt').write_text('\n'.join(warnings) + '\n')
    return path
