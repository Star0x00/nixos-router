# 阶段 3：服务落地

在阶段 2 的镜像上逐个加服务。每加一个跑一次 qemu，失败就回退该段。

## 3.1 Kea DHCP4

- 包：`kea`（Fedora 官方）
- 配置：`/usr/share/router/kea/kea-dhcp4.conf`，unit drop-in 用 `-c` 指向它
- 租约：`/var/lib/kea`（`StateDirectory=kea`）
- 注意：Fedora 的单元名是 `kea-dhcp4.service`，不是 `kea-dhcp4-server.service`

验证：LAN 侧客户端能拿到 10.10.10.2-100 的地址，网关/DNS 都是 10.10.10.1。

## 3.2 dae（eBPF 透明代理）

- 包：Dae Universe RPM（`/etc/yum.repos.d/daeuniverse.repo`）
- 配置：`/etc/dae/config.dae` + `/etc/dae/config.d/*.dae`（权限 0400，dae 会拒绝 group/other 可读写）
- 资源：`DAE_LOCATION_ASSET=/var/lib/dae/assets`，首次启动由 `dae-seed-assets.sh` 从只读 `/usr` 种入
- 依赖：`sub-store.service` + `dae-wait-sub-store.sh`
- 定时刷新：`dae-reload.timer`（6 小时一次，`dae reload` 平滑换节点）

风险点：
- SELinux。dae 需要加载 BPF、挂 `/sys/fs/bpf`；若被拒：
  ```sh
  ausearch -m avc -ts recent | audit2allow -M dae_local
  ```
- 内核 BTF：`ls /sys/kernel/btf/vmlinux` 必须存在（Fedora 默认有）。
- 配置权限：`chmod 0400 /etc/dae/config.dae /etc/dae/config.d/*.dae`。

验证：`dae validate`、`curl -x http://127.0.0.1:12345` 走代理、`nslookup` 看 DNS 是否被拦截、LAN 机器直接用网关上网。

## 3.3 容器（Quadlet）

全部放 `/usr/share/containers/systemd/`（rootful），实测不需要 enable，`systemctl daemon-reload` 后生成服务。

- `sub-store.container`：3001，数据 `/var/lib/sub-store`
- `openlist.container`：5244，数据 `/var/lib/openlist`
- `memos.container`：5230，数据 `/var/lib/memos`（Fedora 无 RPM，改容器）

验证：`systemctl status sub-store`、`podman ps`、浏览器访问 3001/5244/5230。

## 3.4 Forgejo + runner

- 包：`forgejo`、`forgejo-runner`（Fedora 仓库；缺失则用上游 RPM 或二进制 + 自写 unit）
- 配置：`/etc/forgejo/app.ini`（可变配置，属正常 /etc 用法）
- 数据：`/var/lib/forgejo`
- runner：host 模式 + rootful podman，`/etc/forgejo-runner/token` 由 `LoadCredential` 读
- insecure registry：`/etc/containers/registries.conf.d/10-router.conf` 加 `10.10.10.1:3000`

验证：首次建管理员（`forgejo admin user create`）、推一个镜像到 3000、跑一次 Actions。
