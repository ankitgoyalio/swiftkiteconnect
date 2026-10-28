#!/usr/bin/env python3
"""Inventory public declarations and require documentation for completed slices."""
import argparse
import json
from pathlib import Path
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('symbol_graphs', type=Path)
parser.add_argument('--require-complete', action='store_true', help='Require documentation for every declaration at final delivery')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
policy = json.loads((root / 'Documentation/DocCCoverage.json').read_text())
symbols = {}
for graph in args.symbol_graphs.glob('KiteConnect*.symbols.json'):
    for symbol in json.loads(graph.read_text())['symbols']:
        # Synthesized conformances are compiler output, not authored declarations.
        if 'location' in symbol and '::SYNTHESIZED::' not in symbol['identifier']['precise']:
            symbols[symbol['identifier']['precise']] = symbol
if not symbols:
    sys.exit('No public declarations found.')
required = set()
errors = []
for name, paths in policy['completedSlices'].items():
    for path in paths:
        matches = {key for key, symbol in symbols.items() if '/'.join(symbol['pathComponents']) == path}
        if not matches:
            errors.append(f'{name}: declared coverage target is missing: {path}')
        required.update(matches)
if args.require_complete:
    required = set(symbols)
inventory = []
for key, symbol in sorted(symbols.items(), key=lambda pair: pair[1]['pathComponents']):
    text = '\n'.join(line['text'] for line in symbol.get('docComment', {}).get('lines', []))
    # A nonempty summary is necessary, but semantic review remains required.
    documented = len(text.strip()) >= 40
    path = '/'.join(symbol['pathComponents'])
    inventory.append({'id': key, 'path': path, 'kind': symbol['kind']['identifier'],
                      'documented': documented, 'required': key in required})
    if key in required and not documented:
        errors.append(f'{path}: missing meaningful documentation in a completed slice')
output = root / '.build/documentation/public-api-inventory.json'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(inventory, indent=2) + '\n')
print(f'Public API inventory: {len(inventory)} declarations; {len(required)} required by completed slices; '
      f'{sum(item["documented"] for item in inventory)} have documentation comments.')
if errors:
    sys.exit('\n'.join(errors))
