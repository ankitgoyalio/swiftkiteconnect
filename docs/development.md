# Development

## Find the implementation

For endpoint changes, start with the [REST coverage matrix](../Documentation/Coverage.md).
Each row links the implementation, public protocol tests, and compiled example.
For streaming and other non-REST behavior, use the
[capability matrix](../Documentation/CapabilityCoverage.md).

| Responsibility | Entry points |
| --- | --- |
| Client configuration and session ownership | [KiteClient.swift](../Sources/KiteConnect/KiteClient.swift) contains `KiteConfiguration`; [Authentication.swift](../Sources/KiteConnect/Authentication.swift) manages tokens |
| HTTP requests and response handling | [KiteRequest.swift](../Sources/KiteConnect/KiteRequest.swift) and [HTTP.swift](../Sources/KiteConnect/HTTP.swift) |
| Streaming lifecycle and recovery | [KiteTicker.swift](../Sources/KiteConnect/KiteTicker.swift) and [KiteTickerRecovery.swift](../Sources/KiteConnect/KiteTickerRecovery.swift) |
| WebSocket transport | [NIOKiteWebSocketTransport.swift](../Sources/KiteConnect/NIOKiteWebSocketTransport.swift) |
| Portfolio models and operations | [Portfolio.swift](../Sources/KiteConnect/Portfolio.swift) contains `KitePosition`; [PortfolioOperations.swift](../Sources/KiteConnect/PortfolioOperations.swift) contains mutations |
| Controlled test services | [LocalHTTPTests.swift](../Tests/KiteConnectTests/LocalHTTPTests.swift) and [TickerTests.swift](../Tests/KiteConnectTests/TickerTests.swift) |

## Run checks

Use Swift 6.4. On macOS, select full Xcode before running tests. Command Line
Tools alone can fail to load the Swift Testing macro plugin. If needed, set
`DEVELOPER_DIR` for your installed Xcode, for example in Fish:

```fish
set -gx DEVELOPER_DIR /Applications/Xcode.app/Contents/Developer
python3 Scripts/check-development.py
```

The preflight reports the selected compiler, Xcode, and SwiftFormat. It fails
before a build if Swift 6.4, full Xcode on macOS, or the pinned formatter is missing.
Install the formatter as described below before running it.

On macOS, build the test bundle before using the bounded runner:

```fish
xcrun swift build --build-tests
python3 Scripts/test-macos.py
env LIBDISPATCH_COOPERATIVE_POOL_STRICT=1 xcrun swift test --skip-build --filter 'real (local )?HTTP' --maximum-repetitions 10
bash Scripts/test-ios.sh
```

On Ubuntu 24.04, run `bash Scripts/test-ubuntu.sh`. For documentation and hook changes:

```fish
python3 Scripts/check-documentation.py
python3 Scripts/audit-snapshot.py
python3 Scripts/check-documentation-examples.py
python3 -m unittest discover -s Tests/Hooks -p 'test_*.py'
python3 -m unittest discover -s Tests/Documentation -p 'test_*.py'
node --test Tests/Publisher.test.cjs
```

The [DocC guide](../Documentation/DocC.md) covers warning-free builds and example
regeneration. The [CI workflow](../.github/workflows/protocol-tests.yml) defines
required platform checks. Optional remote checks use the
[sandbox guide](../Documentation/SandboxVerification.md). Keep local logs and
result bundles in ignored `.test-results/`.

## Qualify minimum Apple OS versions before release

The package declares macOS 15 and iOS 18. The routine Apple CI job tests newer
runtimes. A successful build with those deployment targets does not establish
runtime compatibility. Before publishing a release, run the same candidate
revision on both minimum OS versions and retain the results with that revision.

1. Prepare a macOS 15 machine or VM and an iOS 18 simulator. Record the exact OS
   patch versions, architecture, Xcode version and Swift version. Use Swift 6.4
   and a full Xcode installation that supports the selected runtime. Check
   [Apple's Xcode compatibility table](https://developer.apple.com/xcode/system-requirements)
   before selecting the environment. Xcode 27.1 requires macOS 26.6 or later,
   so the routine CI Xcode installation cannot run on the macOS 15 host.
2. On the macOS 15 host, run the macOS build, bounded suite and constrained-executor
   commands in [Run checks](#run-checks). A standalone Swift 6.4 toolchain requires
   a compatible SDK and working Swift Testing macros. Verify the compiler and
   execute the suite before accepting that setup. If no compatible setup is
   available, record minimum macOS qualification as blocked. Do not substitute
   results from a newer host or silently lower the package's tools version.
3. On a host with Swift 6.4 and an installed iOS 18 runtime, select that runtime
   explicitly and run the existing iOS test runner. For example, in Fish:

   ```fish
   env IOS_SIMULATOR_RUNTIME=com.apple.CoreSimulator.SimRuntime.iOS-18-0 IOS_SIMULATOR_NAME="iPhone 16" bash Scripts/test-ios.sh
   ```

   Replace the identifiers with the installed iOS 18 runtime and device. The
   runner must fail if that runtime is unavailable. Do not use automatic selection
   for minimum OS qualification, because it can select a newer runtime.
4. Retain the full test summaries, simulator result bundle, compiler and OS
   inventory, and candidate commit SHA in release CI artifacts or ignored
   `.test-results/`. All deterministic tests must pass, including real loopback
   HTTP and WebSocket tests. Record optional remote sandbox skips separately.
5. Add dated evidence and artifact links to
   [Verification](../Documentation/Verification.md). A missing runtime, unavailable
   compatible compiler, test failure or hang blocks minimum OS qualification and
   release publication. Repeat this procedure for each release candidate and
   after changes to networking, concurrency, dependencies or deployment targets.

The required `minimum-apple` job in the protocol workflow passes only when both
`minimum-macos` and `minimum-ios` succeed. The macOS job uses GitHub's `macos-15`
image, Xcode 16.4, and standalone Swift 6.4.0. Xcode 16.4's embedded package
resolver cannot load a tools-version 6.4 manifest, so iOS tests use Xcode 27.1
on `xcode-27`. The macOS job exports the iOS 18.5 runtime for the iOS job to
import and explicitly test with an iPhone 16 simulator. The iOS job removes
preinstalled runtimes from its fresh hosted runner before downloading the older
image to leave room for import and testing.

The jobs fail if the OS, compiler, runtime, build, or tests are unavailable or
incompatible. The `minimum-macos-test-results` and `minimum-ios-test-results`
artifacts retain the candidate SHA, environment inventory, logs, and iOS result
bundle. The intermediate `ios18-runtime` artifact expires after one day. These
checks qualify the macOS 15 and iOS 18 families at the recorded patch versions,
not specifically macOS 15.0 or iOS 18.0.

Before release, require a successful `minimum-apple` run for the candidate and
record its evidence in Verification.md. The newer-runtime `apple` job and the
`ubuntu` job also remain required. Workflow configuration alone does not claim
successful qualification.

## Compare required-check completion time

Use [the timing collector](../Scripts/ci-timing.py) with authenticated `gh`,
Python 3 and Ruby. Collect each completed Protocol tests run into a new directory:

```fish
python3 Scripts/ci-timing.py --run-id 41013409795
python3 Scripts/ci-timing.py --replay .test-results/ci-timing/41013409795-attempt-1
```

The first command prints the evidence directory. The second regenerates
`measurement.json` and `summary.md` from its retained inputs without API access.
Keep the directory in ignored `.test-results/` or an Actions artifact.
Collection uses the run's current attempt and retains paginated job metadata,
logs, artifact metadata and the tested revision's workflow. Check
`collection-warnings.txt` for missing evidence. If checkout logs are unavailable,
the workflow snapshot uses the source revision and the tested revision stays unknown.

After this workflow reaches the default branch, [CI timing](../.github/workflows/ci-timing.yml)
collects each completed Protocol tests run and retains its raw evidence for
30 days. Its Actions summary links the measurements by filename. You can also
run CI timing manually with a Protocol tests run ID. The collector executes
only default-branch code and has read-only permissions. It does not participate
in qualification or Pages publication.

For each comparison:

1. Select at least three successful runs per condition where feasible. Prefer
   the same tested revision, event, workflow hash, runner image, architecture,
   compiler, SDK and runtime. If revisions differ, inspect their changes before
   grouping them. Record the sample size and every mismatch on the tracking issue.
2. Separate failed, cancelled and incomplete runs. Use `classification` and
   `qualified` in `measurement.json`. Missing timestamps cannot establish a
   successful duration. Keep diagnostic evidence without adding it to the baseline.
3. Compare required-check wait from run creation to the last required job's
   completion. Inspect the completion chain and each job's queue after dependencies,
   dependency wait and execution. Do not add overlapping execution times as elapsed time.
4. Compare unweighted runner minutes as a separate cost. `runner_minutes` covers
   all executed jobs, including deployment. `required_runner_minutes` covers
   required jobs and their dependencies. Neither value includes billing multipliers
   or minute rounding. Skipped jobs consume no execution minutes.
5. Inspect step costs and environment observations in the JSON. Build, test,
   documentation, provisioning and artifact costs are step durations. Ubuntu and
   iOS commands combine compilation and tests, so isolated timings are unavailable.
   Empty categories remain unknown. Compiler observations may include installer
   preflight output. Runtime inventory can include imported runtimes.
6. Record cache restore and save costs when comparing later optimizations.
   For the uncached workflow, describe cold dependency state as an inference from
   fresh hosted checkouts and absent workflow caches. Record preinstalled compilers
   and runtimes separately. Do not claim that hosted images contain no other caches.
7. Retain a compact dated summary and Actions links on the implementation issue.
   Include the median, range, runner variation and unavailable measurements.
   Keep raw logs and per-run JSON out of tracked documentation.

## Review dependency updates

[Dependabot configuration](../.github/dependabot.yml) checks SwiftPM packages and
GitHub Actions each Monday at 08:00 Asia/Kolkata. Routine version updates have
two open Swift PR slots and one Actions slot. Dependabot security updates, if
enabled separately in repository settings, have a separate limit.

Networking patch and minor updates are grouped across SwiftNIO, NIOSSL and
WebSocketKit. Swift Crypto updates and all major upgrades remain individual PRs.
Actions patch and minor updates form a separate group. The configuration takes
effect after it reaches the default branch.

Review each update before merging:

1. Read the upstream release notes and inspect `Package.swift` and
   `Package.resolved`, or the changed workflow references for Actions updates.
   Preserve existing `exact:` requirements when updating their versions.
2. For major upgrades, include migration notes and describe any changes to
   compiler requirements, minimum OS versions or public behavior.
3. Require successful `apple` and `ubuntu` checks against the current base.
   Merge manually. The repository ruleset requires both checks and auto-merge
   is disabled.
4. Before release publication, complete the
   [minimum OS qualification](#qualify-minimum-apple-os-versions-before-release)
   for the candidate dependency set.

Keep SwiftFormat and Swift/Xcode upgrades in dedicated maintenance PRs. Update
their pins, validation scripts, CI setup and documentation together. Dependabot's
Actions updater changes action references, not the compiler version or formatter
download embedded in workflow commands.

For a failed update job, inspect **Insights > Dependency graph > Dependabot** on
GitHub. Check the job log for manifest, resolver or toolchain errors, fix the
cause, and retry the update. Do not weaken CI or deployment targets to accept an
update. The [Dependabot options reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference)
describes scheduling, groups and PR limits.

## Set up commit checks

Install SwiftFormat 0.64.3 and enable the repository's pre-commit hook after
cloning (requires Python 3 and Git):

```sh
git config core.hooksPath .githooks
```

On macOS, `brew install swiftformat` installs the current Homebrew release.
Check it with `swiftformat --version`; the hook requires exactly 0.64.3 so
contributors use the same formatting rules. For a specific release, install
with `mint install nicklockwood/SwiftFormat@0.64.3` if you use Mint, or get the
appropriate executable from the [0.64.3 release](https://github.com/nicklockwood/SwiftFormat/releases/tag/0.64.3)
and place it on `PATH`. Linux contributors can build that tag with Swift
Package Manager. This is Nick Lockwood's `swiftformat`, distinct from the
toolchain's `swift format` command.

## Resolve a formatting rejection

The hook first checks file sizes, then lints added or modified staged authored
Swift files using the staged root `.swiftformat`. Renames and type changes to
regular Swift files are checked too. Generated and vendored files use the same
staged attribute exemptions as the size check. Commits without authored Swift
or formatter-policy changes do not require SwiftFormat.

The hook reads staged Swift blobs in one batch and lints a temporary snapshot in
bounded SwiftFormat batches. Git history remains available for header metadata.
The hook never rewrites files or stages changes, so partial staging is preserved.
To fix a rejection, run `swiftformat <file> --config .swiftformat`, review the
diff, and stage the intended hunks again before committing. Stage configuration
changes along with the source they affect.

CI runs this hook against files changed from the pull request base or previous
`main` revision, using the same version, staged attributes, and configuration.
Manual workflow runs compare with the previous commit. CI also lints the full
repository. Generated documentation examples are excluded from formatting because
they must match the authored DocC snippets exactly. To check a branch locally, run
`python3 .githooks/pre-commit --base origin/main`. Changes to `.swiftformat` or
`.gitattributes` expand the formatting check to all authored Swift files.
For a full repository check, run:

```sh
swiftformat . --lint --config .swiftformat
```

The configuration uses Swift 6.4, four-space indentation, and SwiftFormat's
default rules with explicit comma, header, and `self` settings. Test names and
existing force-unwrap/force-try assertions are preserved: renaming breaks the
coverage map, and automatic assertion conversion can produce nested Swift Testing
macros that do not compile. When upgrading
SwiftFormat, update the version in `.githooks/check_swift_format.py`,
`.swiftformat`, the CI installation step, these instructions, and the hook test fixture together; review
any resulting source changes.

Swift source headers use the file name, `swiftkiteconnect`, and
`Created by <Git author name> on DD/MM/YYYY.`. SwiftFormat fills `{file}`,
`{author.name}`, and `{created}` from file and Git metadata, using UTC for
consistent dates. The author is the person who first committed the file;
new files use the configured Git author identity. Existing
creation dates are retained; the template does not stamp every file with
the date formatting runs. SwiftFormat preserves the package manifest's
Swift tools version comment.

## Resolve a file-size rejection

The hook checks only added, modified, renamed, or type-changed staged regular
files. It measures the staged Git blob, including partial staging, and blocks
files larger than 20,000 bytes: 5,000 estimated tokens at bytes / 4. Files exactly
at the limit pass. Deleted files, symlinks, and submodules are not checked.

When blocked, split code by responsibility, documentation by topic, or tests by
behavior. Keep every extracted file and the original at or below 20,000 bytes,
update imports/references or documentation links, and stage all changed files
before retrying. The hook prints these instructions and each offending file's
staged byte and token counts.

## Exclude tool-managed files

Git does not record whether an agent authored a file. Authored files are checked
by default; tool-managed lockfiles, generated output, and vendored sources are
excluded using `linguist-generated=true` or `linguist-vendored=true` patterns in
`.gitattributes`. Add precise patterns for other generated output rather than
exempting authored source. Stage attribute changes with their generated files;
the hook reads attributes from the index too.

## Verify hook changes

Run the hook's integration tests with:

```sh
python3 -m unittest discover -s Tests/Hooks -p 'test_*.py'
```

## Keep documentation durable

Read [the documentation policy](../Documentation/README.md) before adding guides
or evidence. Keep API contracts, reproducible instructions and pinned upstream
sources in Git. Record implementation/review history on GitHub. Save raw logs,
per-run JSON summaries and bundles in ignored `.test-results/` or CI artifacts.
Keep qualification results in `Documentation/Verification.md` rather than repeated
status pages. Never commit credentials, session files or agent execution reports.

The hook runs `Scripts/check-documentation.py --staged` before other checks.
It rejects unregistered project guides at the root, under `docs/`, and under
`Documentation/`, while allowing numbered ADRs and pinned snapshots. It rejects
historical report paths and execution artifacts even when forced into the index
or marked generated. It checks local links using staged paths/content, so
deletions and partial staging are handled together. Ordinary Markdown section
anchors are checked too, including duplicate headings and explicit HTML IDs.
DocC symbol anchors are validated by the DocC build. CI runs the same policy
against tracked working-tree files.
Run `python3 Scripts/check-documentation.py` before submitting documentation changes.
