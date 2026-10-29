# Documentation

- [DocC build](DocC.md): canonical catalog, static artifact, and complete symbol coverage.
- [Pages publication](Pages.md): dedicated domain setup, deployment, and live verification.
- [Usage](Usage.md): pointer to canonical DocC task guides.
- [Contracts](Contracts.md): pointer to canonical DocC contracts.
- [Publisher](Publisher.md): application-owned browser integration.
- [Coverage](Coverage.md) and [capability coverage](CapabilityCoverage.md): pinned scope.
- [Official SDK parity](SDKParity.md): pinned wrappers, differences, and independent fixtures.
- [Verification](Verification.md): current evidence and remaining qualification.
- [Sandbox verification](SandboxVerification.md): optional external checks.
- [Snapshot manifest](Snapshots/2026-10-27/manifest.json): exact upstream provenance.

Keep consumer guidance, durable contracts, reproducible instructions and selected
upstream snapshots in Git. Record implementation history and review discussion on
the corresponding GitHub issue or PR. Keep current qualification status in
Verification.md rather than repeating it across ticket reports.

Raw test/build logs, per-run summaries, result bundles, screenshots, credentials
and temporary agent reports belong outside source control. Use ignored
`.test-results/` for local execution output and CI artifacts for hosted runs.
Snapshots are the intentional exception: their exact bytes, manifest and generated
inventory make the coverage audit reproducible without a live website.

The pre-commit hook and CI enforce the documentation layout, reject historical
report paths and execution-output formats, and check local Markdown links.
Register intentional new guides in `Scripts/check-documentation.py` after checking
for an existing home for the topic. When moving a guide, update its callers and
links in the same change. New Swift examples belong in the DocC catalog. The compiled-example drift check
covers every catalog article and native tutorial resource. The README and retained
guide pointers contain no separate canonical examples.
