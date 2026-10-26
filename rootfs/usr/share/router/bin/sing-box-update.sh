#!/usr/bin/bash
# Build /etc/sing-box/config.json from the Sub-Store subscription.
#
# Restored from the NixOS setup (services/deprecated/sing-box.nix +
# assets/gen-singbox-base.mjs): download the subscription, regenerate the node
# group from it, validate, and only then replace the live config.
#
# Everything is downloaded/generated into /run first, so a Sub-Store that is
# not up yet (or a broken subscription) cannot truncate the working config.
set -euo pipefail

dir=/etc/sing-box
template=/usr/share/router/singbox/base.json
gen=/usr/share/router/lib/gen-singbox-base.mjs
url='http://127.0.0.1:3001/qwerhyy123/download/collection/singbox?target=sing-box'

node_json=/run/sing-box-node.json
config_new=/run/sing-box-config.json
rm -f "$node_json" "$config_new"

curl -sS -f -m 60 --retry 3 --retry-delay 5 -o "$node_json" "$url"
node "$gen" "$node_json" "$template" "$config_new"
/usr/bin/sing-box check -c "$config_new"

install -d -m 0750 -o root -g sing-box "$dir"

# Nothing changed: keep the running process and its connections.
if cmp -s "$config_new" "$dir/config.json"; then
    exit 0
fi

install -m 0640 -o root -g sing-box "$node_json" "$dir/node.json"
install -m 0640 -o root -g sing-box "$config_new" "$dir/config.json"

# --no-block: this unit is ordered before sing-box.service, so waiting for the
# restart job would deadlock at boot.
systemctl --no-block try-restart sing-box.service || true
