# nixos-router

NixOS 路由器配置（独立仓库，不依赖 home-manager 配置）。

## 结构

```
flake.nix                       # nixpkgs (nixos-unstable) + daeuniverse
hosts/router/
├── default.nix                 # 聚合入口：硬件 + 各功能模块
├── hardware-configuration.nix  # nixos-generate-config 生成，勿手改
├── base.nix                    # 主机名/用户/SSH/Nix 设置
├── boot.nix                    # bootloader、内核参数、udev
├── network.nix                 # networkd (WAN/LAN + NAT) + nftables 防火墙
├── net.nix                     # 共享常量（IP、网卡、用户名、SSH key）
├── assets/                     # dae / sing-box 配置文件
└── services/
    ├── kea.nix                 # DHCP4（替代 AdGuardHome 的 DHCP）
    ├── sing-box.nix            # SOCKS5 代理（dae 的出站）
    ├── dae.nix                 # eBPF 透明代理 / 分流 / DNS 拦截
    ├── sub-store/              # 订阅管理（podman 容器）
    │   ├── container.nix
    │   └── README.md
    ├── memos/                  # 自托管备忘录（原生部署）
    │   ├── server.nix
    │   └── README.md
    ├── forgejo/                # 代码托管 + OCI 镜像仓库 + Actions runner
    │   ├── server.nix
    │   ├── actions.nix
    │   └── README.md           # 访问地址 / 首次部署 / 启用 Actions
    └── deprecated/             # 被取代的旧方案（不导入）
        └── adguardhome.nix     #   旧 AGH 方案（kea+dae 取代）
```

各服务子目录里的 `README.md` 记录该服务的访问地址与部署/启用要点
（如 Forgejo 首次建号、Actions 的 uuid+token 启用流程、Sub-Store 环境变量等）。

## 架构

- **DHCP**：Kea DHCP4，下发网关/DNS 均为 `10.10.10.1`
- **透明代理**：dae (eBPF) 拦截流量 + DNS, 直连接入 sing-box (SOCKS5)
- **DNS**：由 dae 的 DNS 路由处理（广告拦截、污染重查）
- **防火墙**：nftables，仅放行 established + LAN（见 `network.nix`）
- **订阅**：Sub-Store（podman 容器）
- **备忘录**：Memos（原生 systemd，`http://10.10.10.1:5230`）
- **代码托管/镜像**：Forgejo（原生 systemd，`http://10.10.10.1:3000`，独立 btrfs 子卷 + snapper）
- **CI**：Forgejo Actions runner 经 podman 跑 job

## 部署

```sh
# 构建
nix build .#nixosConfigurations.router.config.system.build.toplevel

# 远程部署（需 SSH root@10.10.10.1）
nixos-rebuild switch --flake .#router --target-host root@10.10.10.1 --use-remote-sudo
```

## 注意

- `services/deprecated/` 是未导入的旧方案，仅供历史参考。
- 要新加服务：见 `services/forgejo` 的「子目录 + README」组织方式。