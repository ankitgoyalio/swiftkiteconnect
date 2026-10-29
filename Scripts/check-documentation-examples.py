#!/usr/bin/env python3
"""Compile the same Swift examples readers see in Markdown, DocC, and tutorials."""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
catalog = root / 'Sources/KiteConnect/KiteConnect.docc'
documents = [root / 'README.md']
documents += sorted(catalog.rglob('*.md')) + sorted(catalog.rglob('*.tutorial'))
blocks = []
resources = set()
for document in documents:
    text = document.read_text()
    blocks += re.findall(r'```swift\n(.*?)\n```', text, re.S)
    for name in re.findall(r'@Code\([^)]*\bfile:\s*"([^"]+\.swift)"', text):
        matches = list((catalog / 'Resources').rglob(name))
        if len(matches) != 1:
            sys.exit(f'{document}: expected one tutorial resource named {name}')
        resources.add(matches[0])
# Declaration comments render executable examples too. Extract only contiguous
# triple-slash comments, never executable implementation code or ordinary comments.
for source in sorted((root / 'Sources/KiteConnect').glob('*.swift')):
    for comment in re.findall(r'(?:^[ \t]*///[^\n]*\n)+', source.read_text(), re.M):
        text = re.sub(r'^[ \t]*/// ?', '', comment, flags=re.M)
        blocks += re.findall(r'```swift\n(.*?)\n```', text, re.S)
# Every Swift resource is compiled, including incremental tutorial steps. Use a
# distinct enclosing type or function in each step when names overlap.
for resource in sorted((catalog / 'Resources').rglob('*.swift')):
    if resource not in resources:
        sys.exit(f'{resource}: Swift tutorial resource is not referenced by @Code')
    blocks.append(resource.read_text().strip())
imports = sorted({line for block in blocks for line in block.splitlines() if line.startswith('import ')})
bodies = ['\n'.join(line for line in block.splitlines() if not line.startswith('import ')).strip() for block in blocks]
expected = '// Generated from Markdown, KiteConnect.docc, and tutorial resources; run python3 Scripts/check-documentation-examples.py --write.\n' + '\n'.join(imports) + '\n\n' + '\n\n'.join(bodies) + '\n'
target = root / 'Tests/KiteConnectTests/DocumentationExamples.swift'
if '--write' in sys.argv:
    target.write_text(expected)
if not target.exists() or target.read_text() != expected:
    sys.exit('Documentation examples are stale; regenerate with --write and run swift test.')
print(f'Verified {len(blocks)} Swift documentation examples match compiled test sources.')
