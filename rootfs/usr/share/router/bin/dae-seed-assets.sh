#!/usr/bin/bash
# dae 的 geoip/geosite 资源在只读的 /usr 里；运行时需要可写目录
# （dae 会尝试自动更新资源）。首次启动时把它们种子到 /var/lib/dae/assets。
set -euo pipefail
dst=/var/lib/dae/assets
mkdir -p "$dst"
for src in /usr/share/dae /usr/lib/dae /usr/share/daeuniverse; do
    [ -d "$src" ] || continue
    cp -an "$src"/. "$dst"/ 2>/dev/null || true
done
exit 0
