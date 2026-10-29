"""Exercise development preflight with controlled tool executables."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class DevelopmentPreflight(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.bin = Path(self.directory.name)
        self.env = dict(os.environ, PATH=str(self.bin))
        self.tool("swift", "echo 'Swift version 6.4.0'")
        self.tool("swiftformat", "echo 0.64.3")
        self.tool("xcodebuild", "echo 'Xcode 27.1'")
        self.tool("xcrun", "if [ \"$1\" = '--find' ]; then echo /Applications/Xcode.app/Contents/Developer/usr/bin/swift; else echo 'Swift version 6.4.0'; fi")

    def tool(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + body + "\n")
        path.chmod(0o755)

    def check(self):
        return subprocess.run([sys.executable, str(ROOT / "Scripts/check-development.py")],
                              env=self.env, capture_output=True, text=True)

    def test_compatible_tools_pass(self):
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SwiftFormat: 0.64.3", result.stdout)

    def test_missing_formatter_fails_with_setup_pointer(self):
        (self.bin / "swiftformat").unlink()
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("docs/development.md", result.stderr)

    def test_wrong_compiler_and_formatter_fail(self):
        self.tool("swift", "echo 'Swift version 6.3.0'")
        self.tool("xcrun", "if [ \"$1\" = '--find' ]; then echo /Applications/Xcode.app/Contents/Developer/usr/bin/swift; else echo 'Swift version 6.3.0'; fi")
        self.tool("swiftformat", "echo 0.64.4")
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Required Swift unavailable", result.stderr)
        self.assertIn("Required SwiftFormat unavailable", result.stderr)

    @unittest.skipUnless(sys.platform == "darwin", "Xcode selection is macOS-specific")
    def test_command_line_tools_selection_fails(self):
        self.tool("xcrun", "if [ \"$1\" = '--find' ]; then echo /Library/Developer/CommandLineTools/usr/bin/swift; else echo 'Swift version 6.4.0'; fi")
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Required Selected Swift unavailable", result.stderr)
