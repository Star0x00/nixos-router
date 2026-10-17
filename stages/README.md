# 阶段计划

每个阶段都能单独构建、单独验证。全部完成前不动生产机。

| 阶段 | 内容 | 产物 | 验证 |
|---|---|---|---|
| 1 | 仓库重整 | `archive/` | `git log --follow` 仍可追溯，NixOS 不再构建 |
| 2 | 骨架镜像 | `FROM fedora-bootc:43` + networkd/nftables/sshd + sysctl/modprobe/udev/initramfs | `bootc container lint`；qemu 起得来、能 DHCP、能 SSH |
| 3 | 服务落地 | kea、dae、sub-store/openlist/memos、forgejo | qemu 里手工验证每个服务；先不写 unit 依赖，跑通再加 |
| 4 | 安装与数据 | btrfs 根、`bootc install`、`/var/lib` 迁移 | 第二块盘装机，切启动项 |
| 5 | 运维 | registry 推送、upgrade/rollback、备份 | 出一次滚动升级 + 回滚演练 |
