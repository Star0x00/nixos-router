# Memos — 轻量自托管备忘录/笔记

原生 NixOS 模块部署(单个 Go 二进制), 不用容器; 随 nixos-unstable 升级。

- **访问**: `http://10.10.10.1:5230`, 首次注册的账号即管理员
- **数据**: `/var/lib/memos`(SQLite + 上传资源, 备份拷走即可)
- **私有模式**: `MEMOS_INSTANCE_URL` 留空(默认), 匿名访客一律跳登录页, 不开 Explore/RSS/公开 API
- **收紧注册**: 实例级开关默认放开, 需收紧时在 设置 → 成员/安全 里关
- **只绑 LAN**: 防火墙统一由 `network.nix` 的 nftables 处理