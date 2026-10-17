# Sub-Store — 订阅管理(容器)

podman 容器运行, 数据在 `/var/lib/sub-store`。
- **访问**: `http://10.10.10.1:3001/<backendPath>/api/utils/env`
- **作用**: 上游节点管理; dae 启动时从这里拉订阅(`?target=V2Ray`)作为节点池

## 常用环境变量(容器内, 对应 docker run -e)
| 变量 | 说明 |
|---|---|
| `SUB_STORE_FRONTEND_BACKEND_PATH` | 后端前缀路径, 拼在 URL 里防扫 |
| `SUB_STORE_BACKEND_SYNC_CRON` | 定时同步订阅/文件到私有 Gist |
| `SUB_STORE_BACKEND_UPLOAD_CRON` / `DOWNLOAD_CRON` | 全量备份 / 恢复到 Gist |
| `SUB_STORE_BACKEND_DEFAULT_PROXY` | 让 Sub-Store 走代理抓订阅(默认不走) |
| `SUB_STORE_PUSH_SERVICE` | Bark / PushPlus / Telegram 推送 key |
| `SUB_STORE_MAX_HEADER_SIZE` | 响应头过大报 Headers Overflow 时调大 |
| `SUB_STORE_BODY_JSON_LIMIT` | 自定义 JSON body 限制(默认 1mb) |