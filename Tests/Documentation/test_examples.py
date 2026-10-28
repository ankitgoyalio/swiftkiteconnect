"""Exercise authored examples through the contributor command."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Examples(unittest.TestCase):
    def test_docc_and_native_tutorial_code_compile_from_authored_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in ('Scripts', 'Documentation', 'Tests/KiteConnectTests',
                           'Sources/KiteConnect/KiteConnect.docc/Resources'):
                (root / folder).mkdir(parents=True)
            shutil.copy(ROOT / 'Scripts/check-documentation-examples.py', root / 'Scripts')
            (root / 'README.md').write_text('')
            (root / 'Documentation/Usage.md').write_text('')
            catalog = root / 'Sources/KiteConnect/KiteConnect.docc'
            (root / 'Sources/KiteConnect/Helper.swift').write_text(
                '/// ```swift\n/// func symbolExample() {}\n/// ```\npublic struct Helper {}\n')
            (catalog / 'Configure.md').write_text('```swift\nfunc articleExample() {}\n```\n')
            (catalog / 'Start.tutorial').write_text('@Code(name: "Start.swift", file: "Start.swift")')
            resource = catalog / 'Resources/Start.swift'
            resource.write_text('func tutorialExample() {}\n')
            command = ['python3', str(root / 'Scripts/check-documentation-examples.py')]
            subprocess.run(command + ['--write'], check=True, capture_output=True)
            generated = (root / 'Tests/KiteConnectTests/DocumentationExamples.swift').read_text()
            self.assertIn('func articleExample() {}', generated)
            self.assertIn('func tutorialExample() {}', generated)
            self.assertIn('func symbolExample() {}', generated)
            subprocess.run(['swiftc', '-typecheck', str(root / 'Tests/KiteConnectTests/DocumentationExamples.swift')],
                           check=True, capture_output=True)
            resource.write_text('func updatedTutorialExample() {}\n')
            stale = subprocess.run(command, capture_output=True)
            self.assertNotEqual(stale.returncode, 0)
            self.assertIn(b'stale', stale.stderr)
