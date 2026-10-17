# 阶段 4：安装与数据迁移

## 4.1 文件系统布局

原 NixOS 有 `/`、`/home`、`/nix`、`/forgejo` 四个 btrfs 子卷。bootc 只有"只读根 + /var 持久 + /etc 3-way merge"，所以：

- `/`：bootc 自己管（composefs / ostree），不建子卷
- 所有持久数据统一落 `/var/lib/*`，见 `rootfs/usr/lib/tmpfiles.d/router.conf`
- 若要 btrfs 根 + 独立数据子卷，必须 `bootc install to-filesystem`：自己 `mkfs.btrfs`、建子卷、写 fstab（或用 `systemd.mount-extra` karg），bootc 不会自动挂

推荐：`--filesystem btrfs` 交给 bootc，数据全在 `/var`。需要快照就用 btrfs snapshot 打 `/var/lib/forgejo`。

## 4.2 安装（第二块盘）

```sh
# 推镜像到本机 registry 或直接用本地 podman 存储
podman build -t 10.10.10.1:3000/cyrene/router-bootc:2025.10 .
podman push 10.10.10.1:3000/cyrene/router-bootc:2025.10

# 装到第二块盘（会清空该盘）
podman run --rm --privileged --pid=host --ipc=host \
  -v /var/lib/containers:/var/lib/containers -v /dev:/dev \
  --security-opt label=type:unconfined_t \
  localhost/router-bootc:latest \
  bootc install to-disk --filesystem btrfs --wipe /dev/sdX
```

或者不拆机：用 `bootc-image-builder` 出 ISO。

```sh
podman run --rm --privileged --pid=host --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v "$PWD/output:/output" \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type anaconda-iso --rootfs btrfs \
  localhost/router-bootc:latest
```

## 4.3 数据迁移

在旧系统上准备，在新系统挂载后恢复：

```sh
# 旧机（NixOS）
rsync -aHAX --numeric-ids /var/lib/forgejo  /mnt/var/lib/
rsync -aHAX --numeric-ids /var/lib/memos    /mnt/var/lib/
rsync -aHAX --numeric-ids /var/lib/sub-store /mnt/var/lib/
rsync -aHAX --numeric-ids /var/lib/openlist /mnt/var/lib/
rsync -aHAX --numeric-ids /var/lib/kea      /mnt/var/lib/
```

- UID/GID 要对齐：`forgejo` 在 Fedora 上由 RPM 建（`id forgejo`），NixOS 上没这个用户，先在新机上建好再 `chown -R`。
- sub-store/openlist 的数据是 root/1001 所有，rsync `--numeric-ids` 即可。
- snapper 快照不迁；改为新机上对 `/var/lib/forgejo` 做 btrfs snapshot + timer。

## 4.4 切换

1. BIOS 启动项切到新盘，先保留旧盘。
2. 验证 WAN/LAN/DHCP/dae/服务。
3. 稳定两周后再清旧盘。
