# 阶段 5：运维

## 推送与升级

```sh
podman build -t 10.10.10.1:3000/cyrene/router-bootc:$(date +%Y.%m.%d) .
podman push 10.10.10.1:3000/cyrene/router-bootc:$(date +%Y.%m.%d)

# 路由器上
sudo bootc upgrade --check      # 看有没有新版本
sudo bootc upgrade              # 暂存，重启生效
sudo bootc status               # 当前/暂存/回滚
sudo bootc rollback             # 回滚到上一部署，重启生效
```

镜像 tag 必须不可变（日期或 git sha）。`bootc-fetch-apply-updates.timer` 默认 4 小时拉一次，本方案已 disable，改为手工升级，避免路由器半夜自动换系统。

## 备份

- `/var/lib/forgejo`：btrfs snapshot + `forgejo dump`
- `/var/lib/sub-store`：Sub-Store 自身有 Gist 同步/上传 cron，已有
- `/etc`：`tar ` 一份到 `/var/backups/etc-$(date +%F).tar.zst`（升级后对照 diff）

## 排障入口

```sh
bootc status
journalctl -u dae -u kea-dhcp4 -u nftables -b
nft list ruleset
dae validate -c /etc/dae/config.dae
ausearch -m avc -ts recent      # SELinux 拒绝
```
