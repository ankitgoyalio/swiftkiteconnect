"""Validate ordinary Markdown anchors against working copies and staged blobs."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class DocumentationLinks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'Scripts').mkdir()
        shutil.copy(ROOT / 'Scripts/check-documentation.py', self.root / 'Scripts')
        self.git('init', '--quiet')

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, check=True,
                              capture_output=True, text=True)

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')

    def check(self, *args):
        return subprocess.run(['python3', 'Scripts/check-documentation.py', *args],
                              cwd=self.root, capture_output=True, text=True)

    def test_cross_file_and_same_page_fragments(self):
        self.write('README.md', '# Home\n[home](#home)\n[checks](docs/development.md#run-checks)\n')
        self.write('docs/development.md', '## Run checks\n')
        self.git('add', '.')
        self.assertEqual(self.check().returncode, 0)
        self.write('README.md', '[missing](#missing)\n[old](docs/development.md#old-checks)\n')
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('broken local fragment #missing', result.stderr)
        self.assertIn('broken local fragment docs/development.md#old-checks', result.stderr)

    def test_staged_mode_reads_both_source_and_target_from_index(self):
        self.write('README.md', '[checks](docs/development.md#staged-heading)\n')
        self.write('docs/development.md', '# Staged heading\n')
        self.git('add', '.')
        self.write('README.md', '[checks](docs/development.md#working-heading)\n')
        self.write('docs/development.md', '# Working heading\n')
        self.assertEqual(self.check('--staged').returncode, 0)
        self.assertEqual(self.check().returncode, 0)
        self.write('docs/development.md', '# Other heading\n')
        self.assertNotEqual(self.check().returncode, 0)
        self.assertEqual(self.check('--staged').returncode, 0)
        self.git('add', 'docs/development.md')
        self.assertNotEqual(self.check('--staged').returncode, 0)

    def test_duplicate_headings_inline_markup_and_percent_encoding(self):
        self.write('README.md', '''# **Run** _`checks`_ &amp; [tests](https://example.test)
# Run checks & tests
# Run checks & tests-1
# Run checks & tests
Café operations
---------------
<a id="custom-id"></a>
<a name="legacy"></a>
[one](#run-checks--tests)
[two](#run-checks--tests-1)
[collision](#run-checks--tests-1-1)
[three](#run-checks--tests-2)
[unicode](#caf%C3%A9-operations)
[custom](#custom%2Did)
[legacy](#legacy)
[encoded path](Tests/Guide%20%28example%29.md#section)
[balanced path](Tests/Guide%20(example).md#section)
[file](<docs/adr/0001-link-target.md#section> "A title")
''')
        self.write('docs/adr/0001-link-target.md', '# Section\n')
        self.write('Tests/Guide (example).md', '# Section\n')
        self.git('add', '.')
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_fenced_links_and_headings_are_ignored(self):
        self.write('README.md', '''# Visible
````markdown
# Hidden
[bad](missing.md#missing)
```
[also bad](#missing)
````
~~~
# Other hidden
[bad](missing.md)
~~~
[good](#visible)
''')
        self.git('add', '.')
        self.assertEqual(self.check().returncode, 0)
        self.write('README.md', (self.root / 'README.md').read_text() + '[bad](#hidden)\n')
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('broken local fragment #hidden', result.stderr)
        self.assertNotIn('broken local link missing.md', result.stderr)

    def test_docc_and_source_fragments_keep_path_checks(self):
        self.write('README.md', '''[symbol](Sources/Library.docc/Article.md#Some-Symbol)
[source](Sources/Library.swift#L12)
[external](https://example.test/#missing)
''')
        self.write('Sources/Library.docc/Article.md', '[symbol](#Renderer-Specific-Anchor)\n')
        self.write('Sources/Library.swift', '// source\n')
        self.git('add', '.')
        self.assertEqual(self.check().returncode, 0)
        self.git('rm', '--force', 'Sources/Library.docc/Article.md')
        result = self.check()
        self.assertIn('broken local link Sources/Library.docc/Article.md#Some-Symbol', result.stderr)

    def test_missing_files_and_retired_references_still_fail(self):
        self.write('README.md', '[missing](docs/missing.md#heading)\n')
        self.write('Documentation/Coverage.md', 'See Usage for examples.\n')
        self.git('add', '.')
        result = self.check()
        self.assertIn('broken local link docs/missing.md#heading', result.stderr)
        self.assertIn('retired guide reference', result.stderr)


if __name__ == '__main__':
    unittest.main()
