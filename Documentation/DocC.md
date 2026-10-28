# Build the DocC site

Use Swift 6.4, Python 3, and the toolchain's DocC compiler. On macOS, select full
Xcode before running the build:

```fish
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 Scripts/build-documentation.py
```

On a toolchain with `swift` and `docc` on `PATH`, run:

```fish
python3 Scripts/build-documentation.py
```

The command extracts the public symbol graph with SwiftPM, requires comments on every authored public declaration, and converts the catalog with warnings treated as errors.
It checks generated direct routes, internal references, renderer assets, and the
navigation/search index. The static artifact is
`.build/documentation/KiteConnect.doccarchive`. The hosting base path is empty
for the planned `kiteconnect.ankitgoyal.io` domain. DNS, HTTPS, and publication
are separate work. This command does not deploy the site.

## Validate examples

Author user-facing DocC sources in
[the catalog](../Sources/KiteConnect/KiteConnect.docc). Keep Swift article
examples in fenced `swift` blocks. Put native tutorial Swift files in the catalog's
`Resources` directory and reference each with `@Code(file: ...)`.
Every Swift resource enters compilation. For incremental tutorial steps, provide
complete compilation context in each resource and use distinct enclosing types
or function names when steps repeat declarations. Imports must be at file scope.

After changing an example, regenerate the compiled source and run the offline
checks:

```fish
python3 Scripts/check-documentation-examples.py --write
python3 Scripts/check-documentation-examples.py
python3 -m unittest discover -s Tests/Documentation -p 'test_*.py'
swift test
node --test Tests/Publisher.test.cjs
```

The extractor reads every DocC article, tutorial markup, and referenced Swift
tutorial resource, as well as any README and Usage pointer-page Swift blocks.
Keep executable snippets in fenced `swift` blocks; do not use an alternate fence
label to bypass compilation. Fenced Swift examples in triple-slash declaration comments also enter extraction.
Use triple-slash comments for executable symbol examples.
The generated test source compiles against the public SDK. Existing controlled
HTTP and WebSocket tests supply behavioral evidence without live credentials or
trading requests. Generated examples are not executed against Kite.

## Review complete declaration coverage

Every routine site build requires documentation on every authored public declaration,
including shared protocols, value helpers, cases, initializers, and members.
The audit excludes compiler-synthesized members and writes
`.build/documentation/public-api-inventory.json`. Its comment-presence check is a
minimum requirement, not a semantic score. No slice can waive complete coverage.

After API or documentation changes, review the generated inventory and the affected
source comments against implementation and fixture-backed protocol tests. Check
behavior, each parameter, return values, errors, cancellation, units, nil versus
zero, unknown values, and request constraints where applicable. Reject summaries
that merely repeat a declaration's name. A generated symbol page and a warning-free
build do not establish useful documentation.

[DocCCoverage.json](DocCCoverage.json) and its separate slice manifests retain the
explicit targets from earlier slices. Removed targets fail even when the remaining
API is documented. All newly added declarations are required automatically; no
manifest update is needed to activate that requirement. `--require-complete` remains
accepted for existing commands, but complete coverage is always enforced.

Keep each authored file below 20,000 bytes. Split a source file only when the size
limit requires it, retain creation metadata, and register any new coverage manifest
in `Scripts/check-documentation.py`.

## Prepare the root-hosted artifact

The build uses DocC's static-hosting transform without a hosting base path. Serve
all archive contents at the domain root. The package landing route is
`/documentation/kiteconnect/`; tutorial routes start at `/tutorials/`. Preserve the
`data`, `index`, `js`, `css`, `images`, and `downloads` directories when present.
Do not add a repository-name prefix. The offline site check verifies generated
page routes, reference targets, tutorial resources, renderer assets, and searchable
navigation targets. Direct routes each contain an `index.html` for reloads.

CI validates pull requests and uploads the archive without publishing. Issue
[#40](https://github.com/ankitgoyalio/swiftkiteconnect/issues/40) owns the Pages
workflow, root landing behavior, DNS, custom domain, HTTPS, and live reload checks.
Before deployment, run the commands above and the existing Apple and Ubuntu
qualification jobs. Do not infer live hosting or authenticated trading qualification
from an offline archive check. Keep generated output and raw logs outside Git.
