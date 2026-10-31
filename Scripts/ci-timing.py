#!/usr/bin/env python3
"""Collect or replay Protocol tests timing evidence. See docs/development.md."""
import argparse
import hashlib
from datetime import datetime
import json
from pathlib import Path
import subprocess

from ci_timing_details import details, job_logs
from ci_timing_collect import collect

REQUIRED = ('apple', 'ubuntu', 'minimum-apple')


def timestamp(value):
    if not value:
        return None
    try:
        result = datetime.fromisoformat(value.replace('Z', '+00:00'))
        return result if result.year >= 2000 and result.tzinfo else None
    except (ValueError, TypeError):
        return None


def seconds(start, end):
    return (end - start).total_seconds() if start and end and end >= start else None


def workflow_jobs(path):
    result = subprocess.run(['ruby', '-rjson', '-ryaml', '-e',
                             'puts JSON.generate(YAML.safe_load(File.read(ARGV[0]), aliases: false))', str(path)],
                            check=True, capture_output=True, text=True)
    return json.loads(result.stdout)['jobs']


def measure(run, jobs, workflow, logs=None):
    logs = logs or {}
    created = timestamp(run.get('created_at'))
    indexed = {job['name']: job for job in jobs}
    if len(indexed) != len(jobs):
        raise ValueError('Duplicate job names cannot be measured unambiguously')
    measured = {}

    def dependencies(name):
        needs = (workflow.get(name) or {}).get('needs', [])
        return [needs] if isinstance(needs, str) else needs

    def chain(name):
        needs = dependencies(name)
        if not needs:
            return [name]
        latest = max(needs, key=lambda n: indexed.get(n, {}).get('completed_at') or '')
        return chain(latest) + [name]

    for name, job in indexed.items():
        needs = dependencies(name)
        ends = [timestamp(indexed.get(dep, {}).get('completed_at')) for dep in needs]
        ready = max(ends) if ends and all(ends) else (None if needs else created)
        start, end = timestamp(job.get('started_at')), timestamp(job.get('completed_at'))
        # Queued jobs can expose a placeholder started_at before dispatch.
        if job.get('status') not in ('in_progress', 'completed'):
            start = None
        measured[name] = dict(conclusion=job.get('conclusion'),
                              queue_seconds=seconds(ready, start),
                              dependency_wait_seconds=seconds(created, ready),
                              execution_seconds=seconds(start, end))
        measured[name].update(details(job, logs.get(name, ''),
                                      lambda a, b: seconds(timestamp(a), timestamp(b))))
    def ancestors(name, visiting=()):
        if name in visiting:
            raise ValueError('Cyclic workflow dependency')
        result = {name}
        for dep in dependencies(name):
            result.update(ancestors(dep, (*visiting, name)))
        return result

    scope = set().union(*(ancestors(name) for name in REQUIRED))
    complete = all(name in indexed
                   and indexed[name].get('status') == 'completed'
                   and measured[name]['execution_seconds'] is not None
                   and measured[name]['queue_seconds'] is not None
                   for name in scope)
    qualified = (complete and run.get('status') == 'completed'
                 and run.get('conclusion') == 'success'
                 and all(indexed[name].get('conclusion') == 'success' for name in scope))
    classification = (run.get('conclusion') if run.get('status') == 'completed'
                      and run.get('conclusion') in ('failure', 'cancelled')
                      else ('success' if qualified else 'incomplete'))
    finish = max((indexed.get(n, {}).get('completed_at') or '' for n in REQUIRED))
    last = max(REQUIRED, key=lambda n: indexed.get(n, {}).get('completed_at') or '')
    durations = [j['execution_seconds'] for name, j in measured.items()
                 if indexed[name].get('conclusion') != 'skipped']
    required_durations = [measured[n]['execution_seconds'] for n in scope if n in measured]
    wait = seconds(created, timestamp(finish)) if complete else None
    return dict(run_id=run['id'], run_attempt=run.get('run_attempt'),
                source_revision=run.get('head_sha'), event=run.get('event'),
                url=run.get('html_url'), required_conclusions={n: indexed.get(n, {}).get('conclusion') for n in REQUIRED},
                qualified=qualified, classification=classification,
                required_wait_seconds=wait,
                successful_required_wait_seconds=wait if qualified else None,
                runner_minutes=sum(durations) / 60 if all(d is not None for d in durations) else None,
                required_runner_minutes=sum(required_durations) / 60 if complete else None,
                completion_chain=chain(last) if complete else None, jobs=measured)


def summary(report):
    def show(value):
        return 'unavailable' if value is None else str(round(value, 2))

    lines = [f"## CI timing: run {report['run_id']} (attempt {report['run_attempt']})",
             f"Classification: **{report['classification']}**; event: `{report['event']}`; "
             f"source revision: `{report['source_revision']}`.",
             f"Required conclusions: `{json.dumps(report['required_conclusions'], sort_keys=True)}`.",
             f"Required-check wait: {show(report['required_wait_seconds'])} seconds; "
             f"successful wait: {show(report['successful_required_wait_seconds'])} seconds.",
             f"Runner minutes (all jobs, unweighted execution, not billed minutes): {show(report['runner_minutes'])}.",
             'Completion chain: ' + (' → '.join(report['completion_chain']) if report['completion_chain'] else 'unavailable'),
             '', '| Job | Dependency wait s | Queue after dependencies s | Execution s | Conclusion |',
             '| --- | ---: | ---: | ---: | --- |']
    for name, job in report['jobs'].items():
        lines.append(f"| {name} | {show(job['dependency_wait_seconds'])} | {show(job['queue_seconds'])} | "
                     f"{show(job['execution_seconds'])} | {job['conclusion']} |")
    lines.extend(['', '| Job | Build s | Test s | Docs s | Provisioning s | Artifact s | Mixed s | Cache restore s | Cache save s | Cache envelope s |',
                  '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |'])
    for name, job in report['jobs'].items():
        values = [show(job['costs_seconds'][key]) for key in
                  ('build', 'test', 'documentation', 'provisioning', 'artifact', 'mixed_qualification',
                   'cache_restore', 'cache_save', 'cache')]
        lines.append('| ' + name + ' | ' + ' | '.join(values) + ' |')
    lines += ['', 'Costs are step envelopes, not isolated compiler/test CPU time. Ubuntu qualification and iOS test '
              'steps include builds; absent/incomplete categories are unavailable. Job overhead and other steps '
              'remain in raw measurements. Cache envelopes combine composite action work when separate transfer '
              'timestamps are unavailable; do not interpret them as isolated restore/save times. Queue is dispatch latency after the latest dependency completes, '
              'including scheduler overhead. Overlapping jobs are never summed as elapsed wait.',
              'Environment, tested checkout revisions, image versions and missing observations: `measurement.json`; '
              'source evidence: `run.json`, `jobs.json`, `workflow.yml`, `logs.zip`, `artifacts.json`.',
              'Unknown timestamps are unavailable, never zero-duration successes. Logs/artifacts may be unavailable '
              'after retention expiry. Fresh hosted checkout without workflow caches implies cold dependency build '
              'state; it does not imply cold preinstalled compilers or runtimes. See collection warnings.']
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--replay', type=Path, help='Replay a retained evidence directory offline')
    mode.add_argument('--run-id', type=int, help='Collect an Actions run using authenticated gh')
    parser.add_argument('--repo', default='ankitgoyalio/swiftkiteconnect')
    parser.add_argument('--output', type=Path, help='New evidence directory (must not exist)')
    args = parser.parse_args()
    path = args.replay or collect(args.repo, args.run_id, args.output)
    run = json.loads((path / 'run.json').read_text())
    jobs = json.loads((path / 'jobs.json').read_text())['jobs']
    result = measure(run, jobs, workflow_jobs(path / 'workflow.yml'), job_logs(path / 'logs.zip'))
    result['workflow_sha256'] = hashlib.sha256((path / 'workflow.yml').read_bytes()).hexdigest()
    (path / 'summary.md').write_text(summary(result))
    print(path)
    (path / 'measurement.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
