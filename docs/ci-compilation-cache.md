# Evaluate minimum macOS compilation caching

Keep `compilation_cache=off` until repeated hosted comparisons establish correctness
and total-time savings. Ordinary pushes and pull requests do not restore compilation
outputs. The pilot affects only `minimum-macos`; runtime provenance, aggregate
checks, and deployment rules remain independent.

1. Dispatch Protocol tests on the experiment branch with `package_cache=warm` and
   `compilation_cache=off` to measure the download-only condition from ticket #58.
   Keep the revision and environment fixed across comparisons.
2. Dispatch `compilation_cache=cold` with the same download mode. This skips
   compilation restore, builds and tests, then validates outputs before cache save.
   Missing or empty products, module cache, planning database, or test bundles fail
   the experiment. Cache save follows both the complete suite and constrained-executor
   regression. Inspect `compilation-cache/outputs.json` for validated paths and bytes.
   This report establishes local output presence only. Confirm an uploaded cache in
   the save action log and Actions cache inventory. A successful step with a path
   validation warning does not establish a save.
3. Dispatch `compilation_cache=warm` to measure restore, normal build, both suites,
   and save. A miss builds normally. Record the matched key from the summary.
4. Dispatch `compilation_cache=compare`. This requires a hit and generates a unique
   source marker in the library with a test that checks its value. After the normal
   build and both suites, the runner deletes compilation scratch, rebuilds identical
   source, and repeats both suites. Inspect `compilation-cache/comparison.json` in
   `minimum-macos-test-results`. It requires matching named test outcomes, including
   execution of the source marker test. The candidate SHA and marker hashes identify
   the instrumented source. This adds disposable probe files to the candidate;
   it does not change tracked SDK behavior.
5. Dispatch `compilation_cache=invalid` after a saved run to corrupt the restored
   Swift Build planning database deliberately. Inspect the build logs for one clean retry.
   A second build failure blocks qualification. Tests never receive a retry through
   this recovery path. Change dependencies, compiler, SDK, or build configuration
   separately and confirm a miss before accepting compatibility isolation.
6. Use `Scripts/ci-timing.py` as described in [Compare required-check completion time](development.md#compare-required-check-completion-time). Compare at least three successful
   comparable runs per condition where feasible. Include restore and save costs,
   required-check completion, runner minutes, and cache size from Actions logs.
   `storage-kib.txt` reports `.build/out` size, not compressed cache bytes. Keep comparison
   runs separate because they execute an extra clean build and both suites.
7. Record run links, exact identities, sample sizes, medians, ranges, and unresolved
   acceptance criteria on #59. Keep raw logs and measurements in Actions artifacts.
   Local CLI tests and a newer macOS host cannot establish minimum OS correctness
   or hosted performance benefit. Do not enable the pilot from those results.

The compatibility identity includes OS patch and build, architecture, compiler
versions and target information, Xcode, SDK build and path, manifest and dependency
resolution hashes, workspace path, configuration, and build environment. The cache
contains Swift Build debug products, intermediates including the planning database,
and module cache. `Scripts/ci-compilation-cache.py paths` emits the same explicit
allowlist for restore and save. Swift 6.4 defaults to Swift Build, so the old native
`.build/*/debug`, `.build/build.db`, and `.build/debug.yaml` paths do not cover this
layout. Download state uses the separate #58 cache. Test logs, result bundles, runtime images, and qualification
conclusions are outside the compilation cache. Every candidate executes its build
and suites after restore.

To roll back, leave `compilation_cache=off`. To remove the experiment, remove its
input, composite action, comparison and save steps, and restore the direct
`swift build --build-tests` command. Keep the existing suite and constrained-executor
steps. Remove saved entries with the `minimum-macos-compilation-v1-` prefix through
Actions cache management if needed. No protection or runtime-transfer change is
part of rollback.
