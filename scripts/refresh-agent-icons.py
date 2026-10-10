#!/usr/bin/env python3
"""Refresh pinned vectors from their provenance manifest. Build-time tool: pip install svg.path."""
import hashlib
import json
from pathlib import Path
import re
from urllib.request import urlopen
from svg.path import parse_path

root = Path(__file__).resolve().parents[1]
manifest = root / 'Resources/Icon/AgentIcons.json'
data = json.loads(manifest.read_text())
for icon in data['icons']:
    name = icon['name']
    with urlopen(icon['source'], timeout=30) as response:
        svg = response.read().decode()
    # CoreSVG treats em sizes as 1px and does not parse compressed SVG arc flags reliably.
    svg = svg.replace('height="1em"', 'height="24"').replace('width="1em"', 'width="24"')
    if not name.endswith('-color'):
        svg = svg.replace('currentColor', '#000000')
    svg = re.sub(r' d="([^"]+)"', lambda match: ' d="' + parse_path(match[1]).d() + '"', svg)
    destination = root / 'App/AgentIcons.xcassets' / f'agent-{name}.imageset' / f'{name}.svg'
    destination.write_text(svg)
    icon['sha256'] = hashlib.sha256(svg.encode()).hexdigest()
manifest.write_text(json.dumps(data, indent=2) + '\n')
