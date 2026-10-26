# Development

## Set up commit checks

Install the repository's pre-commit hook after cloning (requires Python 3):

```sh
git config core.hooksPath .githooks
```

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
