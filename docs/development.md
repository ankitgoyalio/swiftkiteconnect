# Development

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
changes do not require SwiftFormat.

The hook never rewrites files or stages changes, so partial staging is preserved.
To fix a rejection, run `swiftformat <file> --config .swiftformat`, review the
diff, and stage the intended hunks again before committing. Stage configuration
changes along with the source they affect. For a full repository check, run:

```sh
swiftformat . --lint --config .swiftformat
```

The configuration uses Swift 6.4, four-space indentation, and SwiftFormat's
default rules with explicit comma, header, and `self` settings. When upgrading
SwiftFormat, update the version in `.githooks/check_swift_format.py`,
`.swiftformat`, these instructions, and the hook test fixture together; review
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
