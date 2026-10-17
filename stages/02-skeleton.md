# 阶段 2：骨架镜像

只解决"能装、能启动、能进 SSH、能上网"。不含代理/DHCP/容器。

## 包含（已写入仓库）

- 包：`systemd-networkd` `nftables` `openssh-server` `podman` + 排障工具
- `/usr/lib/systemd/network/10-wan.network` WAN(`eno1`) DHCP
- `/usr/lib/systemd/network/10-lan.network` LAN(`enp0s20f0u1`) 10.10.10.1/24 + IPMasquerade
- `/usr/share/router/nftables.conf` + unit drop-in 改 `ExecStart`
- `/usr/lib/sysctl.d/90-router.conf`：`ip_forward=1`
- `/usr/lib/modprobe.d/99-router.conf`：blacklist `r8153_ecm`
- `/usr/lib/udev/rules.d/90-usb-nic-power.rules`：USB 网卡不休眠
- `/usr/lib/dracut/dracut.conf.d/50-router-modules.conf`：`force_drivers+=" r8152 "`
- mask：NetworkManager、firewalld、systemd-resolved
- `/etc/ssh/authorized_keys/root` + `ListenAddress 10.10.10.1`
- initramfs 构建期重生成 + `bootc container lint`

## 验证

```sh
podman build -t localhost/router-bootc:stage2 --target skeleton .   # 或用完整 Containerfile
podman run --rm localhost/router-bootc:stage2 bootc container lint
```

qemu（USB 网卡用 `-device usb-net` 模拟）：

```sh
qemu-system-x86_64 -M q35 -m 4G -enable-kvm \
  -drive if=virtio,file=stage2.qcow2,format=qcow2 \
  -netdev user,id=wan -device virtio-net-pci,netdev=wan \
  -device qemu-xhci -device usb-net,netdev=lan \
  -netdev user,id=lan \
  -nographic
```

检查点：`ip -br a` 有 eno1(或 vlan 名) 拿到 DHCP；`nft list ruleset` 有表；`systemctl status sshd` 无 EADDRNOTAVAIL；`systemctl is-enabled NetworkManager` = masked。
