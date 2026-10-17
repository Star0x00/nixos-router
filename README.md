# fedora-bootc-router

Fedora bootc 自定义 OCI 系统镜像，替换原 NixOS 路由器。
旧的 NixOS 配置原样保留在 `archive/`（未删除、未导入）。

## 目标主机（与原配置一致）

| 项 | 值 |
|---|---|
| WAN | `eno1`，DHCP |
| LAN | `enp0s20f0u1`（USB RTL8153），`10.10.10.1/24` |
| 主机名 | `nixos-router` |
| root SSH | 见 `rootfs/usr/share/router/ssh/authorized_keys` |
| 系统 | `quay.io/fedora/fedora-bootc:43` 派生 |

## 目录

```
Containerfile               # 骨架镜像（阶段 2）
.github/workflows/build.yml # CI：构建 + lint + 推送 GHCR
rootfs/                     # 原样 COPY 到镜像 / 的文件树（静态配置优先进 /usr）
  usr/share/router/         # nftables 等配置源
  usr/lib/systemd/system/   # unit drop-in
stages/                     # 每阶段的说明与验证步骤
archive/                    # 原 NixOS 仓库（只读参考，不再构建）
```

## 阶段

- **阶段 1** 仓库重整：NixOS 全部移入 `archive/`。✅
- **阶段 2** 骨架镜像：FROM fedora-bootc:43 + 基础包 + 静态配置（networkd/nftables/sshd/sysctl/modprobe/udev/initramfs），`bootc container lint` 通过。
- **阶段 3+** 服务逐个加：DHCP → 代理 → 容器 → 代码托管，每个单独验证。

## 构建

本地：

```sh
just build            # podman build -t localhost/router-bootc:dev .
```

CI（GitHub Actions，`.github/workflows/build.yml`）：

- push 到 `main` → 构建 + `bootc container lint` + 推送 `ghcr.io/<owner>/<repo>:latest` 和 `:sha-<12位>`
- PR → 只构建 + lint，不推送
- 每周一 03:00 UTC 自动重建，跟进 `fedora-bootc:43` 更新
- `archive/**` 与 `*.md` 的改动不触发构建

## 状态

阶段 1 完成；阶段 2 骨架配置已写好，**尚未构建验证**。验证步骤见 `stages/02-skeleton.md`。

## 注意

- 静态配置放 `/usr`，机器本地状态才放 `/etc`（bootc 升级时 `/etc` 是 3-way merge）。
- initramfs 在构建期生成，改了 dracut 配置必须重跑 `dracut`。
- Fedora 默认 NetworkManager/firewalld，全部 mask，改用 systemd-networkd + nftables。
