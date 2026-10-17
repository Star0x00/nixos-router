#!/usr/bin/bash
# dae pulls its node pool from the local Sub-Store. Wait up to 60s for the HTTP
# endpoint, then start anyway so a broken Sub-Store cannot block dae itself.
for _ in $(seq 1 30); do
    if curl -s -m 2 -o /dev/null 'http://127.0.0.1:3001/qwerhyy123/api/utils/env'; then
        exit 0
    fi
    sleep 2
done
echo "Sub-Store not ready within 60s, starting dae anyway" >&2
exit 0
