#!/usr/bin/bash
# dae keeps geoip/geosite assets in a writable location because it may update
# them at runtime. The image ships them under /usr (read-only), so seed them
# into /var/lib/dae/assets on first start.
set -euo pipefail
dst=/var/lib/dae/assets
mkdir -p "$dst"
for src in /usr/share/dae /usr/lib/dae /usr/share/daeuniverse; do
    [ -d "$src" ] || continue
    cp -an "$src"/. "$dst"/ 2>/dev/null || true
done
exit 0
