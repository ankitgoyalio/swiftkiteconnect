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

The command extracts the public symbol graph with SwiftPM, audits completed
coverage slices, and converts the catalog with warnings treated as errors.
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

The extractor retains the README and Usage.md examples during migration. It also
reads DocC articles, tutorial markup, and the referenced Swift tutorial resources.
The generated test source compiles against the public SDK. Existing controlled
HTTP and WebSocket tests supply behavioral evidence without live credentials or
trading requests. Generated examples are not executed against Kite.

## Extend declaration coverage

Review `.build/documentation/public-api-inventory.json` after a site build.
The inventory records each authored public declaration's identifier, path, kind,
comment presence, and inclusion in completed slices. Compiler-synthesized members
are excluded. Add completed slices to [DocCCoverage.json](DocCCoverage.json) using
symbol graph paths. A removed declaration or a missing summary in a completed
slice fails the build. New slices must add their declarations before completion.

Slice #31 covers `KiteConfiguration`, its public members, `KiteClient`, its two
initializers, and its public configuration and API key. Endpoint methods and other
models remain for later slices. Slice #38 migrates Publisher browser guidance and
its offline examples. Its declaration list is empty because Publisher has no
Swift API. The linked authentication and order declarations belong to their
respective slices. Review descriptions for useful behavior,
parameters, errors, and constraints. A comment-length check cannot judge meaning.

For final delivery, require every declaration to have documentation:

```fish
python3 Scripts/check-documentation-coverage.py .build/documentation/symbols --require-complete
```

The foundation's slice policy does not waive the complete-coverage requirement
in ADR-0013. CI uploads generated output as an artifact and never publishes it.
Keep canonical authored sources in Git. Do not commit `.doccarchive` output.

Large completed slices can use a separate JSON file under `Documentation/DocCCoverage/`
with the same `completedSlices` object. The coverage audit loads these files together
with `DocCCoverage.json` and rejects duplicate slice names. Register each new file
in `Scripts/check-documentation.py`. Keep each authored file below 20,000 bytes.
The [orders, GTT, and alerts slice](DocCCoverage/34-orders-gtt-and-alerts.json)
uses this layout to preserve every explicit declaration target.
