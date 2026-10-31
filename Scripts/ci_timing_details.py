"""Step costs and environment observations from retained Actions job logs."""
import re
import zipfile


CATEGORIES = ('build', 'test', 'documentation', 'provisioning', 'artifact',
              'mixed_qualification', 'cache_restore', 'cache_save', 'cache', 'other')


def category(name):
    name = name.lower()
    if 'cache/restore@' in name or ('restore' in name and
            any(word in name for word in ('cache', 'compilation', 'package downloads'))):
        return 'cache_restore'
    if 'cache/save@' in name or ('save' in name and
            any(word in name for word in ('cache', 'compilation', 'package downloads'))):
        return 'cache_save'
    if any(word in name for word in ('actions/package-downloads', 'actions/compilation-cache')):
        return 'cache'
    if any(word in name for word in ('upload-artifact', 'download-artifact', 'pages artifact')):
        return 'artifact'
    if any(word in name for word in ('runtime', 'free space', 'setup-swift', 'toolchain',
                                     'preinstalled', 'install pinned', 'signing keys')):
        return 'provisioning'
    if any(word in name for word in ('documentation', 'docc', 'publisher')):
        return 'documentation'
    if 'ubuntu qualification' in name or (name.startswith('ios ') and 'tests' in name):
        return 'mixed_qualification'
    if 'build' in name:
        return 'build'
    if any(word in name for word in ('tests', 'regression', 'sandbox')):
        return 'test'
    return 'other'


def job_logs(path):
    if not path.exists():
        return {}
    with zipfile.ZipFile(path) as archive:
        return {re.sub(r'^\d+_', '', name)[:-4]: archive.read(name).decode('utf-8-sig')
                for name in archive.namelist() if re.match(r'^\d+_.*\.txt$', name)}


def environment(log):
    clean = re.sub(r'\x1b\[[0-9;]*m', '', log)
    clean = re.sub(r'^\S+Z ', '', clean, flags=re.MULTILINE)

    def matches(pattern):
        return sorted(set(re.findall(pattern, clean, flags=re.MULTILINE))) or None

    def first(pattern):
        values = re.findall(pattern, clean, flags=re.MULTILINE)
        return values[0] if values else None

    image = re.search(r'##\[group\]Runner Image\nImage: ([^\n]+)\nVersion: ([^\n]+)', clean)
    compiler = matches(r'^((?:Apple )?Swift version [^\n]+)$')
    # Compiler output may include a swift-driver prefix on newer Xcode.
    compiler = compiler or matches(r'^swift-driver version: .*? (Apple Swift version [^\n]+)$')
    return dict(
        runner_image=' '.join(image.groups()) if image else None,
        architecture=first(r'^Target: ([^-\n]+)-'),
        compiler=compiler,
        xcode=matches(r'^Xcode [\d.]+$'),
        os=matches(r'^ProductVersion:\s+([^\n]+)$') or matches(r'^PRETTY_NAME="([^"]+)"$'),
        sdk=matches(r'/SDKs/([^/\s"\x1b]+\.sdk)'),
        runtime=matches(r'^\s*IOS_SIMULATOR_RUNTIME: (\S+)') or
                matches(r'^(iOS [^\n]+com\.apple\.CoreSimulator\.SimRuntime\S*)'),
        tested_revision=first(r'^\[command\].*git log -1 --format=%H\n([0-9a-f]{40})$'),
        runtime_inventory=matches(r'^(iOS [^\n]+com\.apple\.CoreSimulator\.SimRuntime\S*)'),
        evidence='logs.zip; observed compiler lines can include installer preflight and selected compiler',
    )


def details(job, log, duration):
    costs = {name: [] for name in CATEGORIES}
    steps = []
    for step in job.get('steps', []):
        bucket = category(step['name'])
        value = duration(step.get('started_at'), step.get('completed_at'))
        # Skipped steps are absent work, not timed zero-duration successes.
        if step.get('conclusion') == 'skipped':
            value = None
        else:
            costs[bucket].append(value)
        steps.append(dict(name=step['name'], category=bucket, seconds=value,
                          conclusion=step.get('conclusion')))
    totals = {name: (sum(values) if values and all(v is not None for v in values) else None)
              for name, values in costs.items()}
    env = environment(log)
    setup = [s for s in job.get('steps', []) if 'setup-swift@' in s['name']]
    env['compiler_setup'] = ('installed by setup-swift' if any(s.get('conclusion') == 'success' for s in setup)
                             else ('preinstalled (setup-swift skipped)' if setup and
                                   all(s.get('conclusion') == 'skipped' for s in setup)
                                   else 'no setup-swift step; see compiler observation'))
    return dict(costs_seconds=totals, steps=steps, environment=env,
                runner_labels=job.get('labels'), runner_name=job.get('runner_name'),
                unavailable=[key for key, value in env.items() if value is None])
