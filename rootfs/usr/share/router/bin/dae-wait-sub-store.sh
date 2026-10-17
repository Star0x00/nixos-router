#!/usr/bin/bash
# dae 启动时才去 Sub-Store 拉订阅；等它的 HTTP 端口就绪（最多 60s），
# 超时也照常启动，免得 Sub-Store 挂了连 dae 都起不来。
for _ in $(seq 1 30); do
    if curl -s -m 2 -o /dev/null 'http://127.0.0.1:3001/qwerhyy123/api/utils/env'; then
        exit 0
    fi
    sleep 2
done
echo "Sub-Store 未在 60s 内就绪, 仍然启动 dae" >&2
exit 0
