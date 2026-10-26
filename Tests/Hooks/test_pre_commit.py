"""Exercise the hook against real Git indexes in disposable repositories."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class StagedTokenLimitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.env = os.environ.copy()
        for name in tuple(self.env):
            if name.startswith("GIT_"):
                del self.env[name]
        self.git("init", "--quiet")
        self.git("config", "user.name", "Hook Test")
        self.git("config", "user.email", "hook@example.invalid")
        hooks = self.repo / ".githooks"
        hooks.mkdir()
        shutil.copy2(ROOT / ".githooks/pre-commit", hooks / "pre-commit")
        shutil.copy2(ROOT / ".gitattributes", self.repo / ".gitattributes")
        self.git("config", "core.hooksPath", ".githooks")
        self.git("add", ".gitattributes")

    def git(self, *args):
        return subprocess.run(
            ["git", *args], cwd=self.repo, env=self.env,
            capture_output=True, check=True,
        )

    def stage(self, name, content):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        self.git("add", "--", name)

    def check_hook(self, succeeds):
        result = subprocess.run(
            [str(self.repo / ".githooks/pre-commit")],
            cwd=self.repo, env=self.env, capture_output=True,
        )
        self.assertEqual(result.returncode, 0 if succeeds else 1, result.stderr)
        return result.stderr.decode()

    def test_exact_limit_passes_but_one_more_byte_blocks(self):
        self.stage("source.swift", b"x" * 20_000)
        self.check_hook(True)
        self.stage("source.swift", b"x" * 20_001)
        error = self.check_hook(False)
        self.assertIn("5,000.25 tokens", error)
        self.assertIn("Group code by responsibility", error)
        self.assertIn("Stage the revised original", error)

    def test_counts_bytes_instead_of_unicode_characters(self):
        self.stage("unicode.md", ("é" * 10_001).encode())
        self.assertIn("20,002 bytes", self.check_hook(False))

    def test_large_unstaged_content_does_not_block_small_staged_blob(self):
        self.stage("source.swift", b"small")
        (self.repo / "source.swift").write_bytes(b"x" * 25_000)
        (self.repo / "untracked.md").write_bytes(b"x" * 25_000)
        self.check_hook(True)

    def test_small_working_copy_cannot_hide_large_staged_blob(self):
        self.stage("source.swift", b"x" * 25_000)
        (self.repo / "source.swift").write_bytes(b"small")
        self.check_hook(False)

    def test_lockfiles_codegen_and_vendor_are_exempt(self):
        for name in (
            "Package.resolved", "nested/Package.resolved", "skills-lock.json",
            "yarn.lock", "pnpm-lock.yaml", "package-lock.json",
            "Sources/Generated/API.swift", "generated/API.swift",
            "API.generated.swift", "API.g.swift", "Vendor/SDK.swift",
        ):
            self.stage(name, b"x" * 25_000)
        self.check_hook(True)

    def test_exemptions_use_staged_attributes(self):
        attributes = self.repo / ".gitattributes"
        self.stage("API.swift", b"x" * 25_000)
        attributes.write_text("API.swift linguist-generated=true\n")
        self.check_hook(False)
        self.git("add", ".gitattributes")
        attributes.write_text("")
        self.check_hook(True)

    def test_multiple_violations_and_unusual_filenames(self):
        names = ["space name.swift", "line\nbreak.swift", "déjà.swift"]
        for name in names:
            self.stage(name, b"x" * 20_001)
        error = self.check_hook(False)
        for name in names:
            self.assertIn(repr(name), error)

    def test_rename_to_authored_path_checks_the_blob(self):
        self.stage("API.generated.swift", b"x" * 25_000)
        self.git("commit", "--quiet", "-m", "Generated baseline")
        self.git("mv", "API.generated.swift", "API.swift")
        self.check_hook(False)

    def test_unchanged_large_files_and_deletions_are_ignored(self):
        self.stage("large.md", b"x" * 25_000)
        self.git("-c", "core.hooksPath=/dev/null", "commit", "--quiet", "-m", "Baseline")
        self.stage("small.md", b"small")
        self.check_hook(True)
        self.git("rm", "large.md")
        self.check_hook(True)

    def test_symlinks_are_ignored(self):
        (self.repo / "link").symlink_to("missing-target")
        self.git("add", "link")
        self.check_hook(True)

    def test_actual_commit_is_blocked_without_changing_the_index(self):
        self.stage("source.swift", b"x" * 20_001)
        before = self.git("write-tree").stdout
        result = subprocess.run(
            ["git", "commit", "-m", "Should fail"],
            cwd=self.repo, env=self.env, capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"Commit blocked", result.stderr)
        self.assertEqual(self.git("write-tree").stdout, before)


if __name__ == "__main__":
    unittest.main()
