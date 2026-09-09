# Forgejo — 自托管代码托管 + 内置 OCI(容器镜像)仓库

原生 NixOS 模块部署(单 Go 二进制), 数据放独立 btrfs 子卷 + snapper 快照。
Actions 用 podman 跑 job, 不引入 docker。

## 访问地址

- **Web**: `http://10.10.10.1:3000`
- **Git-over-SSH**: `ssh://forgejo@10.10.10.1/<owner>/<repo>.git`(走系统 sshd 的 forgejo 用户, 端口 22)
- **镜像仓库**: 内置(与代码同账号), 纯 HTTP 所以推送要关 tls 校验:
  `podman push --tls-verify=false 10.10.10.1:3000/<owner>/<image>`

## 文件

- `server.nix` — Forgejo 服务、子卷挂载、snapper 快照
- `actions.nix` — Actions runner(podman)
- 子卷与快照说明见下「数据与备份」

## 首次部署

1. 一次性创建数据子卷与快照子卷:

   ```sh
   mkdir -p /mnt/btrfs-top
   mount -o subvolid=5 /dev/disk/by-uuid/f3727793-20bf-4102-b40d-b65dd50d8e19 /mnt/btrfs-top
   btrfs subvolume create /mnt/btrfs-top/forgejo
   btrfs subvolume create /mnt/btrfs-top/forgejo/.snapshots
   umount /mnt/btrfs-top && rmdir /mnt/btrfs-top
   ```

2. `nixos-rebuild switch`(首次在空子卷上起服务, 若 `forgejo.service` 因
   `/var/lib/forgejo/custom` 缺失失败, 先 `systemd-tmpfiles --create` 建骨架再启动)。
3. 建管理员账号: 临时把 `server.nix` 里 `DISABLE_REGISTRATION` 改 `false` 部署,
   开 `http://10.10.10.1:3000` 注册后改回 `true` 再部署。

## 启用 Actions

1. 站点管理 → Actions → **Create new runner**, 抄下弹窗的 **uuid + token**。
   (新版 runner 只认 uuid+token 一对; 旧的短效 Registration Token 已废弃)
2. 把 uuid 填到 `actions.nix` 的 `server.connections.forgejo.uuid`;
   把 token 写入路由器 `/etc/forgejo-runner/token`(root:root 0600)。
3. 把 `actions.nix` 里 `enable` 改 `true`, 重新部署。
4. 本地 CI job 镜像(`ci-runner:24.04`, 定义在 `pkgs/ci-runner.nix`): 执行 `just ci-runner` 构建并载入 podman
   (换 base 镜像时按报错回填 `outputHash`); 以后改了镜像重跑该命令即可(固定 tag, 记得重新 load)。

## 数据与备份

- 数据在独立 btrfs 子卷 `/var/lib/forgejo`(与 root/home/nix 平级), 压缩 zstd。
- **snapper 自动时间线快照**(时6/日7/周4/月3), 落在子卷内 `.snapshots`:
  `snapper -c forgejo list`  查看
  `snapper -c forgejo rollback`  回滚
- btrfs 快照不递归嵌套子卷, 不会把自己复制进快照而膨胀。
- 手动带走快照(可选): `btrfs send | btrfs receive <目标盘>`。