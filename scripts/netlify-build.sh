#!/bin/bash

set -e

FLUTTER_VERSION="3.35.5"

git clone https://github.com/flutter/flutter.git --depth 1 --branch "$FLUTTER_VERSION" "$HOME/flutter"

export PATH="$HOME/flutter/bin:$PATH"

flutter --version
flutter config --enable-web

flutter pub get
flutter build web --release

SITE_URL="${URL:-${DEPLOY_PRIME_URL:-}}"
SITE_URL="${SITE_URL%/}"
if [ -n "$SITE_URL" ]; then
  python3 - "$SITE_URL" <<'PY'
from pathlib import Path
import sys

site = sys.argv[1]
path = Path("build/web/index.html")
html = path.read_text()
html = html.replace('content="/og-image.png"', f'content="{site}/og-image.png"')
path.write_text(html)
PY
fi