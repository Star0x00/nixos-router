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
    ├── sub-store.nix           # 订阅管理容器（podman）
    └── adguardhome.nix         # 未启用（旧方案，被 kea+dae 取代）
```

## 架构

- **DHCP**：Kea DHCP4，下发网关/DNS 均为 `10.10.10.1`
- **透明代理**：dae (eBPF) 拦截流量 + DNS,直连接入 sing-box (SOCKS5)
- **DNS**：由 dae 的 DNS 路由处理（广告拦截、污染重查）
- **防火墙**：nftables，仅放行 established + LAN 流量
- **订阅**：Sub-Store（podman 容器），每天 7 点更新节点重启 sing-box

## 部署

```sh
# 构建
nix build .#nixosConfigurations.router.config.system.build.toplevel

# 远程部署（需 SSH root@10.10.10.1）
nixos-rebuild switch --flake .#router --target-host root@10.10.10.1 --use-remote-sudo
```

## 注意

- `net.nix` 含 SSH authorized key 等敏感信息，仓库应保持私有
- `services/adguardhome.nix` 未启用（旧方案），仅保留参考
- `pi-coding-agent` 等 agent 包不在本仓库（后续由独立 flake 提供）