# Router-bootc

This repository has a container that can become my homelab server in charge of network router and some service. It uses `bootc` and bases on `fedora-bootc`.

## Main Information

| Key        | Value                                                        |
| ---------- | ------------------------------------------------------------ |
| Hostname   | router                                                       |
| WAN        | `eno1`,DHCP                                                  |
| LAN        | `enp0s20f0u1` (USB RTL8153), `10.10.10.1/24`                 |
| Root SSH   | see rootfs/etc/ssh/authorized_keys/root(./rootfs/etc/ssh/authorized_keys/root) |
| Base image | `quay.io/fedora/fedora-bootc:44`                             |
| Service    | `sub-store` `singbox` `dae`                                  |

## Layout

```text
├── .github
│   └── workflows
│       └── build.yml                                       # CI: build + lint + push to GHCR
├── rootfs                                                  # copied verbatim onto /
│   ├── etc
│   │   ├── containers
│   │   │   └── registries.conf.d                           # container registries
│   │   │       └── 10-forgejo-insecure-registry.conf       # allow the LAN Forgejo registry over HTTP
│   │   ├── dae                                             # dae config
│   │   │   ├── config.d
│   │   │   │   ├── 10-global.dae
│   │   │   │   ├── 20-node.dae
│   │   │   │   ├── 30-dns.dae
│   │   │   │   ├── 40-group.dae
│   │   │   │   └── 50-routing.dae
│   │   │   └── config.dae
│   │   └── ssh
│   │       ├── authorized_keys                             # ssh key
│   │       │   └── root
│   │       └── sshd_config.d                               # ssh config
│   │           └── 10-lan-only-key-auth.conf               # listen on LAN, root key-only
│   └── usr
│       ├── lib
│       │   ├── bootc
│       │   │   └── kargs.d                                 # kernel args
│       │   │       └── 50-selinux.toml                     # disable SELinux
│       │   ├── dracut
│       │   │   └── dracut.conf.d
│       │   │       └── 50-r8152-usb-nic.conf               # load r8152 in the initrd
│       │   ├── modprobe.d
│       │   │   └── 99-blacklist-r8153-ecm.conf             # disable conflicting r8153_ecm
│       │   ├── sysctl.d
│       │   │   └── 90-ip-forwarding.conf                   # enable IPv4 forwarding
│       │   ├── systemd
│       │   │   ├── network                                 # systemd-networkd
│       │   │   │   ├── 10-lan.network                      # LAN address + DHCP server
│       │   │   │   └── 10-wan.network                      # WAN DHCP client
│       │   │   └── system                                  # systemd service units
│       │   │       ├── dae.service.d
│       │   │       │   └── 10-sing-box-and-assets.conf     # start after sing-box, seed assets
│       │   │       ├── nftables.service.d
│       │   │       │   └── 10-use-local-rules.conf         # load the rules shipped in the image
│       │   │       ├── sshd.service.d
│       │   │       │   └── 10-wait-lan-device.conf         # wait for the LAN NIC before binding
│       │   │       ├── llama-model-fetch.service           # pull Hy-MT2 GGUF
│       │   │       └── sing-box.service                    # sing-box service
│       │   ├── sysusers.d                                  # create user
│       │   │   └── sing-box.conf                           # sing-box user and group
│       │   ├── tmpfiles.d                                  # systemd-tmpfiles
│       │   │   └── 10-persistent-state-dirs.conf           # create /var state dirs
│       │   └── udev                                        # device
│       │       └── rules.d                                 # rules
│       │           └── 90-usb-nic-power.rules              # keep USB NICs from autosuspending
│       └── share
│           ├── containers                                  # containers
│           │   └── systemd                                 # podman quadlets
│           │       ├── llama-server.container              # llama translate service
│           │       └── sub-store.container                 # sub-store
│           └── network-services                            # static assets/scripts used by the network services
│               ├── dae
│               │   └── seed-assets.sh                      # cp dae geoip/geosite to /var
│               ├── llama
│               │   └── fetch-model.sh                      # download models
│               ├── nftables
│               │   └── nftables.conf                       # nftables rules
│               └── sing-box
│                   ├── base.json                           # sing-box config template
│                   └── update.py                           # node update script
```

## Service

| Service      | Informations              |
| ------------ | ------------------------- |
| sub-store    | `10.10.10.1:3001/qwerhyy` |
| llama-server | `10.10.10.1:8080`         |
